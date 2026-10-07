import Foundation

public struct TouchPoint: Codable, Equatable, Sendable {
    public var id: Int
    public var x: Double
    public var y: Double
    public var area: Double
    public init(id: Int, x: Double, y: Double, area: Double = 1) { self.id = id; self.x = x; self.y = y; self.area = area }
}
public struct TouchFrame: Codable, Sendable {
    public var timestamp: Double
    public var deviceID: String
    public var contacts: [TouchPoint]
    public var modifiers: Modifiers
    public init(timestamp: Double, deviceID: String = "test", contacts: [TouchPoint], modifiers: Modifiers = []) { self.timestamp = timestamp; self.deviceID = deviceID; self.contacts = contacts; self.modifiers = modifiers }
}
public enum GestureState: String, Sendable { case idle, candidate, recognized, cancelled }
public struct RecognizedGesture: Equatable, Sendable {
    public var trigger: Trigger
    public var deviceID: String
    public var timestamp: Double
    public init(trigger: Trigger, deviceID: String, timestamp: Double) { self.trigger = trigger; self.deviceID = deviceID; self.timestamp = timestamp }
}
public struct GestureEngine: Sendable {
    struct Contact: Sendable { var start: TouchPoint; var last: TouchPoint; var began: Double; var peakArea: Double; var movement: Double }
    public private(set) var state: GestureState = .idle
    public private(set) var lastPeakArea: Double = 0
    public var tuning: Tuning
    private var contacts: [Int: Contact] = [:]
    private var group: Set<Int> = []
    private var started: Double = 0
    private var fingerCount = 0
    private var originX: Double = 0
    private var originY: Double = 0
    private var endX: Double = 0
    private var endY: Double = 0
    private var peakArea: Double = 0
    private var movement: Double = 0
    private var pinchStart: Double?
    private var modifiers: Modifiers = []
    private var device = ""
    private var lastTime: Double = 0
    private var waitForLift = false
    private var lastTap: (time: Double, device: String, fingers: Int, right: Bool, count: Int, modifiers: Modifiers)?
    public init(tuning: Tuning = .init()) { self.tuning = tuning }
    public mutating func cancel() { contacts.removeAll(); group.removeAll(); state = .idle; fingerCount = 0; pinchStart = nil; lastTap = nil; waitForLift = false }
    public mutating func cancelForNativeScroll() { state = .cancelled; lastTap = nil; waitForLift = true }
    public mutating func process(_ f: TouchFrame) -> [RecognizedGesture] {
        guard f.timestamp.isFinite, f.timestamp >= lastTime, f.contacts.count <= 16, f.contacts.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.area.isFinite && (0...1).contains($0.x) && (0...1).contains($0.y) }) else { cancel(); return [] }
        if device != f.deviceID && !contacts.isEmpty { cancel() }
        if lastTime > 0 && f.timestamp - lastTime > 0.5 && !contacts.isEmpty { cancel() }
        lastTime = f.timestamp; device = f.deviceID
        if waitForLift { if f.contacts.isEmpty { waitForLift = false; contacts.removeAll(); group.removeAll(); state = .idle }; return [] }
        let live = Set(f.contacts.map(\.id)); let existing = Set(contacts.keys)
        for t in f.contacts {
            if var c = contacts[t.id] { c.last = t; c.peakArea = max(c.peakArea, t.area); c.movement = max(c.movement, hypot(t.x - c.start.x, t.y - c.start.y)); contacts[t.id] = c }
            else { contacts[t.id] = Contact(start: t, last: t, began: f.timestamp, peakArea: t.area, movement: 0) }
        }
        let newIDs = live.subtracting(existing)
        if !newIDs.isEmpty && (state == .idle || (state == .cancelled && group.isDisjoint(with: live))) {
            let acceptable = newIDs.filter { id in guard let c = contacts[id] else { return false }; return c.start.x >= tuning.edgeMargin && c.start.x <= 1 - tuning.edgeMargin && c.start.y >= tuning.edgeMargin && c.start.y <= 1 - tuning.edgeMargin }
            if !acceptable.isEmpty {
                group = Set(acceptable); started = f.timestamp; state = .candidate; fingerCount = group.count; modifiers = f.modifiers
                let pts = group.compactMap { contacts[$0]?.start }; originX = pts.map(\.x).reduce(0,+) / Double(pts.count); originY = pts.map(\.y).reduce(0,+) / Double(pts.count)
                endX = originX; endY = originY; movement = 0; peakArea = 0; pinchStart = nil
            }
        } else if state == .candidate && f.timestamp - started < 0.08 {
            group.formUnion(newIDs.filter { id in guard let c = contacts[id] else { return false }; return c.start.x >= tuning.edgeMargin && c.start.x <= 1 - tuning.edgeMargin && c.start.y >= tuning.edgeMargin && c.start.y <= 1 - tuning.edgeMargin })
            if group.count > fingerCount {
                fingerCount = group.count
                let pts = group.compactMap { contacts[$0]?.start }; originX = pts.map(\.x).reduce(0,+) / Double(pts.count); originY = pts.map(\.y).reduce(0,+) / Double(pts.count)
            }
        }
        if fingerCount > 3 { state = .cancelled }
        let members = group.compactMap { contacts[$0] }
        if !members.isEmpty {
            peakArea = max(peakArea, members.map(\.peakArea).max() ?? 0)
            movement = max(movement, members.map(\.movement).max() ?? 0)
            endX = members.map { $0.last.x }.reduce(0,+) / Double(members.count)
            endY = members.map { $0.last.y }.reduce(0,+) / Double(members.count)
        }
        var result: [RecognizedGesture] = []
        func recognized(_ t: Trigger) -> RecognizedGesture { .init(trigger: t, deviceID: f.deviceID, timestamp: f.timestamp) }
        let activeMembers = members.filter { live.contains($0.last.id) }
        if state == .candidate && fingerCount == 2 && activeMembers.count == 2 {
            let a = activeMembers[0].last, b = activeMembers[1].last
            let distance = hypot(a.x - b.x, a.y - b.y)
            if pinchStart == nil { pinchStart = distance }
            if let initial = pinchStart, abs(distance - initial) >= tuning.pinchDistance {
                state = .recognized; lastTap = nil
                result.append(recognized(.init(kind: distance < initial ? .pinchIn : .pinchOut, modifiers: modifiers)))
            }
        }
        if state == .candidate {
            let dx = endX - originX, dy = endY - originY
            if max(abs(dx), abs(dy)) >= tuning.swipeDistance && (fingerCount > 1 || abs(dx) > abs(dy) * 1.5) {
                let d: Direction = abs(dx) > abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .up : .down)
                state = .recognized; lastTap = nil
                result.append(recognized(.init(kind: .swipe, fingers: min(fingerCount, 3), direction: d, modifiers: modifiers)))
            } else if movement < tuning.tapMovement, f.timestamp - started >= tuning.holdDelay, let tap = lastTap, tap.device == f.deviceID, started - tap.time <= tuning.multiTapInterval {
                state = .recognized; lastTap = nil
                result.append(recognized(.init(kind: .touchHold, fingers: min(fingerCount, 3), modifiers: modifiers)))
            } else if f.timestamp - started > tuning.restingDelay { state = .cancelled; group.removeAll() }
        }
        if !group.isEmpty && group.isDisjoint(with: live) {
            if state == .candidate && f.timestamp - started <= tuning.tapDuration && movement < tuning.tapMovement && peakArea >= tuning.contactArea && (1...3).contains(fingerCount) {
                lastPeakArea = peakArea
                let right = fingerCount == 1 && originX >= tuning.rightZone
                var count = 1
                if let t = lastTap, f.timestamp - t.time <= tuning.multiTapInterval, t.device == f.deviceID, t.fingers == fingerCount, t.right == right, t.modifiers == modifiers { count = t.count % 3 + 1 }
                lastTap = (f.timestamp, f.deviceID, fingerCount, right, count, modifiers)
                result.append(recognized(.init(kind: right ? .rightTap : .tap, fingers: fingerCount, clicks: count, modifiers: modifiers)))
            }
            group.removeAll(); state = .idle; pinchStart = nil
        }
        contacts = contacts.filter { live.contains($0.key) }
        return result
    }
}

public struct MultiTapDispatcher: Sendable {
    private var pending: (gesture: RecognizedGesture, deadline: Double)?
    public var hasPendingWork: Bool { pending != nil }
    public init() {}
    public mutating func submit(_ g: RecognizedGesture, hasHigherTap: Bool, interval: Double) -> [RecognizedGesture] {
        var emitted: [RecognizedGesture] = []
        if let p = pending, p.gesture.deviceID != g.deviceID || p.gesture.trigger.fingers != g.trigger.fingers || p.gesture.trigger.kind != g.trigger.kind || p.gesture.trigger.modifiers != g.trigger.modifiers { emitted.append(p.gesture); pending = nil }
        if hasHigherTap { pending = (g, g.timestamp + interval) } else { pending = nil; emitted.append(g) }
        return emitted
    }
    public mutating func advance(_ time: Double) -> [RecognizedGesture] {
        guard let p = pending, time >= p.deadline else { return [] }; pending = nil; return [p.gesture]
    }
    public mutating func cancel() { pending = nil }
}
