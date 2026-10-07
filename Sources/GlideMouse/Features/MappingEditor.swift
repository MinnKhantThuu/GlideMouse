import SwiftUI
import AppKit
import MouseCore

struct MappingEditor: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    @State var mapping: Mapping
    @State private var recording = false
    @State private var capturingMouse = false
    @State private var captureMessage = ""
    @State private var choosingAction = false
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(model.text("Mapping editor")).font(.title2.bold())
            Text(String(format: model.text("Saving these changes affects: %@"), model.editingScopeName)).font(.callout).foregroundStyle(.secondary)
            if !MagicMouseCatalog.touchKinds.contains(mapping.trigger.kind) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(model.text("Capture mouse input")).font(.headline)
                    Spacer()
                    Button(model.text(capturingMouse ? "Stop capture" : "Start capture")) {
                        capturingMouse.toggle()
                        if capturingMouse { captureMessage = "" } else { model.setMouseCaptureArea(nil) }
                    }
                }
                MouseCaptureArea(armed: capturingMouse, label: model.text(capturingMouse ? "Click, hold, drag or button + wheel inside this box." : "Start capture, then perform your mouse gesture here."), holdDelay: model.configuration.tuning.holdDelay, dragDistance: model.configuration.tuning.dragDistance, areaChanged: { model.setMouseCaptureArea($1, owner: $0) }) { trigger, protected in
                    if var trigger {
                        if trigger.button < 2, [.button, .buttonHold, .buttonDrag, .buttonWheel, .buttonChord].contains(trigger.kind) {
                            guard [.button, .buttonHold].contains(trigger.kind) else { captureMessage = model.text("Left/right buttons support double click and hold."); return }
                            if trigger.kind == .button { trigger.clicks = 2 }
                        }
                        if let existing = model.effectiveProfile.mappings.first(where: { $0.trigger.canonical == trigger.canonical }) { mapping = existing }
                        else { mapping = Mapping(trigger: trigger, action: mapping.action) }
                        captureMessage = triggerLabel(trigger, model: model)
                    }
                    else if protected { captureMessage = model.text("Left and right clicks stay native. Use a wheel or side button.") }
                }.frame(height: 100)
                Text(captureMessage.isEmpty ? model.text("Captured input is selected automatically. Choose an action, then Save mapping.") : captureMessage).font(.caption)
            }
            }
            Form {
                TextField(model.text("Mapping name (optional)"), text: Binding(get: { mapping.name ?? "" }, set: { mapping.name = $0.isEmpty ? nil : String($0.prefix(150)) }))
                EasyPicker(label: model.text("Input"), selection: $mapping.trigger.kind, values: TriggerKind.allCases) { model.text("trigger." + $0.rawValue) }
                if [.button,.buttonHold,.buttonDrag,.buttonWheel,.buttonChord].contains(mapping.trigger.kind) {
                    Stepper(model.text("Button") + ": \(mapping.trigger.button + 1)", value: $mapping.trigger.button, in: 2...31)
                }
                if mapping.trigger.kind == .buttonChord { Stepper(model.text("Second button") + ": \(mapping.trigger.chordButton + 1)", value: $mapping.trigger.chordButton, in: 2...31) }
                if [.tap,.rightTap,.swipe,.touchHold].contains(mapping.trigger.kind) { Stepper(model.text("Fingers") + ": \(mapping.trigger.fingers)", value: $mapping.trigger.fingers, in: 1...3) }
                if [.button,.tap,.rightTap].contains(mapping.trigger.kind) { Stepper(model.text("Tap or press count") + ": \(mapping.trigger.clicks)", value: $mapping.trigger.clicks, in: 1...3) }
                if [.swipe,.buttonDrag,.buttonWheel].contains(mapping.trigger.kind) { EasyPicker(label: model.text("Direction"), selection: $mapping.trigger.direction, values: Direction.allCases) { model.text($0.rawValue) } }
                HStack { modifier(.control, "⌃"); modifier(.option, "⌥"); modifier(.shift, "⇧"); modifier(.command, "⌘") }
                Button { choosingAction = true } label: {
                    DropdownLabel(title: model.text("Action") + ": " + model.text("action." + mapping.action.rawValue))
                }.buttonStyle(.plain).modifier(PointingHandCursor()).contentShape(Rectangle())
                if mapping.action.requiresTarget { TextField(model.text("Target"), text: $mapping.options.target) }
                if [.openApp,.openFolder].contains(mapping.action) { Button(model.text("Choose target")) { chooseTarget() } }
                if mapping.action == .shortcut {
                    Text(model.text("Shortcut is recorded only while this field is focused.")).font(.caption)
                    ShortcutRecorder(model: model, keyCode: $mapping.options.keyCode, modifiers: $mapping.options.modifiers, recording: $recording).frame(height: 36)
                    Button(model.text(recording ? "Stop recording" : "Record shortcut")) { recording.toggle() }
                }
                if mapping.action == .shell {
                    Toggle(model.text("Allow this shell command"), isOn: $mapping.options.shellEnabled)
                    TextField(model.text("Working directory"), text: $mapping.options.workingDirectory)
                    Slider(value: $mapping.options.timeout, in: 1...60, step: 1) { Text(model.text("Timeout") + " \(Int(mapping.options.timeout))s") }
                    Text(model.text("Commands run once at a time with a timeout. Imported automation is disabled until reviewed.")).font(.caption)
                }
                if [.missionControl,.appExpose,.showDesktop,.spaceLeft,.spaceRight,.back,.forward,.quickLook,.appLauncher,.zoomIn,.zoomOut].contains(mapping.action) { Text(model.text("This action uses a shortcut. Availability depends on the active app and system shortcut settings.")).font(.caption).foregroundStyle(.secondary) }
                if mapping.action == .smartZoom { Text(model.text("Native Smart Zoom is unavailable on this build. Use Zoom In/Out shortcuts.")).foregroundStyle(.orange) }
                if mapping.action == .canvasPan && mapping.trigger.kind != .buttonDrag { Text(model.text("Canvas pan needs a held button + drag mapping.")).foregroundStyle(.orange) }
                Toggle(model.text("Enable mapping"), isOn: $mapping.enabled)
            }.formStyle(.grouped)
            HStack {
                Button(model.text("Cancel")) { model.setMouseCaptureArea(nil); dismiss() }
                Text(model.text("Advanced mapping")).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(model.text("Save mapping")) { var m = mapping; m.trigger = m.trigger.canonical; let cleanName = m.name?.trimmingCharacters(in: .whitespacesAndNewlines); m.name = cleanName?.isEmpty == false ? cleanName : nil; let previousError = model.errorMessage; model.errorMessage = nil; model.saveMapping(m); if model.errorMessage == nil { model.setMouseCaptureArea(nil); dismiss() } else if previousError != nil {} }.keyboardShortcut(.defaultAction)
                    .disabled(mapping.action == .smartZoom || (mapping.action == .canvasPan && mapping.trigger.kind != .buttonDrag))
            }
        }.padding(24).frame(width: 600, height: 820).buttonStyle(PointingButtonStyle())
        .sheet(isPresented: $choosingAction) { ActionChooser(model: model, action: $mapping.action, triggerKind: mapping.trigger.kind) }
    }
    private func modifier(_ flag: Modifiers, _ label: String) -> some View {
        Toggle(label, isOn: Binding(get: { mapping.trigger.modifiers.contains(flag) }, set: { enabled in if enabled { mapping.trigger.modifiers.insert(flag) } else { mapping.trigger.modifiers.remove(flag) } })).toggleStyle(.button).modifier(PointingHandCursor())
    }
    private func chooseTarget() {
        let panel = NSOpenPanel(); panel.title = model.text("Choose target"); panel.prompt = model.text("Choose target"); panel.canChooseFiles = mapping.action == .openApp; panel.canChooseDirectories = mapping.action == .openFolder
        if mapping.action == .openApp { panel.allowedContentTypes = [.application] }
        if panel.runModal() == .OK, let u = panel.url { mapping.options.target = u.path }
    }
}
struct ShortcutRecorder: NSViewRepresentable {
    @ObservedObject var model: AppModel
    @Binding var keyCode: UInt16
    @Binding var modifiers: Modifiers
    @Binding var recording: Bool
    final class RecorderView: NSView {
        var recorded: ((UInt16,Modifiers) -> Void)?
        var recording = false
        var label = ""
        override var acceptsFirstResponder: Bool { true }
        override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self) }
        override func keyDown(with event: NSEvent) {
            guard recording else { super.keyDown(with: event); return }
            recorded?(event.keyCode, Modifiers(cgFlags: event.cgEvent?.flags ?? []))
        }
        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            if recording && window?.firstResponder === self { keyDown(with: event); return true }; return false
        }
        override func draw(_ dirtyRect: NSRect) {
            NSColor.controlBackgroundColor.setFill(); bounds.fill()
            (label as NSString).draw(at: NSPoint(x: 10,y: 10), withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 13, weight: .medium), .foregroundColor: NSColor.labelColor])
        }
    }
    func makeNSView(context: Context) -> RecorderView {
        let v = RecorderView(); v.setAccessibilityElement(true); v.setAccessibilityRole(.textField); v.setAccessibilityLabel(model.text("Shortcut recorder")); return v
    }
    func updateNSView(_ view: RecorderView, context: Context) {
        view.recording = recording; view.label = recording ? model.text("Press shortcut…") : ShortcutDisplay.label(keyCode: keyCode, modifiers: modifiers, translate: model.text)
        view.setAccessibilityLabel(model.text("Shortcut recorder"))
        view.setAccessibilityValue(view.label)
        view.recorded = { code, flags in keyCode = code; modifiers = flags; recording = false }
        if recording { DispatchQueue.main.async { view.window?.makeFirstResponder(view) } }; view.needsDisplay = true
    }
}
struct ImportReview: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(model.text("Review import")).font(.title2.bold())
            if let p = model.importPreview {
                Text(model.text("Profiles") + ": \(p.profiles)")
                Text(model.text("Mappings") + ": \(p.mappings)")
                Text(model.text("Automation disabled") + ": \(p.disabledCommands)")
                Text(model.text("Replace applies the imported settings with the engine paused. Merge rejects conflicting rules and keeps your current preferences."))
            }
            HStack { Button(model.text("Cancel")) { model.importPreview = nil }; Spacer(); Button(model.text("Merge")) { model.applyImport(merge: true) }; Button(model.text("Replace")) { model.applyImport(merge: false) } }
        }.padding(26).frame(width: 530).buttonStyle(PointingButtonStyle())
    }
}

