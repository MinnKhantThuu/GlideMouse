import Foundation
import AppKit
@preconcurrency import ApplicationServices
import MouseCore

/// Software integration checks in an empty, owned window. Does not load/save user settings.
@MainActor enum PrimaryButtonHarness {
    private final class Collector: @unchecked Sendable {
        static let testTag: Int64 = 0x5052494D415259
        private let lock = NSLock()
        private var delivered: [(CGEventType, Int64, CGPoint, Int64)] = []
        private var actions: [Trigger] = []
        func record(_ type: CGEventType, _ event: CGEvent) {
            let tag = event.getIntegerValueField(.eventSourceUserData)
            guard tag == Self.testTag || tag == syntheticTag else { return }
            lock.lock(); defer { lock.unlock() }
            delivered.append((type, event.getIntegerValueField(.mouseEventClickState), event.location, Int64(event.flags.rawValue)))
        }
        func action(_ trigger: Trigger) { lock.lock(); defer { lock.unlock() }; actions.append(trigger) }
        func clear() { lock.lock(); defer { lock.unlock() }; delivered.removeAll(); actions.removeAll() }
        func snapshot() -> ([(CGEventType, Int64, CGPoint, Int64)], [Trigger]) { lock.lock(); defer { lock.unlock() }; return (delivered, actions) }
    }
    static func run() -> Int32 {
        guard AXIsProcessTrusted(), CGPreflightListenEventAccess() else { print("SKIP: permissions unavailable"); return 77 }
        let app = NSApplication.shared; app.setActivationPolicy(.regular); app.finishLaunching()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 300), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "GlideMouse — Software primary-button regression"; window.contentView = NSView(); window.center(); window.makeKeyAndOrderFront(nil); app.activate(ignoringOtherApps: true)
        let point = CGPoint(x: window.frame.midX, y: (NSScreen.main?.frame.height ?? 900) - window.frame.midY)
        let collector = Collector()
        let types: [CGEventType] = [.leftMouseDown,.leftMouseUp,.leftMouseDragged,.rightMouseDown,.rightMouseUp,.rightMouseDragged]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly, eventsOfInterest: mask, callback: { _,type,event,user in
            if let user { Unmanaged<Collector>.fromOpaque(user).takeUnretainedValue().record(type,event) }; return Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(collector).toOpaque()) else { return 1 }
        let tapSource = CFMachPortCreateRunLoopSource(nil, tap, 0)!
        CFRunLoopAddSource(CFRunLoopGetMain(), tapSource, .defaultMode); CGEvent.tapEnable(tap: tap, enable: true)
        let runtime = InputRuntime(report: { _ in }, action: { collector.action($0.mapping.trigger) }, cancellation: {}, pause: {}, drag: { _,_ in })
        let source = CGEventSource(stateID: .privateState)!
        source.userData = Collector.testTag; source.localEventsSuppressionInterval = 0
        func pump(_ seconds: Double) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }
        func post(_ type: CGEventType, _ button: Int, count: Int = 1, at: CGPoint? = nil, flags: CGEventFlags = []) {
            let e = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: at ?? point, mouseButton: button == 0 ? .left : .right)!
            e.flags = flags; e.setIntegerValueField(.mouseEventClickState, value: Int64(count)); e.setIntegerValueField(.eventSourceUserData, value: Collector.testTag); e.post(tap: .cgSessionEventTap); pump(0.04)
        }
        var c = Configuration(); c.engineEnabled = true; c.tuning.multiTapInterval = 0.2; c.tuning.holdDelay = 0.25
        runtime.apply(c, bundleID: nil, magicMousePresent: false); pump(0.4)
        var checks: [String: Bool] = [:]
        collector.clear(); post(.leftMouseDown, 0); post(.leftMouseUp, 0); pump(0.05)
        checks["unmappedPrimaryNativeImmediately"] = collector.snapshot().0.count == 2 && collector.snapshot().1.isEmpty
        c.globalDefaults.mappings = (0...1).flatMap { b in [Mapping(trigger: .init(kind: .button, button: b, clicks: 2), action: .missionControl), Mapping(trigger: .init(kind: .buttonHold, button: b), action: .quickLook)] }
        runtime.apply(c, bundleID: nil, magicMousePresent: false); pump(0.3)
        for button in 0...1 {
            let down: CGEventType = button == 0 ? .leftMouseDown : .rightMouseDown
            let up: CGEventType = button == 0 ? .leftMouseUp : .rightMouseUp
            let drag: CGEventType = button == 0 ? .leftMouseDragged : .rightMouseDragged
            collector.clear(); post(down, button); post(up, button); pump(0.35)
            let single = collector.snapshot()
            checks["button\(button+1)NativeSingleReplay"] = single.1.isEmpty && single.0.map(\.0) == [down, up] && single.0.allSatisfy { $0.2 == point }
            collector.clear(); post(down, button); post(up, button); post(down, button, count: 2); post(up, button, count: 2); pump(0.3)
            let double = collector.snapshot()
            checks["button\(button+1)DoubleActionOnceWithoutNativeClick"] = double.0.isEmpty && double.1 == [Trigger(kind: .button, button: button, clicks: 2)]
            collector.clear(); post(down, button); pump(0.4); post(up, button); pump(0.1)
            let hold = collector.snapshot()
            checks["button\(button+1)HoldActionOnceWithoutNativeClick"] = hold.0.isEmpty && hold.1 == [Trigger(kind: .buttonHold, button: button)]
            collector.clear(); post(down, button); let moved = CGPoint(x: point.x + 10, y: point.y); post(drag, button, at: moved); post(up, button, at: moved); pump(0.35)
            let dragged = collector.snapshot()
            checks["button\(button+1)NativeDragOrdered"] = dragged.1.isEmpty && dragged.0.map(\.0) == [down,drag,up] && dragged.0.first?.2 == point && dragged.0.last?.2 == moved
            collector.clear(); post(down, button, flags: .maskShift); post(up, button, flags: .maskShift); pump(0.1)
            checks["button\(button+1)ModifierMismatchNative"] = collector.snapshot().0.count == 2 && collector.snapshot().1.isEmpty
        }
        collector.clear(); post(.leftMouseDown, 0); runtime.apply(c, bundleID: nil, magicMousePresent: false); pump(0.15); post(.leftMouseUp, 0); pump(0.3)
        let resetSnapshot = collector.snapshot()
        checks["configurationResetBalancesNativePress"] = resetSnapshot.0.map(\.0) == [.leftMouseDown,.leftMouseUp] && resetSnapshot.1.isEmpty
        runtime.setCaptureArea(CGRect(x: point.x - 20, y: point.y - 20, width: 40, height: 40)); pump(0.15)
        collector.clear(); post(.leftMouseDown, 0); pump(0.4); post(.leftMouseUp, 0); pump(0.25)
        checks["captureAreaDoesNotExecuteHold"] = collector.snapshot().0.map(\.0) == [.leftMouseDown,.leftMouseUp] && collector.snapshot().1.isEmpty
        runtime.setCaptureArea(nil); pump(0.1)
        c.globalDefaults.mappings = [Mapping(trigger: .init(kind: .buttonHold, button: 0), action: .quickLook)]
        runtime.apply(c, bundleID: nil, magicMousePresent: false); pump(0.3)
        collector.clear(); post(.leftMouseDown, 0); post(.leftMouseUp, 0); post(.leftMouseDown, 0, count: 2); post(.leftMouseUp, 0, count: 2); pump(0.15)
        checks["holdOnlyKeepsNativeDoubleClickCount"] = collector.snapshot().0.map(\.1) == [1,1,2,2] && collector.snapshot().1.isEmpty
        c.globalDefaults.mappings = [Mapping(trigger: .init(kind: .buttonHold, button: 0, modifiers: .shift), action: .quickLook)]
        runtime.apply(c, bundleID: nil, magicMousePresent: false); pump(0.3)
        collector.clear(); post(.leftMouseDown, 0, flags: .maskShift); post(.leftMouseUp, 0, flags: .maskShift); pump(0.15)
        checks["nativeReplayKeepsModifiers"] = collector.snapshot().0.count == 2 && collector.snapshot().0.allSatisfy { (CGEventFlags(rawValue: UInt64($0.3)).intersection([.maskShift,.maskControl,.maskAlternate,.maskCommand])) == .maskShift } && collector.snapshot().1.isEmpty
        runtime.shutdown(); pump(0.15); CFMachPortInvalidate(tap); window.orderOut(nil)
        let output: [String: Any] = ["checks":checks, "allPassed":checks.values.allSatisfy { $0 }, "hardwareTest":false, "userSettingsWritten":false, "resetEvents":resetSnapshot.0.map { ["type":$0.0.rawValue, "count":$0.1] }, "resetActions":resetSnapshot.1.map { $0.kind.rawValue }]
        if let data = try? JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted,.sortedKeys]) { print(String(decoding: data, as: UTF8.self)) }
        return checks.values.allSatisfy { $0 } ? 0 : 1
    }
}
