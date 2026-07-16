import Carbon.HIToolbox
import Foundation

/// Wraps Carbon's RegisterEventHotKey for a single system-wide hotkey. No
/// third-party dependency needed — Carbon is formally deprecated but remains
/// the only first-party API for a true global hotkey outside the sandboxed
/// Shortcuts/AppIntents surface.
@MainActor
final class GlobalHotKeyService {
    static let shared = GlobalHotKeyService()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var action: (() -> Void)?

    private static let hotKeyID = EventHotKeyID(signature: OSType(UInt32(0x4D495354)), id: 1) // 'MIST'

    private init() {}

    /// Registers (replacing any existing registration) a hotkey for the
    /// given virtual key code + Carbon modifier mask, invoking `action` on
    /// every press. Silently no-ops if the OS refuses the registration
    /// (e.g. the combo is already claimed system-wide).
    func register(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        unregister()
        self.action = action
        installEventHandlerIfNeeded()

        var ref: EventHotKeyRef?
        RegisterEventHotKey(keyCode, modifiers, Self.hotKeyID, GetEventDispatcherTarget(), 0, &ref)
        hotKeyRef = ref
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil
        action = nil
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let service = Unmanaged<GlobalHotKeyService>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in
                    service.action?()
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }
}
