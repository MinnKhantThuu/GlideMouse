import Carbon
import Foundation

/// Registers only the pause chord. It never observes the keyboard event stream.
@MainActor final class EmergencyPauseHotKey {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: @MainActor () -> Void
    private static let signature: OSType = 0x474D5053 // GMPS
    var registered: Bool { hotKey != nil }

    init(action: @escaping @MainActor () -> Void) { self.action = action }

    @discardableResult func start() -> Bool {
        guard hotKey == nil else { return true }
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard status == noErr, identifier.signature == 0x474D5053, identifier.id == 1 else { return OSStatus(eventNotHandledErr) }
            MainActor.assumeIsolated {
                Unmanaged<EmergencyPauseHotKey>.fromOpaque(context).takeUnretainedValue().action()
            }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard installed == noErr else { return false }
        let status = RegisterEventHotKey(UInt32(kVK_Escape), UInt32(controlKey | optionKey | cmdKey), EventHotKeyID(signature: Self.signature, id: 1), GetApplicationEventTarget(), 0, &hotKey)
        if status != noErr { stop(); return false }
        return true
    }

    func stop() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        hotKey = nil; handler = nil
    }
}