struct MouseCaptureArea: NSViewRepresentable {
    var armed: Bool
    var label: String
    var holdDelay: Double
    var dragDistance: Double
    var areaChanged: (UUID, CGRect?) -> Void
    var captured: (Trigger?, Bool) -> Void
    final class CaptureView: NSView {
        var armed = false { didSet { if !armed { capture.reset() }; updateCaptureArea() } }
        let captureOwner = UUID()
        var areaChanged: ((UUID, CGRect?) -> Void)?
        @objc func updateCaptureArea() {
            guard armed, NSApplication.shared.isActive, let window, window.isKeyWindow, window.isVisible, window.isOnActiveSpace, let screen = NSScreen.screens.first else { areaChanged?(captureOwner, nil); return }
            let visible = visibleRect.intersection(bounds)
            guard !visible.isEmpty else { areaChanged?(captureOwner, nil); return }
            let screenRect = window.convertToScreen(convert(visible,to:nil))
            areaChanged?(captureOwner, CGRect(x:screenRect.minX,y:screen.frame.maxY-screenRect.maxY,width:screenRect.width,height:screenRect.height))
        }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            NotificationCenter.default.removeObserver(self)
            NSWorkspace.shared.notificationCenter.removeObserver(self)
            if let window {
                let center = NotificationCenter.default
                center.addObserver(self, selector: #selector(updateCaptureArea), name: NSView.boundsDidChangeNotification, object: nil)
                for name in [NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification] {
                    center.addObserver(self, selector: #selector(updateCaptureArea), name: name, object: nil)
                }
                for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification, NSWindow.didMoveNotification, NSWindow.didMiniaturizeNotification, NSWindow.didDeminiaturizeNotification, NSWindow.didChangeOcclusionStateNotification] {
                    center.addObserver(self, selector: #selector(updateCaptureArea), name: name, object: window)
                }
                NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(updateCaptureArea), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
            }
            updateCaptureArea()
        }
        override func layout() { super.layout(); updateCaptureArea() }
        var label = ""
        var capture = MouseInputCapture()
        var captured: ((Trigger?, Bool) -> Void)?
        override var acceptsFirstResponder: Bool { true }
        override func draw(_ dirtyRect: NSRect) {
            (armed ? NSColor.controlAccentColor.withAlphaComponent(0.12) : NSColor.controlBackgroundColor).setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10).fill()
            let text = NSMutableParagraphStyle(); text.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [.font:NSFont.systemFont(ofSize:14), .foregroundColor:NSColor.labelColor, .paragraphStyle:text]
            let width = max(0, bounds.width - 30)
            let size = (label as NSString).boundingRect(with: NSSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes).size
            let height = min(ceil(size.height), max(0, bounds.height - 16))
            (label as NSString).draw(in: NSRect(x: 15, y: (bounds.height - height) / 2, width: width, height: height), withAttributes: attributes)
        }
        private func down(_ e: NSEvent) {
            guard armed else { return }; window?.makeFirstResponder(self)
            let point = e.locationInWindow
            if let t = capture.down(button:e.buttonNumber,x:point.x,y:-point.y,time:e.timestamp,clicks:e.clickCount,modifiers:Modifiers(cgFlags:e.cgEvent?.flags ?? [])) { captured?(t,false) }
        }
        private func up(_ e: NSEvent) { if armed, let t = capture.up(button:e.buttonNumber,time:e.timestamp) { captured?(t,false) } }
        private func move(_ e: NSEvent) { if armed, let t = capture.move(x:e.locationInWindow.x,y:-e.locationInWindow.y) { captured?(t,false) } }
        override func mouseDown(with event: NSEvent) { down(event) }
        override func rightMouseDown(with event: NSEvent) { down(event) }
        override func otherMouseDown(with event: NSEvent) { down(event) }
        override func mouseUp(with event: NSEvent) { up(event) }
        override func rightMouseUp(with event: NSEvent) { up(event) }
        override func otherMouseUp(with event: NSEvent) { up(event) }
        override func mouseDragged(with event: NSEvent) { move(event) }
        override func otherMouseDragged(with event: NSEvent) { move(event) }
        override func scrollWheel(with event: NSEvent) {
            guard armed else { return }
            if let t = capture.wheel(x:event.scrollingDeltaX,y:event.scrollingDeltaY,modifiers:Modifiers(cgFlags:event.cgEvent?.flags ?? [])) { captured?(t,false) }
        }
    }
    func makeNSView(context: Context) -> CaptureView { let v = CaptureView(); v.setAccessibilityElement(true); v.setAccessibilityRole(.group); v.setAccessibilityLabel(label); return v }
    static func dismantleNSView(_ view: CaptureView, coordinator: ()) { view.armed = false; view.areaChanged?(view.captureOwner, nil) }
    func updateNSView(_ view: CaptureView, context: Context) {
        view.areaChanged = areaChanged; view.armed = armed; view.label = label; view.capture.holdDelay = holdDelay; view.capture.dragDistance = dragDistance
        view.captured = { t, p in DispatchQueue.main.async { captured(t,p) } }
        view.setAccessibilityLabel(label); view.needsDisplay = true
    }
}

