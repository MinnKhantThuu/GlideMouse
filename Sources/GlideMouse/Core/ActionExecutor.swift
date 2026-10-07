import AppKit
@preconcurrency import ApplicationServices
import MouseCore
import NativeBridge

let syntheticTag: Int64 = 0x474C4944454D

extension Modifiers {
    init(cgFlags: CGEventFlags) {
        var result: Modifiers = []
        if cgFlags.contains(.maskCommand) { result.insert(.command) }
        if cgFlags.contains(.maskAlternate) { result.insert(.option) }
        if cgFlags.contains(.maskControl) { result.insert(.control) }
        if cgFlags.contains(.maskShift) { result.insert(.shift) }
        self = result
    }
    var cgFlags: CGEventFlags {
        var result: CGEventFlags = []
        if contains(.command) { result.insert(.maskCommand) }; if contains(.option) { result.insert(.maskAlternate) }
        if contains(.control) { result.insert(.maskControl) }; if contains(.shift) { result.insert(.maskShift) }
        return result
    }
}
enum Injection {
    private static let keyboardLock = NSLock()
    private nonisolated(unsafe) static var commandOverride: Bool?
    /// Stateless CoreGraphics injection can run on the input thread. Keep window,
    /// drag and command state on the main actor in ActionExecutor.
    static func desktopAction(_ action: MouseAction) -> Bool {
        guard [.spaceLeft, .spaceRight].contains(action), AXIsProcessTrusted() else { return false }
        return key(action == .spaceLeft ? 123 : 124, modifiers: [.control], skipIfCycling: true)
    }
    static func post(_ e: CGEvent, source supplied: CGEventSource? = nil) { if let source = supplied ?? CGEventSource(stateID: .privateState) { source.userData = syntheticTag; source.localEventsSuppressionInterval = 0; e.setSource(source) }; e.setIntegerValueField(.eventSourceUserData, value: syntheticTag); e.post(tap: .cghidEventTap) }
    /// Replay intercepted native mouse events at the same session layer. Posting
    /// them to HID can discard a duplicate down while the physical button is held.
    static func replay(_ e: CGEvent) {
        if let source = CGEventSource(stateID: .privateState) { source.userData = syntheticTag; source.localEventsSuppressionInterval = 0; e.setSource(source) }
        e.setIntegerValueField(.eventSourceUserData, value: syntheticTag); e.post(tap: .cgSessionEventTap)
    }
    static func pointer() -> CGPoint { CGEvent(source: nil)?.location ?? .zero }
    static func click(_ button: CGMouseButton, count: Int = 1, onlyFinal: Bool = false, modifiers: Modifiers = []) {
        let down: CGEventType = button == .left ? .leftMouseDown : button == .right ? .rightMouseDown : .otherMouseDown
        let up: CGEventType = button == .left ? .leftMouseUp : button == .right ? .rightMouseUp : .otherMouseUp
        for i in (onlyFinal ? max(1,min(3,count)) : 1)...max(1,min(3,count)) {
            for type in [down, up] {
                if let e = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: pointer(), mouseButton: button) { e.flags = modifiers.cgFlags; e.setIntegerValueField(.mouseEventClickState, value: Int64(i)); post(e) }
            }
        }
    }
    @discardableResult static func key(_ code: UInt16, modifiers: Modifiers = [], skipIfCycling: Bool = false, preservePhysicalModifiers: Bool = true) -> Bool {
        keyboardLock.lock(); defer { keyboardLock.unlock() }
        if skipIfCycling && commandOverride == true { return false }
        var original = CGEventSource.flagsState(.combinedSessionState)
        // Posting is asynchronous. Keep an owned Command down across cycle steps,
        // and remove its stale snapshot on the first action after our release.
        if let override = commandOverride {
            if override { original.insert(.maskCommand) }
            else { original.remove(.maskCommand); commandOverride = nil }
        }
        guard let (events, source) = keyEvents(code, modifiers: modifiers, original: original, preservePhysicalModifiers: preservePhysicalModifiers) else { return false }
        events.forEach { post($0, source: source) }; return true
    }
    /// Event construction is testable without posting any input to the Mac.
    static func keyEvents(_ code: UInt16, modifiers: Modifiers, original: CGEventFlags, preservePhysicalModifiers: Bool = true) -> ([CGEvent], CGEventSource)? {
        guard let source = CGEventSource(stateID: .privateState) else { return nil }
        let modifierKeys: [(Modifiers, CGEventFlags, UInt16)] = [(.control,.maskControl,59),(.option,.maskAlternate,58),(.shift,.maskShift,56),(.command,.maskCommand,55)]
        // System shortcuts need modifier transitions, not only flags on the arrow.
        // Never release a modifier already held physically by the user.
        let added = modifierKeys.filter { modifiers.contains($0.0) && !original.contains($0.1) }
        var flags = original
        var events: [CGEvent] = []
        for (_,flag,key) in added {
            flags.insert(flag)
            guard let e = CGEvent(keyboardEventSource: source,virtualKey:key,keyDown:true) else { return nil }
            e.type = .flagsChanged; e.flags = flags; events.append(e)
        }
        var keyFlags = preservePhysicalModifiers ? flags : modifiers.cgFlags
        // Arrow keys carry both navigation/function and numeric-pad identity flags.
        // Replacing the CGEvent flags with only Control loses this identity and
        // prevents Dock's Space-switching shortcut from matching the event.
        if (123...126).contains(code) { keyFlags.formUnion([.maskSecondaryFn, .maskNumericPad]) }
        for down in [true,false] {
            guard let e = CGEvent(keyboardEventSource: source,virtualKey:code,keyDown:down) else { return nil }
            e.flags = keyFlags; events.append(e)
        }
        for (_,flag,key) in added.reversed() {
            flags.remove(flag)
            guard let e = CGEvent(keyboardEventSource: source,virtualKey:key,keyDown:false) else { return nil }
            e.type = .flagsChanged; e.flags = flags; events.append(e)
        }
        return (events, source)
    }
    static func commandTransition(down: Bool) {
        keyboardLock.lock(); defer { keyboardLock.unlock() }
        guard let e = CGEvent(keyboardEventSource: nil, virtualKey: 55, keyDown: down) else { return }
        e.type = .flagsChanged
        var flags = CGEventSource.flagsState(.combinedSessionState)
        if down { flags.insert(.maskCommand) } else { flags.remove(.maskCommand) }
        commandOverride = down
        e.flags = flags; post(e)
    }
    static func scroll(_ s: ScrollDelta) {
        guard let e = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: Int32(s.y.rounded()), wheel2: Int32(s.x.rounded()), wheel3: 0) else { return }
        e.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        e.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: s.y)
        e.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: s.x)
        e.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: s.y)
        e.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: s.x)
        e.setIntegerValueField(.scrollWheelEventScrollPhase, value: Int64(s.phase))
        e.setIntegerValueField(.scrollWheelEventMomentumPhase, value: Int64(s.momentumPhase))
        e.flags = []; post(e)
    }
}
@MainActor final class ActionExecutor {
    private(set) var dragging = false
    private var dragModifiers: Modifiers = []
    private var cycle = AppCycleSession()
    private var cycleTask: Task<Void, Never>?
    private var ownsCommand = false
    private var processPID: Int32?
    private var timeoutTask: Task<Void,Never>?
    var report: (String) -> Void = { _ in }
    func cancel() {
        endCycle()
        if dragging { releaseDrag() }
        if let pid = processPID { gm_command_cancel(pid, false); timeoutTask?.cancel() }
    }
    func releaseDrag() {
        guard dragging else { return }; dragging = false
        if let e = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: Injection.pointer(), mouseButton: .left) { e.flags = dragModifiers.cgFlags; Injection.post(e) }
    }
    func moveDrag(_ point: CGPoint) {
        guard dragging else { return }
        if let e = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: point, mouseButton: .left) { e.flags = dragModifiers.cgFlags; Injection.post(e) }
    }
    func execute(_ m: Mapping, preview: Bool = false, alreadyInjected: Bool = false, switchDelay: Double = 0.8) {
        guard m.enabled else { report("Mapping disabled"); return }
        if preview { report("Preview: \(m.action.rawValue)"); return }
        if alreadyInjected { report("Executed: \(m.action.rawValue)"); return }
        guard AXIsProcessTrusted() else { report("Accessibility permission required"); return }
        let a = m.action
        if ![.cycleAppsForward, .cycleAppsBackward].contains(a) { endCycle() }
        let clickModifiers = MagicMouseCatalog.touchKinds.contains(m.trigger.kind) ? m.trigger.modifiers : []
        func key(_ code: UInt16, modifiers: Modifiers = []) {
            Injection.key(code, modifiers: modifiers, preservePhysicalModifiers: !MagicMouseCatalog.touchKinds.contains(m.trigger.kind))
        }
        switch a {
        case .none: break
        case .leftClick: Injection.click(.left, count: [.tap,.rightTap].contains(m.trigger.kind) ? m.trigger.clicks : 1, onlyFinal: true, modifiers: clickModifiers)
        case .rightClick: Injection.click(.right, count: [.tap,.rightTap].contains(m.trigger.kind) ? m.trigger.clicks : 1, onlyFinal: true, modifiers: clickModifiers)
        case .middleClick: Injection.click(.center, modifiers: clickModifiers)
        case .doubleClick: Injection.click(.left, count: 2, modifiers: clickModifiers)
        case .tripleClick: Injection.click(.left, count: 3, modifiers: clickModifiers)
        case .toggleDrag:
            if dragging { releaseDrag() } else { dragging = true; dragModifiers = clickModifiers; if let e = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: Injection.pointer(), mouseButton: .left) { e.flags = dragModifiers.cgFlags; Injection.post(e) } }
        case .back: key(33, modifiers: [.command])
        case .forward: key(30, modifiers: [.command])
        case .zoomIn: key(24, modifiers: [.command])
        case .zoomOut: key(27, modifiers: [.command])
        case .quickLook: key(49)
        case .closeWindow: key(13, modifiers: [.command])
        case .minimizeWindow: key(46, modifiers: [.command])
        case .hideApp: key(4, modifiers: [.command])
        case .cycleWindows: key(50, modifiers: [.command])
        case .appSwitcher: key(48, modifiers: [.command])
        case .previousApp: key(48, modifiers: [.command,.shift])
        case .cycleAppsForward, .cycleAppsBackward: cycleApp(backward: a == .cycleAppsBackward, delay: switchDelay)
        case .missionControl:
            let url = URL(fileURLWithPath: "/System/Applications/Mission Control.app")
            guard NSWorkspace.shared.open(url) else { report("Mission Control could not be opened"); return }
        case .appExpose: key(125, modifiers: [.control])
        case .showDesktop: key(103)
        case .spaceLeft: key(123, modifiers: [.control])
        case .spaceRight: key(124, modifiers: [.control])
        case .appLauncher: key(49, modifiers: [.command]) // Spotlight, supported launcher fallback
        case .shortcut: key(m.options.keyCode, modifiers: m.options.modifiers)
        case .lockScreen: key(12, modifiers: [.control,.command])
        case .screenshot: key(23, modifiers: [.command,.shift])
        case .openURL:
            guard let u = URL(string: m.options.target), ["http","https"].contains(u.scheme ?? ""), u.host != nil else { report("Invalid web URL"); return }
            if !NSWorkspace.shared.open(u) { report("URL could not be opened"); return }
        case .openApp, .openFolder:
            let u = URL(fileURLWithPath: (m.options.target as NSString).expandingTildeInPath)
            guard FileManager.default.fileExists(atPath: u.path) else { report("Target does not exist"); return }
            if !NSWorkspace.shared.open(u) { report("Target could not be opened"); return }
        case .shell:
            guard m.options.shellEnabled else { report("Shell action requires explicit opt-in"); return }
            run(executable: "/bin/zsh", arguments: ["-c",m.options.target], options: m.options)
        case .appleShortcut:
            run(executable: "/usr/bin/shortcuts", arguments: ["run",m.options.target], options: m.options)
        case .volumeUp: media(0)
        case .volumeDown: media(1)
        case .brightnessUp: media(2)
        case .brightnessDown: media(3)
        case .mute: media(7)
        case .playPause: media(16)
        case .nextTrack: media(17)
        case .previousTrack: media(18)
        case .smartZoom: report("Native Smart Zoom is unavailable on this build. Use Zoom In/Out shortcuts."); return
        case .canvasPan: report("Canvas pan needs a held button + drag mapping."); return
        }
        if a != .shell && a != .appleShortcut { report("Executed: \(a.rawValue)") }
    }
    private func endCycle() {
        cycleTask?.cancel(); cycleTask = nil
        _ = cycle.cancel()
        if ownsCommand { Injection.commandTransition(down: false); ownsCommand = false }
    }
    private func cycleApp(backward: Bool, delay: Double) {
        let now = ProcessInfo.processInfo.systemUptime
        if cycle.step(at: now, delay: delay) {
            ownsCommand = !CGEventSource.flagsState(.combinedSessionState).contains(.maskCommand)
            if ownsCommand { Injection.commandTransition(down: true) }
        }
        Injection.key(48, modifiers: backward ? [.command, .shift] : [.command], preservePhysicalModifiers: false)
        cycleTask?.cancel()
        cycleTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            guard let self, self.cycle.advance(ProcessInfo.processInfo.systemUptime) else { return }
            if self.ownsCommand { Injection.commandTransition(down: false); self.ownsCommand = false }
            self.cycleTask = nil
        }
    }
    private func media(_ type: Int) {
        for down in [true,false] {
            let state = down ? 0xA : 0xB
            if let e = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state << 8)), timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: 0, context: nil, subtype: 8, data1: (type << 16) | (state << 8), data2: -1)?.cgEvent { Injection.post(e) }
        }
    }
    private func run(executable: String, arguments: [String], options: ActionOptions) {
        guard processPID == nil else { report("A command is already running"); return }
        let target = arguments.last ?? ""
        let directory = options.workingDirectory.isEmpty ? FileManager.default.homeDirectoryForCurrentUser.path : (options.workingDirectory as NSString).expandingTildeInPath
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let pid = executable.withCString { exe in target.withCString { arg in directory.withCString { dir in home.withCString { h in gm_command_spawn(exe,arg,dir,h) } } } }
        guard pid > 0 else { report("Command failed to start"); return }
        processPID = pid; report("Command running")
        let deadline = ProcessInfo.processInfo.systemUptime + options.timeout
        timeoutTask = Task { @MainActor [weak self] in
            var status: Int32 = 0; var stopping: Double?
            while true {
                let now = ProcessInfo.processInfo.systemUptime
                if (Task.isCancelled || now >= deadline) && stopping == nil { stopping = now; gm_command_cancel(pid,false) }
                if let stopped = stopping, now - stopped > 0.3 { gm_command_cancel(pid,true) }
                let result = gm_command_poll(pid,&status)
                if result != 0 {
                    // Do not leave background descendants from a completed shell command.
                    gm_command_cancel(pid,true)
                    self?.processPID = nil
                    self?.report(stopping == nil ? "Command finished: \(status)" : "Command cancelled or timed out")
                    break
                }
                // A cancelled Task.sleep would busy-loop, so use an uncancelled short child delay.
                await Task.detached { try? await Task.sleep(for: .milliseconds(100)) }.value
            }
        }
    }
}
