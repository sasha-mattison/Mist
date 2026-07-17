import SwiftUI

/// Drives the browser-based Steam OpenID sign-in and reflects its progress.
/// On success the SteamID64 is stored and the library refreshes; if no Web
/// API key is configured yet, the caller is asked to present that setup next.
struct SteamSignInSheet: View {
    let store: GameLibraryStore
    let onDismiss: () -> Void
    let onNeedsAPIKey: () -> Void

    @Environment(SettingsStore.self) private var settings
    @ViewState private var errorMessage: String?
    @ViewState private var isWaiting = false
    @ViewState private var signInTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.badge.shield.checkmark")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
            Text("Sign in with Steam")
                .font(.title2.weight(.semibold))
            Text("Your browser will open Steam's official sign-in page (steamcommunity.com). Sign in there — Steam Guard and password managers work as usual. This app only receives your public SteamID; it never sees your password.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            if isWaiting {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Waiting for you to finish signing in in the browser…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: 420)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    signInTask?.cancel()
                    onDismiss()
                }
                if isWaiting {
                    Button("Reopen Browser Page") { startSignIn(restart: true) }
                } else {
                    Button(errorMessage == nil ? "Open Browser & Sign In" : "Try Again") {
                        startSignIn(restart: false)
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.top, 8)
        }
        .padding(40)
        .frame(minWidth: 560, minHeight: 340)
        .onDisappear { signInTask?.cancel() }
        // Sheets don't inherit .tint() from the presenting window on macOS.
        .tint(settings.accentColor)
    }

    private func startSignIn(restart: Bool) {
        if restart { signInTask?.cancel() }
        errorMessage = nil
        isWaiting = true
        signInTask = Task {
            do {
                let steamID64 = try await SteamOpenIDService().signIn()
                store.completeSignIn(steamID64: steamID64)
                let hasAPIKey = KeychainService.loadAPIKey() != nil
                if hasAPIKey {
                    await store.refreshRemote()
                }
                isWaiting = false
                onDismiss()
                if !hasAPIKey {
                    onNeedsAPIKey()
                }
            } catch is CancellationError {
                isWaiting = false
            } catch SteamOpenIDService.AuthError.cancelled {
                isWaiting = false
            } catch {
                isWaiting = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
