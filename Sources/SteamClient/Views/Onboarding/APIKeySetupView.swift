import AppKit
import SwiftUI

struct APIKeySetupView: View {
    let store: GameLibraryStore
    let onDismiss: () -> Void

    @ViewState private var apiKeyInput = ""
    @ViewState private var isSaving = false
    @ViewState private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Connect your Steam Web API key")
                .font(.title2.weight(.semibold))
            Text("Generate a personal key at steamcommunity.com/dev/apikey, then paste it below. It's stored in your Keychain and used to fetch owned games and playtime.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            SecureField("API key", text: $apiKeyInput)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 320)
                .onSubmit(save)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 12) {
                Button("Open steamcommunity.com/dev/apikey") {
                    if let url = URL(string: "https://steamcommunity.com/dev/apikey") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("Skip for now", action: onDismiss)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
            }
        }
        .padding(40)
        .frame(minWidth: 720, minHeight: 480)
    }

    private func save() {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try KeychainService.saveAPIKey(trimmed)
            errorMessage = nil
            isSaving = true
            Task {
                await store.refreshRemote()
                isSaving = false
                if store.remoteError == nil {
                    onDismiss()
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
