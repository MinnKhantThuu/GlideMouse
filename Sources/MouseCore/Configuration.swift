import Foundation

public enum SupportStatus: String, Codable, Sendable { case verified, experimental, unavailable }
public enum Direction: String, Codable, CaseIterable, Sendable { case left, right, up, down }
public enum TriggerKind: String, Codable, CaseIterable, Sendable {
    case button, buttonHold, buttonDrag, buttonWheel, buttonChord, tap, rightTap, swipe, pinchIn, pinchOut, touchHold
}
public struct Modifiers: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let command = Modifiers(rawValue: 1)
    public static let option = Modifiers(rawValue: 2)
    public static let control = Modifiers(rawValue: 4)
    public static let shift = Modifiers(rawValue: 8)
}
public struct Trigger: Codable, Hashable, Sendable {
    public var kind: TriggerKind
    public var button: Int
    public var fingers: Int
    public var clicks: Int
    public var direction: Direction
    public var modifiers: Modifiers
    public var chordButton: Int
    public init(kind: TriggerKind = .button, button: Int = 2, fingers: Int = 1, clicks: Int = 1, direction: Direction = .left, modifiers: Modifiers = [], chordButton: Int = 3) {
        self.kind = kind; self.button = button; self.fingers = fingers; self.clicks = clicks; self.direction = direction; self.modifiers = modifiers; self.chordButton = chordButton
    }
    /// Fields irrelevant to this kind do not make distinct bindings.
    public var canonical: Trigger {
        var t = self
        if ![.button, .buttonHold, .buttonDrag, .buttonWheel, .buttonChord].contains(kind) { t.button = 2 }
        if ![.tap, .rightTap, .swipe, .touchHold].contains(kind) { t.fingers = 1 }
        if ![.button, .tap, .rightTap].contains(kind) { t.clicks = 1 }
        if ![.buttonDrag, .buttonWheel, .swipe].contains(kind) { t.direction = .left }
        if kind != .buttonChord { t.chordButton = 3 }
        return t
    }
}
public enum MouseAction: String, Codable, CaseIterable, Sendable {
    case none, leftClick, rightClick, middleClick, doubleClick, tripleClick, toggleDrag
    case back, forward, zoomIn, zoomOut, quickLook, smartZoom
    case closeWindow, minimizeWindow, hideApp, cycleWindows, appSwitcher, previousApp
    case missionControl, appExpose, showDesktop, spaceLeft, spaceRight, appLauncher
    case volumeUp, volumeDown, mute, playPause, nextTrack, previousTrack, brightnessUp, brightnessDown
    case shortcut, openApp, openFolder, openURL, lockScreen, screenshot, appleShortcut, shell, canvasPan
    public var requiresTarget: Bool { [.openApp, .openFolder, .openURL, .appleShortcut, .shell].contains(self) }
    public var isSensitive: Bool { [.closeWindow, .hideApp, .lockScreen, .screenshot, .appleShortcut, .shell, .toggleDrag].contains(self) }
}
public struct ActionOptions: Codable, Equatable, Sendable {
    public var target = ""
    public var keyCode: UInt16 = 0
    public var modifiers: Modifiers = [.command]
    public var shellEnabled = false
    public var workingDirectory = ""
    public var timeout: Double = 10
    public init() {}
}
public struct Mapping: Identifiable, Codable, Equatable, Sendable {
    public var name: String?
    public var id: UUID
    public var trigger: Trigger
    public var action: MouseAction
    public var enabled: Bool
    public var options: ActionOptions
    public init(id: UUID = UUID(), trigger: Trigger, action: MouseAction, enabled: Bool = true, options: ActionOptions = .init(), name: String? = nil) {
        self.name = name; self.id = id; self.trigger = trigger.canonical; self.action = action; self.enabled = enabled; self.options = options
    }
    public init(button: Int, action: MouseAction, enabled: Bool = true) { self.init(trigger: Trigger(button: button), action: action, enabled: enabled) }
    public var button: Int { trigger.button }
}
public enum Smoothness: String, Codable, CaseIterable, Sendable { case off, regular, high }
public struct ScrollSettings: Codable, Equatable, Sendable {
    public var enabled = false
    public var smoothness: Smoothness = .regular
    public var momentum = true
    public var speed: Double = 1
    public var acceleration: Double = 0.15
    public var reverseVertical = false
    public var reverseHorizontal = false
    public var shiftHorizontal = true
    public var optionZoom = false
    public var precisionModifier = true
    public init() {}
}
public struct Tuning: Codable, Equatable, Sendable {
    public var tapDuration: Double = 0.22
    public var multiTapInterval: Double = 0.3
    public var tapMovement: Double = 0.035
    public var swipeDistance: Double = 0.15
    public var pinchDistance: Double = 0.08
    public var holdDelay: Double = 0.4
    public var edgeMargin: Double = 0.04
    public var rightZone: Double = 0.65
    public var contactArea: Double = 0
    public var restingDelay: Double = 0.7
    public var dragDistance: Double = 35
    public init() {}
}
public struct Profile: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var bundleID: String?
    public var deviceID: String?
    public var mappings: [Mapping]
    public var scroll: ScrollSettings?
    public var paused: Bool
    public init(id: UUID = UUID(), name: String = "Profile", bundleID: String? = nil, deviceID: String? = nil, mappings: [Mapping] = [], scroll: ScrollSettings? = nil, paused: Bool = false) {
        self.id = id; self.name = name; self.bundleID = bundleID; self.deviceID = deviceID; self.mappings = mappings; self.scroll = scroll; self.paused = paused
    }
}
public enum AppLanguage: String, Codable, CaseIterable, Sendable {
    case en, my, zh
    public var resourceIdentifier: String { self == .zh ? "zh-Hans" : rawValue }
    public var nativeName: String { switch self { case .en: "English"; case .my: "မြန်မာ"; case .zh: "简体中文" } }
}
public enum AppAppearance: String, Codable, CaseIterable, Sendable { case system, light, dark }
public struct Configuration: Codable, Equatable, Sendable {
    public static let currentVersion = 2
    public var schemaVersion = currentVersion
    public var globalDefaults = Profile(name: "All apps")
    public var profiles: [Profile] = []
    public var tuning = Tuning()
    public var scroll = ScrollSettings()
    public var engineEnabled = false
    public var touchEnabled = false
    public var showFeedback = false
    public var language: AppLanguage = .en
    public var appearance: AppAppearance = .system
    public var automaticUpdates = false
    public var usability: UsabilityPreferences?
    public init() {}
    public static func preset(_ kind: String) -> [Mapping] {
        switch kind {
        case "magic": return [Mapping(trigger: .init(kind: .tap), action: .leftClick), Mapping(trigger: .init(kind: .rightTap), action: .rightClick), Mapping(trigger: .init(kind: .tap, fingers: 2), action: .rightClick), Mapping(trigger: .init(kind: .swipe, fingers: 2, direction: .left), action: .back), Mapping(trigger: .init(kind: .swipe, fingers: 2, direction: .right), action: .forward)]
        case "five": return [Mapping(button: 2, action: .middleClick), Mapping(button: 3, action: .back), Mapping(button: 4, action: .forward)]
        default: return [Mapping(button: 2, action: .middleClick)]
        }
    }
}
public struct ResolvedMapping: Sendable {
    public var mapping: Mapping
    public var source: String
    public var paused: Bool
}
public enum ProfileResolver {
    /// An unordered Set is deduplicated, then every canonical field breaks ties.
    /// Group mouse buttons numerically and keep their click/double/hold rows together.
    public static func displayTriggers(in profiles: [Profile]) -> [Trigger] {
        func key(_ trigger: Trigger) -> [Int] {
            let mouse = [.button, .buttonHold, .buttonDrag, .buttonWheel, .buttonChord].contains(trigger.kind)
            return [mouse ? 0 : 1, mouse ? trigger.button : 0,
                    TriggerKind.allCases.firstIndex(of: trigger.kind)!, trigger.clicks, trigger.fingers,
                    Direction.allCases.firstIndex(of: trigger.direction)!, trigger.modifiers.rawValue, trigger.chordButton]
        }
        return Set(profiles.flatMap(\.mappings).map { $0.trigger.canonical }).sorted { key($0).lexicographicallyPrecedes(key($1)) }
    }

