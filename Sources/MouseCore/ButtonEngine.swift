import Foundation
public struct ButtonResult: Sendable {
    public var suppress: Bool
    public var triggers: [Trigger]
    /// Primary buttons that should resume their original native drag.
    public var nativeDrags: [Int] = []
    public init(suppress: Bool = false, triggers: [Trigger] = []) { self.suppress = suppress; self.triggers = triggers }
}
public struct ButtonEngine: Sendable {
    struct Press: Sendable { var time: Double; var x: Double; var y: Double; var modifiers: Modifiers; var handled: Bool; var hold: Bool }
    struct Pending: Sendable { var trigger: Trigger; var deadline: Double; var count: Int }
    private var presses: [Int: Press] = [:]
    private var pending: [Int: Pending] = [:]
    public var tuning: Tuning
    public init(tuning: Tuning = .init()) { self.tuning = tuning }
    public mutating func cancel() { presses.removeAll(); pending.removeAll() }
    public var hasPendingWork: Bool { !presses.isEmpty || !pending.isEmpty }
    public var heldButtons: [Int] { presses.keys.sorted() }
    public mutating func down(button: Int, x: Double, y: Double, time: Double, modifiers: Modifiers, bindings: [Trigger]) -> ButtonResult {
        guard button >= 0 else { return .init() }
        let possible = bindings.filter { $0.button == button && $0.modifiers == modifiers && [.button, .buttonHold, .buttonDrag, .buttonWheel, .buttonChord].contains($0.kind) }
        let chordAsSecondary = bindings.contains { $0.kind == .buttonChord && $0.chordButton == button && $0.modifiers == modifiers }
        guard !possible.isEmpty || chordAsSecondary else { return .init() }
        presses[button] = Press(time: time, x: x, y: y, modifiers: modifiers, handled: false, hold: possible.contains { $0.kind == .buttonHold })
        for t in bindings where t.kind == .buttonChord && t.modifiers == modifiers && presses[t.button] != nil && presses[t.chordButton] != nil {
            presses[t.button]?.handled = true; presses[t.chordButton]?.handled = true; pending[t.button] = nil; pending[t.chordButton] = nil
            return .init(suppress: true, triggers: [t])
        }
        return .init(suppress: true)
    }
    public mutating func up(button: Int, time: Double, bindings: [Trigger]) -> ButtonResult {
        guard let press = presses.removeValue(forKey: button) else { return .init() }
        guard !press.handled else { return .init(suppress: true) }
        let previous = pending.removeValue(forKey: button)
        let count = previous != nil && time <= previous!.deadline && previous!.trigger.modifiers == press.modifiers ? previous!.count % 3 + 1 : 1
        let t = Trigger(kind: .button, button: button, clicks: count, modifiers: press.modifiers)
        let higher = bindings.contains { $0.kind == .button && $0.button == button && $0.modifiers == press.modifiers && $0.clicks > count }
        if higher { pending[button] = Pending(trigger: t, deadline: time + tuning.multiTapInterval, count: count); return .init(suppress: true) }
        return .init(suppress: true, triggers: bindings.contains(t) || button < 2 ? [t] : [])
    }
    public mutating func move(x: Double, y: Double, bindings: [Trigger]) -> ButtonResult {
        var triggers: [Trigger] = []
        var nativeDrags: [Int] = []
        for b in presses.keys.sorted() {
            guard var p = presses[b], !p.handled else { continue }
            let dx = x - p.x, dy = y - p.y
            guard max(abs(dx), abs(dy)) >= (b < 2 ? min(3, tuning.dragDistance) : tuning.dragDistance) else { continue }
            if b < 2 { presses[b] = nil; pending[b] = nil; nativeDrags.append(b); continue }
            let d: Direction = abs(dx) > abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .down : .up)
            let t = Trigger(kind: .buttonDrag, button: b, direction: d, modifiers: p.modifiers)
            if bindings.contains(t) { triggers.append(t); p.handled = true; presses[b] = p }
        }
        var result = ButtonResult(suppress: false, triggers: triggers)
        result.nativeDrags = nativeDrags
        return result
    }
    public mutating func wheel(x: Double, y: Double, modifiers: Modifiers, bindings: [Trigger]) -> ButtonResult {
        guard x != 0 || y != 0 else { return .init() }
        for b in presses.keys.sorted() {
            let d: Direction = abs(x) > abs(y) ? (x > 0 ? .left : .right) : (y > 0 ? .up : .down)
            let t = Trigger(kind: .buttonWheel, button: b, direction: d, modifiers: modifiers)
            if bindings.contains(t) { presses[b]?.handled = true; return .init(suppress: true, triggers: [t]) }
        }
        return .init()
    }
    public mutating func advance(time: Double, bindings: [Trigger]) -> [Trigger] {
        var result: [Trigger] = []
        for b in pending.keys.sorted() { if let p = pending[b], time >= p.deadline { if bindings.contains(p.trigger) || b < 2 { result.append(p.trigger) }; pending[b] = nil } }
        for b in presses.keys.sorted() {
            guard let p = presses[b], !p.handled, p.hold, time - p.time >= tuning.holdDelay else { continue }
            let t = Trigger(kind: .buttonHold, button: b, modifiers: p.modifiers)
            if bindings.contains(t) { presses[b]?.handled = true; result.append(t) }
        }
        return result
    }
}
