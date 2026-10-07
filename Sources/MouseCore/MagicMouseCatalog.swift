import Foundation

/// The same offline-editable inputs are used by the preset, UI and replay tests.
public enum MagicMouseCatalog {
    public static let touchKinds: Set<TriggerKind> = [.tap, .rightTap, .swipe, .pinchIn, .pinchOut, .touchHold]
    public static var triggers: [Trigger] {
        var inputs = (1...3).flatMap { fingers in (1...3).map { Trigger(kind: .tap, fingers: fingers, clicks: $0) } }
        inputs += (1...3).map { Trigger(kind: .rightTap, clicks: $0) }
        inputs += (1...3).flatMap { fingers in
            (fingers == 1 ? [Direction.left, .right] : Direction.allCases).map { Trigger(kind: .swipe, fingers: fingers, direction: $0) }
        }
        inputs += [Trigger(kind: .pinchIn), Trigger(kind: .pinchOut), Trigger(kind: .touchHold)]
        return inputs.map(\.canonical)
    }
    public static var defaults: [Mapping] {
        var mappings = (1...3).map { Mapping(trigger: .init(kind: .tap, clicks: $0), action: .leftClick) }
        mappings += (1...3).map { Mapping(trigger: .init(kind: .rightTap, clicks: $0), action: .rightClick) }
        mappings += [Mapping(trigger: .init(kind: .tap, fingers: 2), action: .appExpose),
                     Mapping(trigger: .init(kind: .tap, fingers: 3), action: .showDesktop)]
        let swipes: [(Int, Direction, MouseAction)] = [
            (1, .left, .back), (1, .right, .forward),
            (2, .left, .spaceLeft), (2, .right, .spaceRight), (2, .up, .appExpose), (2, .down, .minimizeWindow),
            (3, .left, .cycleAppsBackward), (3, .right, .cycleAppsForward), (3, .up, .missionControl), (3, .down, .showDesktop)
        ]
        mappings += swipes.map { Mapping(trigger: .init(kind: .swipe, fingers: $0.0, direction: $0.1), action: $0.2) }
        mappings += [Mapping(trigger: .init(kind: .pinchIn), action: .zoomOut), Mapping(trigger: .init(kind: .pinchOut), action: .zoomIn), Mapping(trigger: .init(kind: .touchHold), action: .toggleDrag)]
        return mappings
    }
}

/// Keeps the system chooser open across repeated swipes, then commits once.
/// Input injection is deliberately outside this pure state machine.
public struct AppCycleSession: Sendable {
    public private(set) var deadline: Double?
    public init() {}
    public mutating func step(at time: Double, delay: Double) -> Bool {
        let begins = deadline == nil
        deadline = time + delay
        return begins
    }
    public mutating func advance(_ time: Double) -> Bool {
        guard let deadline, time >= deadline else { return false }
        self.deadline = nil; return true
    }
    public mutating func cancel() -> Bool { let active = deadline != nil; deadline = nil; return active }
}

/// A drag belongs to the contacts which initiated it, not every resting finger.
/// A second finger can scroll independently. Faults release ownership immediately.
public struct TouchDragSession: Sendable {
    public private(set) var owners: Set<Int> = []
    private var device = ""
    private var lastTime: Double = 0
    private var ignored: Set<Int> = []
    private var scroller: TouchPoint?
    private var scrolling = false
    public init() {}
    public var active: Bool { !owners.isEmpty }
    public mutating func begin(owners: Set<Int>, device: String, time: Double, resting: Set<Int> = []) {
        self.owners = owners; self.device = device; lastTime = time; ignored = resting; scroller = nil; scrolling = false
    }
    @discardableResult public mutating func cancel() -> ScrollDelta? { let end: ScrollDelta? = scrolling ? .init(x: 0, y: 0, phase: 4) : nil; owners = []; ignored = []; scroller = nil; scrolling = false; lastTime = 0; return end }
    public mutating func process(_ frame: TouchFrame, tuning: Tuning) -> (release: Bool, scroll: ScrollDelta?) {
        guard active else { return (false, nil) }
        guard frame.timestamp.isFinite, frame.timestamp >= lastTime, frame.timestamp - lastTime <= 0.5,
              frame.deviceID == device, frame.contacts.count <= 16, Set(frame.contacts.map(\.id)).count == frame.contacts.count, !owners.isDisjoint(with: Set(frame.contacts.map(\.id))),
              frame.contacts.allSatisfy({ $0.x.isFinite && $0.y.isFinite && (0...1).contains($0.x) && (0...1).contains($0.y) }) else {
            let end: ScrollDelta? = scrolling ? .init(x: 0, y: 0, phase: 4) : nil
            cancel(); return (true, end)
        }
        lastTime = frame.timestamp
        // More than one extra contact is ambiguous: stop scrolling, keep drag.
        let extras = frame.contacts.filter { !owners.contains($0.id) && !ignored.contains($0.id) }
        guard extras.count == 1 else {
            let end: ScrollDelta? = scrolling ? .init(x: 0, y: 0, phase: 4) : nil
            scroller = nil; scrolling = false; return (false, end)
        }
        let point = extras[0]; defer { scroller = point }
        guard let previous = scroller, previous.id == point.id else { return (false, nil) }
        let sign = tuning.dragScrollReverse ? -1.0 : 1.0
        let dx = (point.x - previous.x) * tuning.dragScrollSpeed * sign
        let dy = (point.y - previous.y) * tuning.dragScrollSpeed * sign
        guard abs(dx) + abs(dy) > 0.05 else { return (false, nil) }
        let phase = scrolling ? 2 : 1; scrolling = true
        return (false, .init(x: dx, y: dy, phase: phase))
    }
}
