import Foundation

public enum ConfigurationError: Error, LocalizedError {
    case invalid(String), futureVersion(Int), recoveryFailed
    public var errorDescription: String? {
        switch self { case .invalid(let s): return s; case .futureVersion(let v): return "Unsupported configuration schema \(v)."; case .recoveryFailed: return "Settings and backup could not be read. Existing files have been preserved." }
    }
}
public enum ConfigurationValidator {
    public static func validate(_ c: Configuration) throws {
        guard c.schemaVersion == Configuration.currentVersion else { throw ConfigurationError.futureVersion(c.schemaVersion) }
        if let ui = c.usability {
            guard ui.calibrations.count <= 100, Set(ui.calibrations.map(\.identity)).count == ui.calibrations.count else { throw ConfigurationError.invalid("Invalid mouse calibration list.") }
            for calibration in ui.calibrations {
                guard !calibration.identity.isEmpty, calibration.identity.count <= 512, calibration.buttons.count <= 30, Set(calibration.buttons.map(\.button)).count == calibration.buttons.count else { throw ConfigurationError.invalid("Invalid calibration.") }
                var positions = Set<ButtonPosition>()
                for button in calibration.buttons {
                    guard (2...31).contains(button.button), button.position == .extra || positions.insert(button.position).inserted else { throw ConfigurationError.invalid("Invalid calibrated button.") }
                }
            }
        }
        let t = c.tuning
        let ranges: [(Double, ClosedRange<Double>, String)] = [(t.tapDuration, 0.05...0.6, "Tap duration"), (t.multiTapInterval, 0.1...0.8, "Multi-tap interval"), (t.tapMovement, 0.005...0.2, "Tap movement"), (t.swipeDistance, 0.04...0.6, "Swipe distance"), (t.pinchDistance, 0.02...0.5, "Pinch distance"), (t.holdDelay, 0.15...1.5, "Hold delay"), (t.edgeMargin, 0...0.2, "Edge margin"), (t.rightZone, 0.3...0.8, "Right zone"), (t.contactArea, 0...5, "Contact area"), (t.restingDelay, 0.3...3, "Resting delay"), (t.dragDistance, 5...200, "Drag distance"), (t.touchHoldDelay, 0.15...1.5, "Touch hold delay"), (t.swipeSpeed, 0...5, "Swipe speed"), (t.tapSlideSpeed, 0.1...10, "Tap slide speed"), (t.dragScrollSpeed, 100...2000, "Drag scroll speed"), (t.appSwitchDelay, 0.2...3, "App switch delay"), (t.rightZoneFront, 0...0.8, "Right zone front")]
        for (value, range, name) in ranges { if !value.isFinite || !range.contains(value) { throw ConfigurationError.invalid("\(name) is outside its valid range.") } }
        let profiles = c.profiles + [c.globalDefaults]
        guard c.profiles.count <= 200 else { throw ConfigurationError.invalid("Too many profiles.") }
        guard c.globalDefaults.bundleID == nil && c.globalDefaults.deviceID == nil else { throw ConfigurationError.invalid("Global defaults cannot have an app or device selector.") }
        guard Set(profiles.map(\.id)).count == profiles.count else { throw ConfigurationError.invalid("Duplicate profile identifiers.") }
        var selectors = Set<String>()
        for p in c.profiles {
            guard p.bundleID != nil || p.deviceID != nil else { throw ConfigurationError.invalid("A profile needs an app or device selector.") }
            if let b = p.bundleID, b.isEmpty || b.count > 255 { throw ConfigurationError.invalid("Invalid bundle identifier.") }
            if let d = p.deviceID, d.isEmpty || d.count > 512 { throw ConfigurationError.invalid("Invalid device identifier.") }
            let key = "\(p.bundleID ?? "*")|\(p.deviceID ?? "*")"
            guard selectors.insert(key).inserted else { throw ConfigurationError.invalid("Duplicate app/device profile rules.") }
        }
        for p in profiles {
            guard !p.name.isEmpty && p.name.count <= 150 && p.mappings.count <= 500 else { throw ConfigurationError.invalid("Invalid profile name or mapping count.") }
            guard Set(p.mappings.map(\.id)).count == p.mappings.count else { throw ConfigurationError.invalid("Duplicate mapping identifiers.") }
            var triggers = Set<Trigger>()
            for m in p.mappings {
                if let name = m.name, name.count > 150 { throw ConfigurationError.invalid("Mapping name is too long.") }
                guard triggers.insert(m.trigger.canonical).inserted else { throw ConfigurationError.invalid("Conflicting mappings in \(p.name).") }
                guard (0...31).contains(m.trigger.button), (1...3).contains(m.trigger.fingers), (1...3).contains(m.trigger.clicks), (0...31).contains(m.trigger.chordButton), (m.trigger.modifiers.rawValue & ~15) == 0 else { throw ConfigurationError.invalid("Invalid trigger.") }
                // Keep ordinary clicks and dragging available; only deliberate double/hold gestures are remapped.
                if [.button, .buttonHold, .buttonDrag, .buttonWheel, .buttonChord].contains(m.trigger.kind), m.trigger.button < 2 {
                    guard m.trigger.kind == .buttonHold || (m.trigger.kind == .button && m.trigger.clicks == 2) else { throw ConfigurationError.invalid("Left/right buttons support double click and hold. Ordinary clicks stay native.") }
                }
                if m.trigger.kind == .buttonChord && m.trigger.chordButton < 2 { throw ConfigurationError.invalid("Use a side or wheel button for chords.") }
                if m.trigger.kind == .buttonChord && m.trigger.chordButton == m.trigger.button { throw ConfigurationError.invalid("Chord buttons must be different.") }
                guard m.options.timeout.isFinite && (1...60).contains(m.options.timeout), m.options.target.count <= 8192, m.options.keyCode <= 127, (m.options.modifiers.rawValue & ~15) == 0 else { throw ConfigurationError.invalid("Invalid action options.") }
                if m.enabled && m.action.requiresTarget && m.options.target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { throw ConfigurationError.invalid("\(m.action.rawValue) needs a target.") }
                if m.action == .openURL && m.enabled {
                    guard let u = URL(string: m.options.target), ["https", "http"].contains(u.scheme?.lowercased() ?? ""), u.host != nil else { throw ConfigurationError.invalid("Only valid HTTP/HTTPS URLs are accepted.") }
                }
            }
            if let s = p.scroll { try validateScroll(s) }
        }
        try validateScroll(c.scroll)
    }
    public static func validateScroll(_ s: ScrollSettings) throws {
        guard s.speed.isFinite && (0.2...5).contains(s.speed), s.acceleration.isFinite && (0...1).contains(s.acceleration) else { throw ConfigurationError.invalid("Invalid scroll speed or acceleration.") }
    }
}
public struct ImportPreview: Sendable {
    public var configuration: Configuration
    public var disabledCommands: Int
    public var profiles: Int { configuration.profiles.count }
    public var mappings: Int { (configuration.profiles + [configuration.globalDefaults]).reduce(0) { $0 + $1.mappings.count } }
}
public enum ConfigurationCodec {
    public static func encode(_ c: Configuration) throws -> Data { try ConfigurationValidator.validate(c); let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]; return try e.encode(c) }
    public static func decode(_ data: Data) throws -> Configuration {
        guard data.count <= 2_000_000 else { throw ConfigurationError.invalid("Configuration exceeds 2 MB.") }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let version = json?["schemaVersion"] as? Int else { throw ConfigurationError.invalid("Missing schema version.") }
        if version == 1 { return try migrateV1(data) }
        guard version == Configuration.currentVersion else { throw ConfigurationError.futureVersion(version) }
        let c = try JSONDecoder().decode(Configuration.self, from: data); try ConfigurationValidator.validate(c); return c
    }
    public static func preview(_ data: Data) throws -> ImportPreview {
        var c = try decode(data); var n = 0
        func sanitize(_ p: inout Profile) {
            for i in p.mappings.indices where [.shell, .appleShortcut].contains(p.mappings[i].action) {
                p.mappings[i].enabled = false; p.mappings[i].options.shellEnabled = false; n += 1
            }
        }
        sanitize(&c.globalDefaults); for i in c.profiles.indices { sanitize(&c.profiles[i]) }
        c.engineEnabled = false; c.touchEnabled = false; c.automaticUpdates = false
        return ImportPreview(configuration: c, disabledCommands: n)
    }
    private struct Legacy: Decodable { var schemaVersion: Int; var profiles: [LegacyProfile] }
    private struct LegacyProfile: Decodable { var bundleID: String?; var deviceID: String?; var mappings: [LegacyMapping] }
    private struct LegacyMapping: Decodable { var button: Int; var action: MouseAction; var enabled: Bool }
    private static func migrateV1(_ data: Data) throws -> Configuration {
        let old = try JSONDecoder().decode(Legacy.self, from: data); var c = Configuration()
        for p in old.profiles {
            let profile = Profile(name: p.bundleID ?? p.deviceID ?? "All apps", bundleID: p.bundleID, deviceID: p.deviceID, mappings: p.mappings.map { Mapping(button: $0.button, action: $0.action, enabled: $0.enabled) })
            if p.bundleID == nil && p.deviceID == nil { c.globalDefaults = profile } else { c.profiles.append(profile) }
        }
        try ConfigurationValidator.validate(c); return c
    }
    public static func merge(current: Configuration, imported: Configuration) throws -> Configuration {
        var c = current
        for p in imported.profiles {
            if c.profiles.contains(where: { $0.bundleID == p.bundleID && $0.deviceID == p.deviceID }) { throw ConfigurationError.invalid("Merge conflicts with profile \(p.name). Use replace or change its selectors.") }
            c.profiles.append(p)
        }
        for m in imported.globalDefaults.mappings {
            guard !c.globalDefaults.mappings.contains(where: { $0.trigger.canonical == m.trigger.canonical }) else { throw ConfigurationError.invalid("Merge conflicts with a global mapping.") }
            c.globalDefaults.mappings.append(m)
        }
        try ConfigurationValidator.validate(c); return c
    }
}
public final class ConfigurationStore {
    public let url: URL
    public var backupURL: URL { url.appendingPathExtension("backup") }
    public private(set) var recoveredBackup = false
    public init(url: URL) { self.url = url }
    public func load() throws -> Configuration {
        guard FileManager.default.fileExists(atPath: url.path) else { return Configuration() }
        do { return try ConfigurationCodec.decode(Data(contentsOf: url)) }
        catch ConfigurationError.futureVersion(let v) { throw ConfigurationError.futureVersion(v) }
        catch {
            guard let data = try? Data(contentsOf: backupURL), let c = try? ConfigurationCodec.decode(data) else { throw ConfigurationError.recoveryFailed }
            recoveredBackup = true; return c
        }
    }
    public func save(_ c: Configuration) throws {
        let data = try ConfigurationCodec.encode(c)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let previous = try? Data(contentsOf: url) {
            if (try? ConfigurationCodec.decode(previous)) != nil { try previous.write(to: backupURL, options: .atomic) }
            else { try previous.write(to: url.deletingLastPathComponent().appendingPathComponent("settings-recovery-" + UUID().uuidString + ".json"), options: .atomic) }
        }
        try data.write(to: url, options: .atomic)
    }
}
