import AppKit
import Foundation
import Network

/// Signs the user in with their Steam account via Steam's official OpenID 2.0
/// provider — the only sanctioned third-party login surface (credentials are
/// only ever typed into steamcommunity.com in the user's own browser, so
/// password managers and Steam Guard work normally).
///
/// Flow:
/// 1. Start a loopback-only HTTP listener on an ephemeral port.
/// 2. Open steamcommunity.com/openid/login in the default browser with
///    `return_to` pointing at the listener.
/// 3. Steam redirects back after login; capture the `openid.*` parameters.
/// 4. Re-post the assertion to Steam with `check_authentication` so a forged
///    localhost request can't fake a sign-in.
/// 5. Extract the SteamID64 from `openid.claimed_id`.
final class SteamOpenIDService: @unchecked Sendable {
    enum AuthError: Error, LocalizedError {
        case listenerFailed
        case cancelled
        case timedOut
        case malformedCallback
        case verificationFailed

        var errorDescription: String? {
            switch self {
            case .listenerFailed:
                return "Couldn't start the local sign-in listener."
            case .cancelled:
                return "Sign-in was cancelled."
            case .timedOut:
                return "Sign-in timed out. Try again when you're ready."
            case .malformedCallback:
                return "Steam sent back an unexpected response."
            case .verificationFailed:
                return "Steam couldn't verify the sign-in. Try again."
            }
        }
    }

    private static let callbackPath = "/callback"
    private static let timeout: TimeInterval = 10 * 60

    private let queue = DispatchQueue(label: "SteamOpenIDService")
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private var continuation: CheckedContinuation<[String: String], Error>?

