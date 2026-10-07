import Foundation
import CoreGraphics
@preconcurrency import ApplicationServices
import NativeBridge
import MouseCore

struct InputRecord: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var time: Double
    var kind: String
    var detail: String
    var action: String?
    var source: String?
}
struct RuntimeReport: Equatable, Sendable {
    var status = "Paused"
    var events: UInt64 = 0
    var injectedIgnored: UInt64 = 0
    var timeouts = 0
    var maximumCallbackMS: Double = 0
    var callbacks: [Double] = []
    var records: [InputRecord] = []
    var touchStatus = "Not probed"
    var touchDevices: [TouchDeviceInfo] = []
    var contacts: [TouchPoint] = []
    var touchDrops: UInt64 = 0
    var lastPeakArea: Double = 0
    var active = false
    var learningButton: Int?
    var observedButtons: Set<Int> = []
    var lastObservedButton: Int?
    var lastObservedTime: Double = 0
    var actionDispatchMS: [Double] = []
    var fastDesktopActions: UInt64 = 0
}
struct ActionRequest: Sendable { var mapping: Mapping; var source: String; var epoch: Int; var touchHold: Bool = false; var recognizedAt: Double = ProcessInfo.processInfo.systemUptime; var alreadyInjected: Bool = false }

/// All mutable engine state is confined to its dedicated CFRunLoop thread.
/// Public entry points enqueue immutable snapshots; the small lock protects only loop/epoch handles.
final class InputRuntime: @unchecked Sendable {
    private let lock = NSLock()
    private var loop: CFRunLoop?
    private var pendingBlocks: [@Sendable () -> Void] = []
    private var currentEpoch = 0
    private var thread: Thread?
    private var tap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private var timer: Timer?
    private var fastTimer = false
    private var configuration = Configuration()
    private var bundleID: String?
    private var report = RuntimeReport()
    private var buttons = ButtonEngine()
    private var gestures = GestureEngine()
    private var taps = MultiTapDispatcher()
    private var scrolling = ScrollEngine()
    private var deliveredReport: RuntimeReport?
    private var lastReport: Double = 0
    private var lastPermissionCheck: Double = 0
    private var epoch = 0
    private var retries = 0
    private var allowMagic = false
    private var touchRunning = false
    private var touchHeld = false
    private var touchDrag = TouchDragSession()
    private var touchFrameOffset: Double?
    private var lastTouchReceived: Double = 0
    private var touchDeviceID: String?
    private var nativeScrollUntil: Double = 0
    private var droppedLast: UInt64 = 0
    private var dragPointer = false
    private var panOrigin: CGPoint?
    private var captureRect: CGRect?
    private var captureOwner: UUID?
    private var captureButtons = Set<Int>()
    private var learning = false
    private var consumedButtons = Set<Int>()
    // Original events preserve location, modifiers and native click counts when a
    // primary press is not a mapped hold/double. No synthetic replacement click.
    private var primaryEvents: [Int: [CGEvent]] = [:]
    private var nativePrimaryDrags = Set<Int>()
    private func finishPrimary(_ trigger: Trigger, replay: Bool) {
        guard trigger.button < 2, let events = primaryEvents[trigger.button] else { return }
        let count = trigger.kind == .buttonHold ? events.count : min(events.count, trigger.clicks * 2)
        let finished = events.prefix(count)
        let remaining = Array(events.dropFirst(count))
        primaryEvents[trigger.button] = remaining.isEmpty ? nil : remaining
        if replay { finished.forEach { Injection.replay($0) } }
    }
    private let reportHandler: @Sendable (RuntimeReport) -> Void
    private let actionHandler: @Sendable (ActionRequest) -> Void
    private let cancellationHandler: @Sendable () -> Void
    private let pauseHandler: @Sendable () -> Void
    private let dragHandler: @Sendable (CGPoint, Bool) -> Void
    private let fastDesktopAction: @Sendable (MouseAction) -> Bool
    init(report: @escaping @Sendable (RuntimeReport) -> Void, action: @escaping @Sendable (ActionRequest) -> Void, cancellation: @escaping @Sendable () -> Void, pause: @escaping @Sendable () -> Void, drag: @escaping @Sendable (CGPoint,Bool) -> Void, fastDesktopAction: @escaping @Sendable (MouseAction) -> Bool = Injection.desktopAction) {
        reportHandler = report; actionHandler = action; cancellationHandler = cancellation; pauseHandler = pause; dragHandler = drag
        self.fastDesktopAction = fastDesktopAction
        let worker = Thread { [weak self] in self?.run() }; worker.name = "GlideMouse.Input"; worker.qualityOfService = .userInteractive; thread = worker; worker.start()
    }
    private func run() {
        let l = CFRunLoopGetCurrent()!
        scheduleTimer(fast: false)
        lock.lock(); loop = l; let pending = pendingBlocks; pendingBlocks.removeAll(); lock.unlock()
        let probe = TouchProbe.run(); report.touchStatus = probe.status; report.touchDevices = probe.devices
        pending.forEach { $0() }
        CFRunLoopRun()
        timer?.invalidate(); timer = nil
        stopTap(); gm_touch_stop(); thread = nil
    }
    private func scheduleTimer(fast: Bool) {
        if timer != nil && fastTimer == fast { return }
        timer?.invalidate(); fastTimer = fast
        let t = Timer(timeInterval: fast ? 1.0/120.0 : 0.25, repeats: true) { [weak self] _ in self?.tick() }
        t.tolerance = fast ? 0.001 : 0.05; timer = t; RunLoop.current.add(t, forMode: .default)
    }
    private func enqueue(_ block: @escaping @Sendable () -> Void) {
        lock.lock()
        guard let loop else { pendingBlocks.append(block); lock.unlock(); return }
        lock.unlock()
        CFRunLoopPerformBlock(loop, CFRunLoopMode.defaultMode.rawValue, block); CFRunLoopWakeUp(loop)
    }
    func apply(_ c: Configuration, bundleID: String?, magicMousePresent: Bool) {
        enqueue { [weak self] in guard let self else { return }; self.stopTap(); self.reset(); self.configuration = c; self.bundleID = bundleID; self.allowMagic = magicMousePresent
            self.buttons.tuning = c.tuning; self.gestures.tuning = c.tuning; self.retries = 0
            if c.engineEnabled { self.startTap() } else { self.stopTap(); self.report.status = "Paused" }
            self.configureTouch()
        }
    }
    func focusChanged(_ id: String?) { enqueue { [weak self] in guard let self else { return }; self.reset(); self.bundleID = id } }
    func setDragging(_ active: Bool, epoch expected: Int? = nil) { enqueue { [weak self] in guard let self, expected == nil || expected == self.epoch else { return }; self.dragPointer = active } }
    func setCaptureArea(_ rect: CGRect?, owner: UUID? = nil) {
        enqueue { [weak self] in
            guard let self else { return }
            if rect == nil, let owner, self.captureOwner != owner { return }
            self.captureOwner = rect == nil ? nil : owner
            guard self.captureRect != rect else { return }
            self.captureRect = rect
            if rect == nil { self.captureButtons.removeAll() }
            if !self.configuration.engineEnabled {
                if rect != nil { self.startTap(listenOnly: true) }
                else { self.stopTap(); self.report.status = "Paused" }
            }
        }
    }
    func beginLearning() { enqueue { [weak self] in guard let self else { return }; self.stopTap(); self.reset(); self.learning = true; self.report.learningButton = nil; self.startTap(listenOnly: true) } }
    func endLearning() { enqueue { [weak self] in guard let self else { return }; self.learning = false; self.stopTap(); if self.configuration.engineEnabled { self.startTap() } } }
    func recordDispatch(recognizedAt: Double) {
        let milliseconds = max(0, (ProcessInfo.processInfo.systemUptime - recognizedAt) * 1000)
        enqueue { [weak self] in
            guard let self else { return }
            self.report.actionDispatchMS.append(milliseconds)
            if self.report.actionDispatchMS.count > 100 { self.report.actionDispatchMS.removeFirst() }
        }
    }
    func clearDiagnostics() { enqueue { [weak self] in self?.report.records = []; self?.report.callbacks = [] } }
    func suspend() { enqueue { [weak self] in guard let self else { return }; self.stopTap(); self.reset(); gm_touch_stop(); self.touchRunning = false; self.report.status = "Suspended" } }
    func shutdown() { enqueue { [weak self] in guard let self else { return }; self.stopTap(); self.reset(); gm_touch_stop(); if let l = self.loop { CFRunLoopStop(l) } } }
    func isCurrent(_ e: Int) -> Bool { lock.lock(); defer { lock.unlock() }; return e == currentEpoch }
    private func reset() {
        epoch += 1; lock.lock(); currentEpoch = epoch; lock.unlock()
        for (button, events) in primaryEvents { events.forEach { Injection.replay($0) }; consumedButtons.remove(button) }
        primaryEvents.removeAll()
        for button in nativePrimaryDrags {
            if let up = CGEvent(mouseEventSource: nil, mouseType: button == 0 ? .leftMouseUp : .rightMouseUp, mouseCursorPosition: Injection.pointer(), mouseButton: button == 0 ? .left : .right) { Injection.post(up) }
        }
        nativePrimaryDrags.removeAll()
        buttons.cancel(); captureButtons.removeAll(); gestures.cancel(); taps.cancel(); touchHeld = false; if let end = touchDrag.cancel() { Injection.scroll(end) }; touchFrameOffset = nil; panOrigin = nil; dragPointer = false
        if let end = scrolling.cancel() { Injection.scroll(end) }
        cancellationHandler()
    }
    private func configureTouch() {
        gm_touch_stop(); touchRunning = false
        guard configuration.engineEnabled, configuration.touchEnabled, allowMagic, AXIsProcessTrusted(), CGPreflightListenEventAccess() else { report.touchStatus = allowMagic ? "Experimental adapter disabled" : "No Magic Mouse connected"; return }
        let probe = TouchProbe.run(); report.touchDevices = probe.devices
        guard let candidate = probe.devices.first(where: { $0.candidate }), gm_touch_start(Int32(candidate.id)) else { report.touchStatus = String(cString: gm_touch_status()); return }
        touchDeviceID = "mt:\(candidate.id)"
        touchRunning = true; report.touchStatus = String(cString: gm_touch_status())
    }
    private func startTap(listenOnly: Bool = false) {
        stopTap()
        guard CGPreflightListenEventAccess(), listenOnly || AXIsProcessTrusted() else { report.status = "Permissions needed"; return }
        let types: [CGEventType] = [.otherMouseDown,.otherMouseUp,.otherMouseDragged,.mouseMoved,.leftMouseDown,.leftMouseUp,.leftMouseDragged,.rightMouseDown,.rightMouseUp,.rightMouseDragged,.scrollWheel,.keyDown]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: listenOnly ? .listenOnly : .defaultTap, eventsOfInterest: mask, callback: { _, type, event, user in
            guard let user else { return Unmanaged.passUnretained(event) }
            let runtime = Unmanaged<InputRuntime>.fromOpaque(user).takeUnretainedValue()
            return runtime.handle(type, event: event) ? nil : Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap else { report.status = "Event tap unavailable. Check permissions and reopen the app."; return }
        tapSource = CFMachPortCreateRunLoopSource(nil, tap, 0)
        if let source = tapSource, let loop { CFRunLoopAddSource(loop, source, .defaultMode) }
        CGEvent.tapEnable(tap: tap, enable: true); report.status = listenOnly ? "Learning button" : "Active"; report.active = !listenOnly
    }
    private func stopTap() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source = tapSource, let loop { CFRunLoopRemoveSource(loop, source, .defaultMode) }
        tap = nil; tapSource = nil; report.active = false
    }
    private func bindings(deviceID: String? = nil) -> [Trigger] {
        let profiles = ProfileResolver.eligible(bundleID: bundleID, deviceID: deviceID, profiles: configuration.profiles + [configuration.globalDefaults])
        var seen = Set<Trigger>(), result: [Trigger] = []
        for p in profiles {
            if p.paused { break }
            for m in p.mappings where seen.insert(m.trigger.canonical).inserted { if m.enabled { result.append(m.trigger.canonical) } }
        }
        return result
    }
    private func emit(_ trigger: Trigger, deviceID: String? = nil, touchHold: Bool = false) {
        guard let r = ProfileResolver.resolveGesture(trigger: trigger, bundleID: bundleID, deviceID: deviceID, profiles: configuration.profiles + [configuration.globalDefaults]), r.mapping.enabled, !r.paused else { finishPrimary(trigger, replay: true); return }
        finishPrimary(trigger, replay: false)
        if r.mapping.action == .canvasPan && trigger.kind == .buttonDrag { panOrigin = Injection.pointer(); return }
        record("recognized", detail: trigger.kind.rawValue, action: r.mapping.action.rawValue, source: r.source)
        var effective = r.mapping; effective.trigger = trigger
        let recognizedAt = ProcessInfo.processInfo.systemUptime
        // Space switching must not wait behind SwiftUI layout, popovers or sheets.
        // Hold/double-click recognition still runs in ButtonEngine before this point.
        let touchWithModifiers = MagicMouseCatalog.touchKinds.contains(trigger.kind) && !Modifiers(cgFlags: CGEventSource.flagsState(.combinedSessionState)).isEmpty
        let injected = !touchWithModifiers && [.spaceLeft, .spaceRight].contains(effective.action) && fastDesktopAction(effective.action)
        if injected {
            report.fastDesktopActions += 1
            report.actionDispatchMS.append((ProcessInfo.processInfo.systemUptime - recognizedAt) * 1000)
            if report.actionDispatchMS.count > 100 { report.actionDispatchMS.removeFirst() }
        }
        actionHandler(.init(mapping: effective, source: r.source, epoch: epoch, touchHold: touchHold, recognizedAt: recognizedAt, alreadyInjected: injected))
    }
    private func record(_ kind: String, detail: String, action: String? = nil, source: String? = nil) {
        // No key content, screenshots or user text is captured.
        report.records.append(.init(time: ProcessInfo.processInfo.systemUptime, kind: kind, detail: detail, action: action, source: source))
        if report.records.count > 100 { report.records.removeFirst(report.records.count - 100) }
    }
    private func handle(_ type: CGEventType, event: CGEvent) -> Bool {
        let start = ProcessInfo.processInfo.systemUptime
        defer {
            let ms = (ProcessInfo.processInfo.systemUptime - start) * 1000
            report.maximumCallbackMS = max(report.maximumCallbackMS, ms); report.callbacks.append(ms)
            if report.callbacks.count > 500 { report.callbacks.removeFirst(100) }
            scheduleTimer(fast: buttons.hasPendingWork || scrolling.isActive || touchRunning || taps.hasPendingWork)
        }
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            report.timeouts += 1; reset(); retries += 1
            if retries <= 3, type == .tapDisabledByTimeout, let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            else { stopTap(); gm_touch_stop(); touchRunning = false; report.status = "Input tap stopped. Pause and enable to retry." }
            return false
        }
        if event.getIntegerValueField(.eventSourceUserData) == syntheticTag { report.injectedIgnored += 1; return false }
        let mods = Modifiers(cgFlags: event.flags)
        if type == .keyDown {
            if event.getIntegerValueField(.keyboardEventKeycode) == 53, mods == [.command,.option,.control] { configuration.engineEnabled = false; reset(); stopTap(); gm_touch_stop(); touchRunning = false; report.status = "Emergency pause"; pauseHandler(); return true }
            return false
        }
        report.events += 1
        if type == .leftMouseDown || type == .rightMouseDown { if touchHeld { resetTouch() }; gestures.cancelForNativeScroll(); taps.cancel(); if dragPointer { dragHandler(event.location, true); dragPointer = false } }
        let isDown = [.leftMouseDown, .rightMouseDown, .otherMouseDown].contains(type)
        let isUp = [.leftMouseUp, .rightMouseUp, .otherMouseUp].contains(type)
        let button = [.leftMouseDown, .leftMouseUp, .leftMouseDragged].contains(type) ? 0 : [.rightMouseDown, .rightMouseUp, .rightMouseDragged].contains(type) ? 1 : Int(event.getIntegerValueField(.mouseEventButtonNumber))
        if nativePrimaryDrags.contains(button), isUp || [.leftMouseDragged, .rightMouseDragged].contains(type) {
            if let copy = event.copy() { Injection.replay(copy) }
            if isUp { nativePrimaryDrags.remove(button) }
            return true
        }
        if isDown || isUp {
            let b = button; if isDown { report.observedButtons.insert(b); report.lastObservedButton = b; report.lastObservedTime = start }; record(isDown ? "button down" : "button up", detail: "Button \(b)")
            if learning { if isDown && b >= 2 { report.learningButton = b }; return false }
        }
        if isUp {
            let b = button
            if consumedButtons.contains(b) && (!configuration.engineEnabled || learning) { consumedButtons.remove(b); return true }
        }
        let insideCapture = captureRect?.contains(event.location) == true
        if isDown && insideCapture {
            captureButtons.insert(button); return false
        }
        if isUp && captureButtons.remove(button) != nil { return false }
        if !captureButtons.isEmpty && [.leftMouseDragged,.rightMouseDragged,.otherMouseDragged,.mouseMoved,.scrollWheel].contains(type) { return false }
        if insideCapture && type == .scrollWheel && buttons.heldButtons.isEmpty { return false }
        guard configuration.engineEnabled, report.active, !learning else { return false }
        let bs = bindings()
        switch type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            let r = buttons.down(button: button, x: event.location.x, y: event.location.y, time: start, modifiers: mods, bindings: bs)
            if r.suppress {
                consumedButtons.insert(button)
                if button < 2, let copy = event.copy() { primaryEvents[button, default: []].append(copy) }
            }
            r.triggers.forEach { emit($0) }; return r.suppress
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            panOrigin = nil
            let b = button
            let owned = consumedButtons.remove(b) != nil
            if b < 2, owned, primaryEvents[b] != nil, let copy = event.copy() { primaryEvents[b, default: []].append(copy) }
            let r = buttons.up(button: b, time: start, bindings: bs); r.triggers.forEach { emit($0) }; return r.suppress || owned
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            if let origin = panOrigin { let point = event.location; Injection.scroll(.init(x: (origin.x - point.x), y: (origin.y - point.y), phase: 2)); panOrigin = point; return true }
            let r = buttons.move(x: event.location.x, y: event.location.y, bindings: bs); r.triggers.forEach { emit($0) }
            for b in r.nativeDrags {
                primaryEvents.removeValue(forKey: b)?.forEach { Injection.replay($0) }
                consumedButtons.remove(b); nativePrimaryDrags.insert(b)
            }
            if !r.nativeDrags.isEmpty, [.leftMouseDragged, .rightMouseDragged].contains(type) {
                if let copy = event.copy() { Injection.replay(copy) }; return true
            }
            if button < 2, consumedButtons.contains(button), [.leftMouseDragged, .rightMouseDragged].contains(type) { return true }
            if dragPointer { if let dragged = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: event.location, mouseButton: .left) { Injection.post(dragged) }; return true }
            return false
        case .scrollWheel:
            let continuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
            if continuous {
                if let end = scrolling.cancel() { Injection.scroll(end) }
                if touchRunning { taps.cancel(); drainTouchFrames(at: start, discardTaps: true) }
                if touchHeld { return true } // Raw second-finger scrolling owns this stream.
                let horizontal = abs(event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2)) > abs(event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)) * 1.5
                let ownsSwipe = touchRunning && gestures.activeFingers > 0 && (gestures.activeFingers > 1 || horizontal) && bindings(deviceID: touchDeviceID).contains { $0.kind == .swipe && $0.fingers == gestures.activeFingers && $0.modifiers == mods }
                if ownsSwipe { return true }
                nativeScrollUntil = start + 0.12
                if touchRunning { gestures.rejectTapForNativeScroll() } else { gestures.cancelForNativeScroll() }
                taps.cancel()
            }
            let x = event.getDoubleValueField(.scrollWheelEventDeltaAxis2), y = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
            let r = buttons.wheel(x: x, y: y, modifiers: mods, bindings: bs); r.triggers.forEach { emit($0) }; if r.suppress { return true }
            let settings = ProfileResolver.scroll(bundleID: bundleID, deviceID: nil, configuration: configuration)
            guard !continuous, settings.enabled else { return false }
            if settings.optionZoom && mods.contains(.option) { emitZoom(y > 0); return true }
            if let immediate = scrolling.receive(x: x, y: y, timestamp: start, continuous: false, modifiers: mods, settings: settings) { Injection.scroll(immediate) }
            return true
        default: return false
        }
    }
    private func emitZoom(_ up: Bool) { actionHandler(.init(mapping: Mapping(trigger: .init(), action: up ? .zoomIn : .zoomOut), source: "Scrolling", epoch: epoch)) }
    private func resetTouch() {
        // Invalidate a queued drag start before releasing. A fast lift must never
        // let a late main-actor task leave a synthetic mouse-down behind.
        epoch += 1; lock.lock(); currentEpoch = epoch; lock.unlock()
        gestures.cancel(); gestures.cancelForNativeScroll(); taps.cancel(); if let end = touchDrag.cancel() { Injection.scroll(end) }; touchFrameOffset = nil
        if touchHeld || dragPointer { cancellationHandler() }
        touchHeld = false; dragPointer = false
    }
    private func drainTouchFrames(at time: Double, discardTaps: Bool = false) {
    var frame = GMFrame(); var frames: [GMFrame] = []
    while touchRunning && frames.count < 128 && gm_touch_next(&frame) { frames.append(frame) }
    let drops = gm_touch_dropped()
    if drops != droppedLast {
        resetTouch(); droppedLast = drops
    }
    if let last = frames.last {
        lastTouchReceived = time
        if touchFrameOffset == nil { touchFrameOffset = time - last.timestamp }
    } else if touchHeld && time - lastTouchReceived > 0.5 { resetTouch() }
    for frame in frames {
        if frame.overflow || !(0...16).contains(Int(frame.count)) || !frame.timestamp.isFinite { resetTouch(); continue }
        let pts: [TouchPoint] = withUnsafePointer(to: frame.contacts) { raw in raw.withMemoryRebound(to: GMContact.self, capacity: 16) { ptr in (0..<Int(frame.count)).map { .init(id: Int(ptr[$0].identity), x: ptr[$0].x, y: ptr[$0].y, area: ptr[$0].area) } } }
        report.contacts = pts; let deviceID = "mt:\(frame.deviceIndex)"
        let timestamp = frame.timestamp + (touchFrameOffset ?? (time - frame.timestamp))
        guard timestamp.isFinite, timestamp <= time + 0.1 else { resetTouch(); continue }
        let input = TouchFrame(timestamp: timestamp, deviceID: deviceID, contacts: pts, modifiers: Modifiers(cgFlags: CGEventSource.flagsState(.combinedSessionState)))
        if touchHeld {
            let update = touchDrag.process(input, tuning: configuration.tuning)
            if let scroll = update.scroll { Injection.scroll(scroll) }
            if update.release { resetTouch() }
            continue
        }
        if time < nativeScrollUntil { gestures.rejectTapForNativeScroll() }
        let output = gestures.process(input)
        for g in output {
            if g.trigger.kind == .touchHold {
                taps.cancel()
                let resolved = ProfileResolver.resolveGesture(trigger: g.trigger, bundleID: bundleID, deviceID: deviceID, profiles: configuration.profiles + [configuration.globalDefaults])
                if let r = resolved, !r.paused, r.mapping.enabled, r.mapping.action == .toggleDrag {
                    touchHeld = true
                    touchDrag.begin(owners: gestures.holdContacts, device: deviceID, time: timestamp, resting: Set(pts.map(\.id)).subtracting(gestures.holdContacts))
                }
                emit(g.trigger, deviceID: deviceID, touchHold: touchHeld); continue
            }
            if [.tap,.rightTap].contains(g.trigger.kind) {
                if discardTaps { gestures.rejectTapForNativeScroll(); taps.cancel(); continue }
                let profiles = configuration.profiles + [configuration.globalDefaults]
                let resolved = ProfileResolver.resolveGesture(trigger: g.trigger, bundleID: bundleID, deviceID: deviceID, profiles: profiles)
                // Native click counts handle double/triple clicks immediately.
                // Delay only when a higher tap really selects a different action.
                let higher = bindings(deviceID: deviceID).contains { trigger in
                    guard [.tap, .rightTap].contains(trigger.kind), trigger.fingers == g.trigger.fingers, trigger.modifiers == g.trigger.modifiers, trigger.clicks > g.trigger.clicks else { return false }
                    var next = g.trigger; next.clicks = trigger.clicks
                    let later = ProfileResolver.resolveGesture(trigger: next, bundleID: bundleID, deviceID: deviceID, profiles: profiles)
                    return later?.mapping.action != resolved?.mapping.action || later?.mapping.options != resolved?.mapping.options
                }
                taps.submit(g, hasHigherTap: higher, interval: configuration.tuning.multiTapInterval).forEach { emit($0.trigger, deviceID: $0.deviceID) }
            } else { taps.cancel(); emit(g.trigger, deviceID: deviceID) }
        }
    }
    }
    private func tick() {
        let time = ProcessInfo.processInfo.systemUptime
        if time - lastPermissionCheck > 2 {
            lastPermissionCheck = time
            if report.active && (!AXIsProcessTrusted() || !CGPreflightListenEventAccess()) { reset(); stopTap(); gm_touch_stop(); touchRunning = false; report.status = "Permission revoked" }
        }
        if configuration.engineEnabled && report.active {
            let bs = bindings(); buttons.advance(time: time, bindings: bs).forEach { emit($0) }
            if let s = scrolling.tick(time) { Injection.scroll(s) }
            drainTouchFrames(at: time)
            taps.advance(time).forEach { emit($0.trigger, deviceID: $0.deviceID) }
        }
        if time - lastReport >= 0.25 {
            lastReport = time; report.lastPeakArea = gestures.lastPeakArea; report.touchDrops = gm_touch_dropped()
            if deliveredReport != report { deliveredReport = report; reportHandler(report) }
        }
        scheduleTimer(fast: buttons.hasPendingWork || scrolling.isActive || touchRunning || taps.hasPendingWork)
    }
}