private enum ActionGroup: String, CaseIterable {
    case mouse = "Clicks and dragging", behavior = "Button behavior", navigation = "Browser & navigation", windows = "Desktops & windows", media = "Media", tools = "Apps & shortcuts"
    static func group(_ action: MouseAction) -> Self {
        switch action {
        case .none: .behavior
        case .leftClick,.rightClick,.middleClick,.doubleClick,.tripleClick,.toggleDrag,.canvasPan: .mouse
        case .back,.forward,.zoomIn,.zoomOut,.quickLook,.smartZoom: .navigation
        case .closeWindow,.minimizeWindow,.hideApp,.cycleWindows,.appSwitcher,.previousApp,.cycleAppsForward,.cycleAppsBackward,.missionControl,.appExpose,.showDesktop,.spaceLeft,.spaceRight: .windows
        case .volumeUp,.volumeDown,.mute,.playPause,.nextTrack,.previousTrack,.brightnessUp,.brightnessDown: .media
        case .shortcut,.openApp,.openFolder,.openURL,.lockScreen,.screenshot,.appleShortcut,.shell,.appLauncher: .tools
        }
    }
}
struct ActionChooser: View {
    @ObservedObject var model: AppModel
    @Binding var action: MouseAction
    var triggerKind: TriggerKind
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    private var matches: [MouseAction] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return MouseAction.allCases.filter { a in
            a != .smartZoom && (a != .canvasPan || triggerKind == .buttonDrag) &&
            (search.isEmpty || model.text("action." + a.rawValue).localizedCaseInsensitiveContains(search) || a.rawValue.localizedCaseInsensitiveContains(search) || model.text(ActionGroup.group(a).rawValue).localizedCaseInsensitiveContains(search))
        }
    }
    private func actionRow(_ choice: MouseAction) -> some View {
        Button { action = choice; dismiss() } label: { HStack { Text(model.text("action." + choice.rawValue)); Spacer(); if action == choice { Image(systemName: "checkmark") } }.padding(8).frame(maxWidth: .infinity, minHeight: 40).contentShape(Rectangle()) }.buttonStyle(SurfaceButtonStyle())
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(model.text("Choose an action")).font(.title2.bold())
            Text(model.text("Choose what the app should do after your button press. Click actions below are clicks the app performs for you.")).font(.callout).foregroundStyle(.secondary)
            TextField(model.text("Search actions"), text: $query).textFieldStyle(.roundedBorder)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if query.isEmpty {
                        Text(model.text("Recommended")).font(.headline)
                        ForEach([MouseAction.spaceLeft, .spaceRight, .missionControl, .back, .forward, .shortcut], id: \.self) { action in
                            actionRow(action)
                        }
                        Divider()
                    }
                    ForEach(ActionGroup.allCases, id: \.self) { group in
                        let items = matches.filter { ActionGroup.group($0) == group }
                        if !items.isEmpty {
                            Text(model.text(group.rawValue)).font(.headline)
                            ForEach(items, id: \.self) { item in
                                actionRow(item)
                            }
                        }
                    }
                    if matches.isEmpty { Text(model.text("No matching actions")).foregroundStyle(.secondary) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            Button(model.text("Cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
        }.padding(24).frame(width: 500,height: 560).buttonStyle(PointingButtonStyle())
    }
}
struct PresetReview: View {
    @ObservedObject var model: AppModel
    let kind: String
    private var proposed: [Mapping] { model.proposedPreset(kind) }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(model.text("Review preset")).font(.title2.bold())
            Text(String(format: model.text("Apply this setup to: %@"), model.editingScopeName)).font(.headline)
            Text(model.text("Only the listed inputs change. Your other mappings stay in place. Undo restores the previous settings."))
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(model.text("Current mappings") + ": \(model.effectiveProfile.mappings.count)")
                    Divider()
                    Text(model.text("New mappings")).font(.headline)
                    ForEach(proposed) { mapping in
                        HStack { Text(triggerLabel(mapping.trigger, model: model)); Spacer(); Text(model.text("action." + mapping.action.rawValue)) }
                    }
                }
            }
            HStack {
                Button(model.text("Cancel")) { model.pendingPreset = nil }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(model.text("Apply preset")) { model.preset(kind); model.pendingPreset = nil }.keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 600,height: 450).buttonStyle(PointingButtonStyle())
    }
}
