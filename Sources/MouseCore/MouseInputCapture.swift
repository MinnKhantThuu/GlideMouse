import Foundation

/// Captures a physical mouse-button gesture without executing any action.
public struct MouseInputCapture: Sendable {
    private struct Press: Sendable { var x: Double; var y: Double; var time: Double; var modifiers: Modifiers; var clicks: Int; var used = false }
    private var presses: [Int: Press] = [:]
    public var holdDelay: Double = 0.4
    public var dragDistance: Double = 35
    public init() {}
    public mutating func reset() { presses.removeAll() }
    public mutating func down(button: Int, x: Double, y: Double, time: Double, clicks: Int, modifiers: Modifiers) -> Trigger? {
        guard button >= 0 else { return nil }
        let previous = presses.keys.sorted().first
        presses[button] = Press(x: x,y: y,time: time,modifiers: modifiers,clicks: max(1,min(3,clicks)))
        if let previous, previous != button {
            presses[previous]?.used = true; presses[button]?.used = true
            return Trigger(kind: .buttonChord,button: previous,modifiers: modifiers,chordButton: button).canonical
        }
        return nil
    }
    public mutating func up(button: Int, time: Double) -> Trigger? {
        guard let p = presses.removeValue(forKey: button), !p.used else { return nil }
        return Trigger(kind: time-p.time >= holdDelay ? .buttonHold : .button,button: button,clicks: p.clicks,modifiers: p.modifiers).canonical
    }
    public mutating func move(x: Double, y: Double) -> Trigger? {
        guard let b = presses.keys.sorted().first, var p = presses[b], !p.used else { return nil }
        let dx = x-p.x, dy = y-p.y
        guard max(abs(dx),abs(dy)) >= dragDistance else { return nil }
        p.used = true; presses[b] = p
        let direction: Direction = abs(dx)>abs(dy) ? (dx>0 ? .right : .left) : (dy>0 ? .down : .up)
        return Trigger(kind: .buttonDrag,button: b,direction: direction,modifiers: p.modifiers).canonical
    }
    public mutating func wheel(x: Double, y: Double, modifiers: Modifiers) -> Trigger? {
        guard let b = presses.keys.sorted().first, x != 0 || y != 0 else { return nil }
        presses[b]?.used = true
        let direction: Direction = abs(x)>abs(y) ? (x>0 ? .left : .right) : (y>0 ? .up : .down)
        return Trigger(kind: .buttonWheel,button: b,direction: direction,modifiers: modifiers).canonical
    }
}
