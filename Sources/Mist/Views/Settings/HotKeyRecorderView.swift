import Carbon.HIToolbox
import SwiftUI

/// Captures the next key chord pressed while "recording" and reports it as
/// a (keyCode, Carbon modifier mask) pair — the format GlobalHotKeyService
/// needs. Requires at least one modifier key, matching every other macOS
/// global-hotkey recorder, so a single letter doesn't hijack normal typing.
struct HotKeyRecorderView: View {
    let displayString: String?
    let onRecord: (UInt32, UInt32) -> Void
    let onClear: () -> Void

    @ViewState private var isRecording = false
    @ViewState private var monitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            Button(action: toggleRecording) {
                Text(isRecording ? "Press a key combo…" : (displayString ?? "Click to record"))
                    .frame(minWidth: 140)
            }
            .buttonStyle(.bordered)

            if displayString != nil {
                Button("Clear", action: clear)
            }
        }
        .onDisappear { stopRecording() }
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if event.keyCode == 53 { // Escape cancels without setting anything.
                stopRecording()
                return nil
            }
            let modifiers = carbonModifiers(from: event.modifierFlags)
            guard modifiers != 0 else { return nil }
            onRecord(UInt32(event.keyCode), modifiers)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        isRecording = false
    }

    private func clear() {
        stopRecording()
        onClear()
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        return result
    }
}
