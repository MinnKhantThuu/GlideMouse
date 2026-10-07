import Foundation

public enum ButtonPosition: String, Codable, CaseIterable, Sendable {
    case wheel = "Wheel button", upper = "Upper side button", lower = "Lower side button", extra = "Extra button"
}
public struct CalibratedButton: Codable, Equatable, Sendable {
    public var button: Int
    public var position: ButtonPosition
    public init(button: Int, position: ButtonPosition) { self.button = button; self.position = position }
}
public struct MouseCalibration: Codable, Equatable, Sendable {
    public var identity: String
    public var buttons: [CalibratedButton]
    public init(identity: String, buttons: [CalibratedButton] = []) { self.identity = identity; self.buttons = buttons }
    public mutating func assign(button: Int, position: ButtonPosition) {
        buttons.removeAll { $0.button == button || (position != .extra && $0.position == position) }
        buttons.append(.init(button: button, position: position))
    }
}
public struct UsabilityPreferences: Codable, Equatable, Sendable {
    public var setupCompleted = false
    public var calibrations: [MouseCalibration] = []
    public init() {}
}
public enum ScrollPreset: String, CaseIterable, Sendable {
    case standard = "Standard", smooth = "Smooth", custom = "Custom"
    public func applying(to original: ScrollSettings) -> ScrollSettings {
        var result = original
        switch self {
        case .standard: result.enabled = true; result.smoothness = .off; result.momentum = false; result.acceleration = 0
        case .smooth: result.enabled = true; result.smoothness = .high; result.momentum = true; result.acceleration = 0.15
        case .custom: break
        }
        return result
    }
    public static func matching(_ s: ScrollSettings) -> Self {
        guard s.enabled else { return .custom }
        if s.smoothness == .off && !s.momentum && s.acceleration == 0 { return .standard }
        if s.smoothness == .high && s.momentum && s.acceleration == 0.15 { return .smooth }
        return .custom
    }
}
public enum ButtonFeelPreset: String, CaseIterable, Sendable {
    case fast = "Fast", normal = "Normal", relaxed = "Relaxed", custom = "Custom"
    public func applying(to original: Tuning) -> Tuning {
        var result = original
        switch self {
        case .fast: result.holdDelay = 0.25; result.multiTapInterval = 0.22; result.dragDistance = 25
        case .normal: result.holdDelay = 0.4; result.multiTapInterval = 0.3; result.dragDistance = 35
        case .relaxed: result.holdDelay = 0.65; result.multiTapInterval = 0.5; result.dragDistance = 55
        case .custom: break
        }
        return result
    }
    public static func matching(_ t: Tuning) -> Self {
        allCases.first { $0 != .custom && $0.applying(to: t) == t } ?? .custom
    }
}
public enum MappingEdits {
    /// Updates only matching triggers; unrelated advanced bindings remain intact.
    public static func merge(_ additions: [Mapping], into original: [Mapping]) -> [Mapping] {
        var result = original
        for var mapping in additions {
            mapping.trigger = mapping.trigger.canonical
            if let index = result.firstIndex(where: { $0.trigger.canonical == mapping.trigger }) {
                mapping.id = result[index].id
                if mapping.name == nil { mapping.name = result[index].name }
                result[index] = mapping
            } else { result.append(mapping) }
        }
        return result
    }
    public static func starter(_ kind: String, buttons: [CalibratedButton]) -> [Mapping] {
        let upper = buttons.first { $0.position == .upper }?.button
        let lower = buttons.first { $0.position == .lower }?.button
        if kind == "desktop", let upper, let lower {
            return [Mapping(button: upper, action: .spaceRight), Mapping(button: lower, action: .spaceLeft), Mapping(trigger: .init(kind: .buttonHold, button: lower), action: .missionControl)]
        }
        if kind == "browser", let upper, let lower { return [Mapping(button: upper, action: .forward), Mapping(button: lower, action: .back)] }
        if kind == "desktop" || kind == "browser" { return [] }
        return Configuration.preset(kind)
    }
}