    public static func eligible(bundleID: String?, deviceID: String?, profiles: [Profile]) -> [Profile] {
        profiles.enumerated().filter { _, p in (p.bundleID == nil || p.bundleID == bundleID) && (p.deviceID == nil || p.deviceID == deviceID) }
            .sorted { a, b in let sa = score(a.element), sb = score(b.element); return sa == sb ? a.offset < b.offset : sa > sb }.map(\.element)
    }
    public static func resolve(trigger: Trigger, bundleID: String?, deviceID: String?, profiles: [Profile]) -> ResolvedMapping? {
        for p in eligible(bundleID: bundleID, deviceID: deviceID, profiles: profiles) {
            if p.paused { return ResolvedMapping(mapping: .init(trigger: trigger, action: .none, enabled: false), source: p.name, paused: true) }
            if let m = p.mappings.first(where: { $0.trigger.canonical == trigger.canonical }) { return .init(mapping: m, source: p.name, paused: false) }
        }
        return nil
    }
    public static func resolveGesture(trigger: Trigger, bundleID: String?, deviceID: String?, profiles: [Profile]) -> ResolvedMapping? {
        if let exact = resolve(trigger: trigger, bundleID: bundleID, deviceID: deviceID, profiles: profiles) { return exact }
        if [.tap, .rightTap].contains(trigger.kind) {
            var single = trigger; single.clicks = 1
            if let fallback = resolve(trigger: single, bundleID: bundleID, deviceID: deviceID, profiles: profiles) { return fallback }
            if trigger.kind == .rightTap { var generic = trigger; generic.kind = .tap
                if let r = resolve(trigger: generic, bundleID: bundleID, deviceID: deviceID, profiles: profiles) { return r }
                generic.clicks = 1; return resolve(trigger: generic, bundleID: bundleID, deviceID: deviceID, profiles: profiles)
            }
        }
        return nil
    }
    public static func resolve(button: Int, bundleID: String?, deviceID: String?, profiles: [Profile]) -> Mapping? { resolve(trigger: .init(button: button), bundleID: bundleID, deviceID: deviceID, profiles: profiles)?.mapping }
    public static func scroll(bundleID: String?, deviceID: String?, configuration: Configuration) -> ScrollSettings {
        let profiles = eligible(bundleID: bundleID, deviceID: deviceID, profiles: configuration.profiles + [configuration.globalDefaults])
        for p in profiles { if p.paused { var s = configuration.scroll; s.enabled = false; return s }; if let s = p.scroll { return s } }
        return configuration.scroll
    }
    private static func score(_ p: Profile) -> Int { (p.bundleID == nil ? 0 : 2) + (p.deviceID == nil ? 0 : 1) }
}
