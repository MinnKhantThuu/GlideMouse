import Foundation
public struct ScrollDelta: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var phase: Int
    public var momentumPhase: Int
    public init(x: Double, y: Double, phase: Int = 0, momentumPhase: Int = 0) { self.x = x; self.y = y; self.phase = phase; self.momentumPhase = momentumPhase }
}
public struct ScrollEngine: Sendable {
    private var remainingX: Double = 0
    private var remainingY: Double = 0
    private var active = false
    private var began = false
    private var momentum = false
    private var momentumBegan = false
    private var lastInput: Double = 0
    private var lastTick: Double = 0
    private var settings = ScrollSettings()
    public init() {}
    public var isActive: Bool { active }
    public mutating func receive(x: Double, y: Double, timestamp: Double, continuous: Bool, modifiers: Modifiers, settings: ScrollSettings) -> ScrollDelta? {
        guard !continuous, settings.enabled, x.isFinite, y.isFinite, timestamp.isFinite else { return nil }
        self.settings = settings
        var dx = x, dy = y
        if settings.shiftHorizontal && modifiers.contains(.shift) { dx += dy; dy = 0 }
        if settings.reverseVertical { dy = -dy }; if settings.reverseHorizontal { dx = -dx }
        let precision = settings.precisionModifier && modifiers.contains(.control) ? 0.2 : 1.0
        let acceleration = 1 + settings.acceleration * min(4, abs(dx) + abs(dy))
        dx *= settings.speed * acceleration * precision * 12; dy *= settings.speed * acceleration * precision * 12
        if settings.smoothness == .off { return .init(x: dx, y: dy) }
        var transition: ScrollDelta?
        if momentum { transition = .init(x: 0,y: 0,momentumPhase: 3); momentum = false; momentumBegan = false; began = false }
        if !active { active = true; began = false; lastTick = timestamp }
        if dx * remainingX < 0 { remainingX = 0 }; if dy * remainingY < 0 { remainingY = 0 }
        remainingX = max(-4000, min(4000, remainingX + dx)); remainingY = max(-4000, min(4000, remainingY + dy)); lastInput = timestamp
        return transition
    }
    public mutating func tick(_ time: Double) -> ScrollDelta? {
        guard active, time.isFinite, time >= lastTick else { return nil }
        let dt = min(0.05, max(0.001, time - lastTick)); lastTick = time
        if abs(remainingX) + abs(remainingY) < 0.02 { let wasMomentum = momentum; active = false; remainingX = 0; remainingY = 0; momentum = false; momentumBegan = false; began = false; return .init(x: 0, y: 0, phase: wasMomentum ? 0 : 4, momentumPhase: wasMomentum ? 3 : 0) }
        if settings.momentum && began && !momentum && time - lastInput > 0.08 { momentum = true; return .init(x: 0,y: 0,phase: 4) }
        let tau = settings.smoothness == .high ? (settings.momentum ? 0.18 : 0.1) : (settings.momentum ? 0.1 : 0.055)
        let amount = 1 - exp(-dt / tau)
        let dx = remainingX * amount, dy = remainingY * amount
        remainingX -= dx; remainingY -= dy
        if momentum { let phase = momentumBegan ? 2 : 1; momentumBegan = true; return .init(x: dx,y: dy,momentumPhase: phase) }
        let phase = began ? 2 : 1; began = true
        return .init(x: dx, y: dy, phase: phase)
    }
    public mutating func cancel() -> ScrollDelta? {
        let wasActive = active, wasMomentum = momentum
        active = false; remainingX = 0; remainingY = 0; began = false; momentum = false; momentumBegan = false
        return wasActive ? .init(x: 0, y: 0, phase: wasMomentum ? 0 : 8, momentumPhase: wasMomentum ? 3 : 0) : nil
    }
}
