import Carbon
import Combine

@MainActor
final class GlobalShortcutController: ObservableObject {
    @Published private(set) var registeredShortcut: ShortcutDefinition?
    @Published private(set) var errorMessage: String?

    var onTriggered: (() -> Void)?

    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    init() {
        installHandler()
    }

    deinit {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    func register(_ shortcut: ShortcutDefinition?) throws {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }

        guard let shortcut else {
            registeredShortcut = nil
            return
        }

        var reference: EventHotKeyRef?
        let identifier = EventHotKeyID(
            signature: OSType(0x4D_4F_4E_4F),
            id: 1
        )
        let result = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &reference
        )
        guard result == noErr, let reference else {
            errorMessage = "快捷键已被占用，请重新录入"
            throw CocoaError(.featureUnsupported)
        }
        hotKey = reference
        registeredShortcut = shortcut
        errorMessage = nil
    }

    private func installHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else {
                    return noErr
                }
                let controller = Unmanaged<GlobalShortcutController>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                Task { @MainActor in
                    controller.onTriggered?()
                }
                return noErr
            },
            1,
            &eventType,
            pointer,
            &eventHandler
        )
    }
}
