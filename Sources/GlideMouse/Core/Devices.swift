import Foundation
import AppKit
import IOKit.hid
import NativeBridge
import MouseCore

struct MouseDevice: Identifiable, Codable, Sendable {
    var id: String
    var name: String
    var transport: String
    var vendor: Int
    var product: Int
    var buttons: Int
    var stableIdentity: Bool
    var magicMouse: Bool
}
@MainActor final class DeviceRegistry {
    private var manager: IOHIDManager?
    private var onChange: (() -> Void)?
    func start(onChange: @escaping () -> Void) {
        self.onChange = onChange
        let m = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone)); manager = m
        IOHIDManagerSetDeviceMatching(m, [kIOHIDDeviceUsagePageKey: 1, kIOHIDDeviceUsageKey: 2] as CFDictionary)
        let callback: IOHIDDeviceCallback = { context, _, _, _ in
            guard let context else { return }
            MainActor.assumeIsolated { Unmanaged<DeviceRegistry>.fromOpaque(context).takeUnretainedValue().onChange?() }
        }
        IOHIDManagerRegisterDeviceMatchingCallback(m,callback,Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerRegisterDeviceRemovalCallback(m,callback,Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerScheduleWithRunLoop(m,CFRunLoopGetMain(),CFRunLoopMode.defaultMode.rawValue)
        _ = IOHIDManagerOpen(m,IOOptionBits(kIOHIDOptionsTypeNone))
    }
    func stop() { if let m = manager { IOHIDManagerUnscheduleFromRunLoop(m,CFRunLoopGetMain(),CFRunLoopMode.defaultMode.rawValue); IOHIDManagerClose(m,IOOptionBits(kIOHIDOptionsTypeNone)) }; manager = nil; onChange = nil }
    func enumerate() -> [MouseDevice] {
        let temporary = manager == nil
        let m = manager ?? IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        if temporary { IOHIDManagerSetDeviceMatching(m, [kIOHIDDeviceUsagePageKey: 1, kIOHIDDeviceUsageKey: 2] as CFDictionary) }
        guard IOHIDManagerOpen(m, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else { return [] }
        defer { if temporary { IOHIDManagerClose(m, IOOptionBits(kIOHIDOptionsTypeNone)) } }
        let found = IOHIDManagerCopyDevices(m) as? Set<IOHIDDevice> ?? []
        return found.compactMap { d -> MouseDevice? in
            func property(_ key: String) -> Any? { IOHIDDeviceGetProperty(d, key as CFString) }
            let vendor = property(kIOHIDVendorIDKey) as? Int ?? 0, product = property(kIOHIDProductIDKey) as? Int ?? 0
            let name = property(kIOHIDProductKey) as? String ?? "Mouse", transport = property(kIOHIDTransportKey) as? String ?? "Unknown"
            let serial = property(kIOHIDSerialNumberKey) as? String ?? ""
            let location = property(kIOHIDLocationIDKey) as? Int ?? 0
            let elements = IOHIDDeviceCopyMatchingElements(d, nil, IOOptionBits(kIOHIDOptionsTypeNone)) as? [IOHIDElement] ?? []
            let keyboardCollection = elements.contains { IOHIDElementGetUsagePage($0) == 1 && IOHIDElementGetUsage($0) == 6 }
            let touchpadCollection = elements.contains { IOHIDElementGetUsagePage($0) == 13 && IOHIDElementGetUsage($0) == 5 }
            guard MouseDeviceClassification.isMouse(name: name, keyboardCollection: keyboardCollection, touchpadCollection: touchpadCollection) else { return nil }
            let buttons = elements.filter { IOHIDElementGetUsagePage($0) == 9 }.map { IOHIDElementGetUsage($0) }.max() ?? 0
            let identifier = "\(vendor):\(product):\(transport):" + (serial.isEmpty ? "session-\(location)-\(IOHIDDeviceGetService(d))" : serial)
            return MouseDevice(id: identifier, name: name, transport: transport, vendor: vendor, product: product, buttons: Int(buttons), stableIdentity: !serial.isEmpty, magicMouse: vendor == 1452 && (name.localizedCaseInsensitiveContains("magic mouse") || [781, 617, 789].contains(product)))
        }.sorted { $0.name < $1.name }
    }
}
struct TouchDeviceInfo: Identifiable, Codable, Equatable, Sendable {
    var id: Int
    var family: Int
    var builtIn: Bool
    var opaque: Bool
    var candidate: Bool
}
struct TouchProbe: Codable, Sendable {
    var available: Bool
    var status: String
    var devices: [TouchDeviceInfo]
    static func run() -> TouchProbe {
        let available = gm_touch_probe()
        var buffer = [GMDevice](repeating: GMDevice(), count: 16)
        let count = gm_touch_devices(&buffer, 16)
        return .init(available: available, status: String(cString: gm_touch_status()), devices: buffer.prefix(Int(count)).map { .init(id: Int($0.index), family: Int($0.family), builtIn: $0.builtIn, opaque: $0.opaque, candidate: $0.mouseCandidate) })
    }
}