    /// Runs the whole flow and returns the signed-in SteamID64.
    func signIn() async throws -> String {
        let params: [String: String] = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                queue.async { self.start(continuation) }
            }
        } onCancel: {
            queue.async { self.finish(with: .failure(AuthError.cancelled)) }
        }
        return try await Self.verify(callbackParams: params)
    }

    // MARK: - Loopback listener

    private func start(_ continuation: CheckedContinuation<[String: String], Error>) {
        self.continuation = continuation

        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: .any)
        guard let listener = try? NWListener(using: parameters) else {
            finish(with: .failure(AuthError.listenerFailed))
            return
        }
        self.listener = listener

        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                if let port = listener.port {
                    self.openBrowser(port: port.rawValue)
                } else {
                    self.finish(with: .failure(AuthError.listenerFailed))
                }
            case .failed:
                self.finish(with: .failure(AuthError.listenerFailed))
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.start(queue: queue)

        queue.asyncAfter(deadline: .now() + Self.timeout) { [weak self] in
            self?.finish(with: .failure(AuthError.timedOut))
        }
    }

    private func openBrowser(port: UInt16) {
        var components = URLComponents(string: "https://steamcommunity.com/openid/login")!
        components.queryItems = [
            URLQueryItem(name: "openid.ns", value: "http://specs.openid.net/auth/2.0"),
            URLQueryItem(name: "openid.mode", value: "checkid_setup"),
            URLQueryItem(name: "openid.return_to", value: "http://127.0.0.1:\(port)\(Self.callbackPath)"),
            URLQueryItem(name: "openid.realm", value: "http://127.0.0.1:\(port)"),
            URLQueryItem(name: "openid.identity", value: "http://specs.openid.net/auth/2.0/identifier_select"),
            URLQueryItem(name: "openid.claimed_id", value: "http://specs.openid.net/auth/2.0/identifier_select")
        ]
        guard let url = components.url else {
            finish(with: .failure(AuthError.listenerFailed))
            return
        }
        DispatchQueue.main.async {
            NSWorkspace.shared.open(url)
        }
    }

    private func accept(_ connection: NWConnection) {
        connections.append(connection)
        connection.start(queue: queue)
        receiveRequest(on: connection, buffered: Data())
    }

    private func receiveRequest(on connection: NWConnection, buffered: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffered = buffered
            if let data { buffered.append(data) }

            // Only the request line matters; headers/body are irrelevant.
            if let requestLineEnd = buffered.firstRange(of: Data("\r\n".utf8)) {
                let line = String(decoding: buffered[..<requestLineEnd.lowerBound], as: UTF8.self)
                self.handleRequestLine(line, on: connection)
            } else if error != nil || isComplete || buffered.count > 64 * 1024 {
                connection.cancel()
            } else {
                self.receiveRequest(on: connection, buffered: buffered)
            }
        }
    }

    private func handleRequestLine(_ line: String, on connection: NWConnection) {
        // e.g. "GET /callback?openid.ns=… HTTP/1.1"
        let parts = line.split(separator: " ")
        guard parts.count >= 2 else {
            respond(on: connection, status: "400 Bad Request", body: "Bad request")
            return
        }
        let target = String(parts[1])
        guard target.hasPrefix(Self.callbackPath),
              let components = URLComponents(string: "http://127.0.0.1\(target)"),
              let queryItems = components.queryItems else {
            // Browsers also ask for /favicon.ico etc. — ignore and keep waiting.
            respond(on: connection, status: "404 Not Found", body: "Not found")
            return
        }

        var params: [String: String] = [:]
        for item in queryItems {
            params[item.name] = item.value ?? ""
        }

        if params["openid.mode"] == "id_res" {
            respond(on: connection, status: "200 OK", body: Self.successPage)
            finish(with: .success(params))
        } else {
            // mode=cancel when the user backs out on the Steam page.
            respond(on: connection, status: "200 OK", body: Self.cancelledPage)
            finish(with: .failure(AuthError.cancelled))
        }
    }

    private func respond(on connection: NWConnection, status: String, body: String) {
        let payload = Data(body.utf8)
        let head = "HTTP/1.1 \(status)\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(payload.count)\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(head.utf8) + payload, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    /// Resolves the continuation exactly once and tears the listener down.
    private func finish(with result: Result<[String: String], Error>) {
        guard let continuation else { return }
        self.continuation = nil
        listener?.cancel()
        listener = nil
        // Leave connections alive briefly so the success page finishes sending.
        queue.asyncAfter(deadline: .now() + 2) { [connections] in
            connections.forEach { $0.cancel() }
        }
        connections = []
        continuation.resume(with: result)
    }

    // MARK: - Assertion verification

    private static func verify(callbackParams: [String: String]) async throws -> String {
        var verification = callbackParams.filter { $0.key.hasPrefix("openid.") }
        verification["openid.mode"] = "check_authentication"

        var request = URLRequest(url: URL(string: "https://steamcommunity.com/openid/login")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(formEncode(verification).utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AuthError.verificationFailed
        }
        let body = String(decoding: data, as: UTF8.self)
        guard body.contains("is_valid:true") else {
            throw AuthError.verificationFailed
        }

        // claimed_id is "https://steamcommunity.com/openid/id/<steamid64>".
        guard let claimed = callbackParams["openid.claimed_id"],
              let idRange = claimed.range(of: #"^https?://steamcommunity\.com/openid/id/(\d{5,25})$"#, options: .regularExpression),
              let slashIndex = claimed[idRange].lastIndex(of: "/") else {
            throw AuthError.malformedCallback
        }
        return String(claimed[claimed.index(after: slashIndex)...])
    }

    private static func formEncode(_ params: [String: String]) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return params
            .map { key, value in
                let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
                let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(k)=\(v)"
            }
            .joined(separator: "&")
    }

    // MARK: - Result pages shown in the browser

    private static let successPage = page(
        title: "Signed in",
        heading: "✅ Signed in to Steam",
        detail: "You can close this tab and return to Mist."
    )

    private static let cancelledPage = page(
        title: "Sign-in cancelled",
        heading: "Sign-in cancelled",
        detail: "You can close this tab. Nothing was changed."
    )

    private static func page(title: String, heading: String, detail: String) -> String {
        """
        <!doctype html><html><head><meta charset="utf-8"><title>\(title)</title>
        <style>
        body { font-family: -apple-system, system-ui, sans-serif; background: #1b2838; color: #fff;
               display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
        .card { text-align: center; }
        h1 { font-size: 28px; margin-bottom: 8px; }
        p { color: #8f98a0; font-size: 15px; }
        </style></head><body><div class="card"><h1>\(heading)</h1><p>\(detail)</p></div></body></html>
        """
    }
}
