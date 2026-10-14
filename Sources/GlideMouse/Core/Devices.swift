import Foundation
import AppKit
import IOKit.hid
import NativeBridge
import MouseCore

struct MouseDevice: Identifiable, Codable, Equatable, Sendable {
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
    private var timer: Timer?
    private var snapshot: [MouseDevice] = []
    func start(onChange: @escaping @MainActor @Sendable () -> Void) {
        stop()
        snapshot = enumerate()
        // Registry metadata does not open an HID device or subscribe to input.
        // Poll for connection changes; invoke refresh only when devices differ.
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let devices = self.enumerate()
                guard devices != self.snapshot else { return }
                self.snapshot = devices; onChange()
            }
        }
        RunLoop.main.add(timer, forMode: .common); self.timer = timer
    }
    func stop() { timer?.invalidate(); timer = nil; snapshot = [] }
    func enumerate() -> [MouseDevice] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOHIDDevice"), &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }
        var devices: [MouseDevice] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            guard let device = IOHIDDeviceCreate(kCFAllocatorDefault, service) else { continue }
            func property(_ key: String) -> Any? { IOHIDDeviceGetProperty(device, key as CFString) }
            guard property(kIOHIDPrimaryUsagePageKey) as? Int == 1,
                  property(kIOHIDPrimaryUsageKey) as? Int == 2 else { continue }
            let vendor = property(kIOHIDVendorIDKey) as? Int ?? 0, product = property(kIOHIDProductIDKey) as? Int ?? 0
            let name = property(kIOHIDProductKey) as? String ?? "Mouse", transport = property(kIOHIDTransportKey) as? String ?? "Unknown"
            let serial = property(kIOHIDSerialNumberKey) as? String ?? ""
            let location = property(kIOHIDLocationIDKey) as? Int ?? 0
            let elements = IOHIDDeviceCopyMatchingElements(device, nil, IOOptionBits(kIOHIDOptionsTypeNone)) as? [IOHIDElement] ?? []
            let keyboardCollection = elements.contains { IOHIDElementGetUsagePage($0) == 1 && IOHIDElementGetUsage($0) == 6 }
            let touchpadCollection = elements.contains { IOHIDElementGetUsagePage($0) == 13 && IOHIDElementGetUsage($0) == 5 }
            guard MouseDeviceClassification.isMouse(name: name, keyboardCollection: keyboardCollection, touchpadCollection: touchpadCollection) else { continue }
            let buttons = elements.filter { IOHIDElementGetUsagePage($0) == 9 }.map { IOHIDElementGetUsage($0) }.max() ?? 0
            var registryID: UInt64 = 0
            IORegistryEntryGetRegistryEntryID(service, &registryID)
            let identifier = "\(vendor):\(product):\(transport):" + (serial.isEmpty ? "session-\(location)-\(registryID)" : serial)
            devices.append(MouseDevice(id: identifier, name: name, transport: transport, vendor: vendor, product: product, buttons: Int(buttons), stableIdentity: !serial.isEmpty, magicMouse: vendor == 1452 && (name.localizedCaseInsensitiveContains("magic mouse") || [781, 617, 789].contains(product))))
        }
        return devices.sorted { ($0.name, $0.id) < ($1.name, $1.id) }
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
