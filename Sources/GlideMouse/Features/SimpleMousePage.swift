import SwiftUI
import AppKit
import MouseCore

struct SimpleMousePage: View {
    @ObservedObject var model: AppModel
    @State private var captureNote = ""
    private var known: [Int] { Array(Set(model.calibratedButtons.map(\.button)).union(model.runtimeReport.observedButtons).union(model.selectedButton.map { $0 >= 2 ? [$0] : [] } ?? []).union((model.configuration.globalDefaults.mappings + model.effectiveProfile.mappings).filter { [.button, .buttonHold, .buttonDrag, .buttonWheel, .buttonChord].contains($0.trigger.kind) }.map(\.button))).filter { $0 >= 2 }.sorted() }
    var body: some View {
        if !model.accessibility || !model.inputMonitoring { SectionBox(title: model.text("Allow mouse control")) { PermissionControls(model: model) } }
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text(model.currentMouse?.name ?? model.text("Connect a mouse")).font(.headline)
            }
            Spacer()
            Button(model.text("Label buttons")) { model.showCalibration = true }
        }
        VStack(alignment: .leading, spacing: 6) {
            MouseCaptureArea(armed: model.accessibility && model.inputMonitoring, label: model.text("Press any mouse button inside this box to select it."), holdDelay: model.configuration.tuning.holdDelay, dragDistance: model.configuration.tuning.dragDistance, areaChanged: { model.setMouseCaptureArea($1, owner: $0) }) { trigger, protected in
                if let trigger {
                    if trigger.button < 2, ![.button, .buttonHold].contains(trigger.kind) { captureNote = model.text("Left/right buttons support double click and hold."); return }
                    captureNote = triggerLabel(trigger, model: model)
                    if [.button, .buttonHold].contains(trigger.kind), [1, 2].contains(trigger.clicks), trigger.modifiers.isEmpty {
                        model.selectedGesture = trigger; model.selectedButton = trigger.button
                    } else {
                        model.pendingMapping = model.effectiveProfile.mappings.first { $0.trigger.canonical == trigger.canonical } ?? Mapping(trigger: trigger, action: .none)
                    }
                } else if protected { captureNote = model.text("Left and right clicks stay native. Use a wheel or side button.") }
            }.frame(height: 48)
            if !captureNote.isEmpty { Text(captureNote).font(.caption).foregroundStyle(.secondary) }
        }
        HStack(alignment: .top, spacing: 18) {
            MousePictureSelector(model: model, buttons: known).frame(minWidth: 290, maxWidth: .infinity)
            editorPanel.frame(minWidth: 260, maxWidth: .infinity, alignment: .leading)
        }
        DisclosureGroup(model.text("Ready-made setups")) {
            VStack(alignment: .leading, spacing: 12) {
                EasyDropdown(title: model.text("Starter setup")) { close in
                    DropdownOption(title: model.text("Desktop navigation")) { model.pendingPreset = "desktop"; close() }.disabled(!hasSides)
                    DropdownOption(title: model.text("Browser navigation")) { model.pendingPreset = "browser"; close() }.disabled(!hasSides)
                }
                Text(model.text(hasSides ? "Only the listed actions change. Other mappings are kept." : "Label both side buttons to use a preset.")).font(.caption).foregroundStyle(.secondary)
            }
        }
        AdvancedBindings(model: model)
    }
    @ViewBuilder private var editorPanel: some View {
        if let button = model.selectedButton, button < 2 || known.contains(button) {
            SimpleButtonInspector(model: model, button: button).id("\(button)-\(model.selectedProfileID?.uuidString ?? "global")")
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text(model.text("Choose a mouse button")).font(.headline)
                Text(model.text("Press it in the blue box above, or select its number on the picture.")).font(.callout)
                Text(model.text("Then choose what a click or a hold should do.")).font(.caption).foregroundStyle(.secondary)
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private var hasSides: Bool { model.calibratedButtons.contains { $0.position == .upper } && model.calibratedButtons.contains { $0.position == .lower } }
}

struct DropdownLabel: View {
    var title: String
    var body: some View {
        HStack(spacing: 12) { Text(title).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true); Spacer(minLength: 8); Image(systemName: "chevron.down").font(.caption.bold()) }
            .padding(.horizontal, 14).frame(maxWidth: .infinity, minHeight: 40)
            .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 9)).contentShape(Rectangle())
    }
}

struct EasyDropdown<Content: View>: View {
    let title: String
    let content: (@escaping () -> Void) -> Content
    @State private var expanded = false
    init(title: String, @ViewBuilder content: @escaping (@escaping () -> Void) -> Content) { self.title = title; self.content = content }
    var body: some View {
        Button { expanded.toggle() } label: { DropdownLabel(title: title) }.buttonStyle(SurfaceButtonStyle())
            .popover(isPresented: $expanded, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 8) { content { expanded = false } }.padding(12).frame(minWidth: 260)
            }
    }
}

/// All menu selections use the same rectangular button, rather than a native
/// Picker whose icon and label can have different hit regions inside a Form.
struct EasyPicker<Value: Hashable>: View {
    let label: String
    @Binding var selection: Value
    let values: [Value]
    let title: (Value) -> String
    var body: some View {
        EasyDropdown(title: label + ": " + title(selection)) { close in
            if values.count > 6 { ScrollView { options(close) }.frame(height: 320) }
            else { options(close) }
        }.accessibilityLabel(label).accessibilityValue(title(selection))
    }
    private func options(_ close: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(values, id: \.self) { value in
                DropdownOption(title: title(value) + (selection == value ? "  ✓" : "")) { selection = value; close() }
            }
        }
    }
}
struct DropdownOption: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).frame(minHeight: 40).contentShape(Rectangle())
        }.buttonStyle(SurfaceButtonStyle()).background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct MousePictureSelector: View {
    @ObservedObject var model: AppModel
    var buttons: [Int]
    private func location(_ button: Int) -> ButtonPosition? { model.calibratedButtons.first { $0.button == button }?.position }
    private var placed: [Int] { buttons.filter { [.wheel, .upper, .lower].contains(location($0) ?? .extra) } }
    private var unplaced: [Int] { buttons.filter { !placed.contains($0) } }
    private func anchor(_ position: ButtonPosition, origin: CGFloat, scale: CGFloat) -> CGPoint {
        // Coordinates refer to the existing illustration; positions come from calibration.
        switch position {
        case .wheel: return CGPoint(x: origin + 180 * scale * 0.51, y: (48 + 180 * 0.20) * scale)
        case .upper: return CGPoint(x: origin + 180 * scale * 0.31, y: (48 + 180 * 0.37) * scale)
        case .lower: return CGPoint(x: origin + 180 * scale * 0.36, y: (48 + 180 * 0.50) * scale)
        case .extra: return .zero
        }
    }
    private func badge(_ button: Int, textScale: CGFloat) -> some View {
        Text("\(button + 1)").font(.system(size: 12 * textScale, weight: .bold)).frame(width: 21 * textScale, height: 21 * textScale)
            .background(Color.accentColor.opacity(0.15), in: Circle())
    }
    private func label(_ button: Int, scale: CGFloat, textScale: CGFloat) -> some View {
        Button { model.selectedGesture = nil; model.selectedButton = button; model.savedButton = nil } label: {
            HStack(spacing: 5) {
                badge(button, textScale: textScale)
                Text(location(button).map { model.text($0 == .wheel ? "Wheel" : $0 == .upper ? "Upper side" : $0 == .lower ? "Lower side" : "Extra") } ?? model.text("Set position")).font(.system(size: 12 * textScale)).fixedSize(horizontal: false, vertical: true)
            }.frame(width: 83 * scale, alignment: .leading).padding(.horizontal, 6 * scale).frame(height: 48 * textScale)
                .background(model.selectedButton == button ? Color.accentColor.opacity(0.2) : Color.accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 8)).contentShape(Rectangle())
        }.buttonStyle(SurfaceButtonStyle()).accessibilityLabel(model.buttonTitle(button))
    }
    private func leader(_ point: CGPoint, labelX: CGFloat, labelY: CGFloat, color: Color) -> some View {
        Path { p in p.move(to: point); p.addLine(to: CGPoint(x: point.x, y: labelY)); p.addLine(to: CGPoint(x: labelX, y: labelY)) }
            .stroke(color, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geometry in
                let width = geometry.size.width
                // Scale the entire diagram in the original 274-point coordinate space.
                // Labels, leaders and calibrated anchors must share the image's scale.
                let scale = width / 274
                let textScale = min(scale, 1.35)
                let origin = width / 2 - 90 * scale
                ZStack {
                    if let image = AppResources.mouseIllustration {
                        Image(nsImage: image).resizable().scaledToFit().frame(width: 180 * scale, height: 180 * scale).position(x: width / 2, y: 138 * scale).accessibilityLabel(model.text("Mouse illustration"))
                    }
                    ForEach(0..<2, id: \.self) { button in
                        let left = button == 0
                        let point = CGPoint(x: origin + 180 * scale * (left ? 0.40 : 0.60), y: (48 + 180 * (left ? 0.18 : 0.10)) * scale)
                        leader(point, labelX: left ? 96 * scale : width - 96 * scale, labelY: 23 * scale, color: .secondary.opacity(0.5))
                        Button { model.selectedGesture = nil; model.selectedButton = button; model.savedButton = nil } label: {
                            HStack(spacing: 4) { Text("\(button + 1)").bold(); Text(model.text(left ? "Left button" : "Right button")) }
                                .font(.system(size: 12 * textScale)).frame(width: 95 * scale, height: 48 * textScale)
                                .background(Color.accentColor.opacity(model.selectedButton == button ? 0.2 : 0.07), in: RoundedRectangle(cornerRadius: 8)).contentShape(Rectangle())
                        }.buttonStyle(SurfaceButtonStyle()).accessibilityLabel(model.buttonTitle(button))
                            .position(x: left ? 48 * scale : width - 48 * scale, y: 23 * scale)
                    }
                    ForEach(placed, id: \.self) { button in
                        let slot = location(button) ?? .extra
                        let left = slot != .wheel
                        let y: CGFloat = (slot == .lower ? 201 : slot == .upper ? 105 : 128) * scale
                        let point = anchor(slot, origin: origin, scale: scale)
                        leader(point, labelX: left ? 96 * scale : width - 96 * scale, labelY: y, color: Color.accentColor.opacity(0.8))
                        Text("\(button + 1)").font(.system(size: 9 * textScale, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 15 * textScale, height: 15 * textScale).background(Color.accentColor, in: Circle()).position(point)
                        label(button, scale: scale, textScale: textScale).position(x: left ? 48 * scale : width - 48 * scale, y: y)
                    }
                    if !unplaced.isEmpty {
                        ScrollView(.horizontal) {
                            HStack(spacing: 10) {
                                ForEach(unplaced, id: \.self) { button in
                                    Button { model.selectedGesture = nil; model.selectedButton = button; model.savedButton = nil } label: {
                                        Text("\(button + 1)").font(.system(size: 14 * textScale, weight: .semibold)).frame(width: 40 * textScale, height: 40 * textScale)
                                            .background(Color.accentColor.opacity(model.selectedButton == button ? 0.22 : 0.08), in: RoundedRectangle(cornerRadius: 9)).contentShape(Rectangle())
                                    }.buttonStyle(SurfaceButtonStyle()).accessibilityLabel(model.buttonTitle(button)).help(model.text("Select this number to set its button position."))
                                }
                            }.padding(.horizontal, 6)
                        }.scrollIndicators(.hidden).frame(width: width - 12 * scale, height: 40 * textScale).position(x: width / 2, y: 251 * scale)
                    }
                }
            }.aspectRatio(274.0 / (unplaced.isEmpty ? 234.0 : 274.0), contentMode: .fit)
            Text(model.text("Select 1 or 2 to assign double click or hold.")).font(.caption2).foregroundStyle(.secondary)
            if buttons.isEmpty { Text(model.text("Press a side or wheel button in the blue box to add its label.")).font(.caption).foregroundStyle(.secondary) }
        }.padding(8).background(Color(nsColor: .controlBackgroundColor).opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
    }
}

private enum SimplePress: String, CaseIterable {
    case click = "Click once", doubleClick = "Double click", hold = "Hold"
    var kind: TriggerKind { self == .hold ? .buttonHold : .button }
    var count: Int { self == .doubleClick ? 2 : 1 }
}

struct SimpleButtonInspector: View {
    @ObservedObject var model: AppModel
    let button: Int
    @State private var press: SimplePress = .click
    private var presses: [SimplePress] { button < 2 ? [.doubleClick, .hold] : SimplePress.allCases }
    private var kind: TriggerKind { press.kind }
    @State private var draft = Mapping(button: 2, action: .none)
    @State private var choosingAction = false
    @State private var actionChosen = false
    @State private var recording = false
    @State private var saved = false
    @State private var removed = false
    init(model: AppModel, button: Int) {
        self.model = model; self.button = button
        _press = State(initialValue: model.selectedGesture?.button == button ? (model.selectedGesture?.kind == .buttonHold ? .hold : model.selectedGesture?.clicks == 2 ? .doubleClick : (button < 2 ? .doubleClick : .click)) : (button < 2 ? .doubleClick : .click))
    }
    private var inherited: Bool { !model.isGlobal && !model.effectiveProfile.mappings.contains { $0.trigger.canonical == draft.trigger.canonical } && model.simpleMapping(button: button, kind: kind, clicks: press.count) != nil }
    private var ownMapping: Mapping? { model.effectiveProfile.mappings.first { $0.trigger.canonical == draft.trigger.canonical } }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.buttonTitle(button)).font(.headline)
            if !model.isGlobal {
                Label(ownMapping == nil ? model.text(inherited ? "From All apps" : "No action assigned yet") : model.text("Custom for this app"), systemImage: ownMapping == nil ? "link" : "app.badge")
                    .font(.caption).foregroundStyle(ownMapping == nil ? Color.secondary : Color.accentColor)
            }
            Text(model.text("When you press this button")).font(.caption).foregroundStyle(.secondary)
            HStack {
                Picker(model.text("When you"), selection: $press) {
                    ForEach(presses, id: \.self) { Text(model.text($0.rawValue)).tag($0) }
                }.pickerStyle(.segmented).labelsHidden().modifier(PointingHandCursor()).onChange(of: press) { _, _ in load() }
            }
            if button < 2 {
                Text(model.text(press == .doubleClick ? "Single clicks wait briefly to distinguish a double click. Dragging stays normal." : "Short clicks work on release. Moving the mouse starts normal dragging.")).font(.caption).foregroundStyle(.secondary)
            } else if press != .click {
                Text(model.text(press == .hold ? "Hold this button briefly to run its action." : "Click this button twice quickly to run its action.")).font(.caption).foregroundStyle(.secondary)
            }
            if button >= 2, model.calibratedButtons.first(where: { $0.button == button }) == nil {
                Text(model.text("Where is this button on your mouse?")).font(.caption)
                positionPicker
            }
            Text(model.text("The app will do this")).font(.caption).foregroundStyle(.secondary)
            Button { choosingAction = true } label: {
                    HStack { Text(draft.action == .none ? model.text("Choose an action") : model.text("action." + draft.action.rawValue)).multilineTextAlignment(.leading); Spacer(); Image(systemName: "chevron.down") }.padding(.horizontal, 12).frame(minHeight: 40).frame(maxWidth: .infinity, alignment: .leading).background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8)).contentShape(Rectangle())
                }.buttonStyle(SurfaceButtonStyle()).accessibilityLabel(model.text("Action"))
            VStack(spacing: 8) {
                Button { save() } label: { Text(model.scopeSaveTitle).frame(maxWidth: .infinity) }.buttonStyle(PointingButtonStyle(prominent: true)).disabled(draft.action == .none && ownMapping == nil && (model.isGlobal || !actionChosen))
                if model.isGlobal, let own = ownMapping {
                    Button(role: .destructive) {
                        model.removeMapping(own.id); removed = model.errorMessage == nil; saved = false; load(resetFeedback: false)
                    } label: { Text(model.text("Remove action")).frame(maxWidth: .infinity) }.accessibilityLabel(model.text(press == .hold ? "Remove hold action" : press == .doubleClick ? "Remove double-click action" : "Remove click action")).help(model.text("Removes this action only. Undo restores it."))
                }
            }
            if !model.isGlobal, let own = ownMapping {
                Button { model.removeMapping(own.id); load(); if model.errorMessage == nil { model.lastMessage = model.text("From All apps") } } label: { Text(model.text("Reset to All apps action")).frame(maxWidth: .infinity) }
            }
            if button >= 2 && (press == .doubleClick || model.simpleMapping(button: button, kind: .button, clicks: 2)?.enabled == true) {
                Label(model.text("Double click adds a brief wait to the single-click action on this button."), systemImage: "info.circle").font(.caption).foregroundStyle(.secondary)
            }
            if removed { Label(model.text("Action removed. Undo restores it."), systemImage: "checkmark.circle").font(.caption).foregroundStyle(.secondary) }
            if draft.action.requiresTarget { TextField(model.text("Target"), text: $draft.options.target).textFieldStyle(.roundedBorder) }
            if [.openApp,.openFolder].contains(draft.action) { Button(model.text("Choose target")) { chooseTarget() } }
            if draft.action == .shortcut {
                ShortcutRecorder(model: model, keyCode: $draft.options.keyCode, modifiers: $draft.options.modifiers, recording: $recording).frame(height: 36)
                Button(model.text(recording ? "Stop recording" : "Record shortcut")) { recording.toggle() }
            }
            if draft.action == .shell {
                Toggle(model.text("Allow this shell command"), isOn: $draft.options.shellEnabled)
                Text(model.text("More command options are in Advanced mapping.")).font(.caption).foregroundStyle(.secondary)
            }
            DisclosureGroup(model.text("Names and other gestures")) {
                TextField(model.text("Mapping name (optional)"), text: Binding(get: { draft.name ?? "" }, set: { draft.name = String($0.prefix(150)) })).textFieldStyle(.roundedBorder)
                Toggle(model.text("Enable mapping"), isOn: $draft.enabled)
                if button >= 2, model.calibratedButtons.contains(where: { $0.button == button }) { DisclosureGroup(model.text("Change button position")) { positionPicker } }
            if button >= 2 { HStack {
                EasyDropdown(title: model.text("Add another gesture")) { close in
                    DropdownOption(title: model.text("Hold and move")) { model.pendingMapping = Mapping(trigger: .init(kind: .buttonDrag, button: button), action: .none); close() }
                    DropdownOption(title: model.text("Hold and scroll")) { model.pendingMapping = Mapping(trigger: .init(kind: .buttonWheel, button: button), action: .none); close() }
                    DropdownOption(title: model.text("Advanced mapping")) { model.pendingMapping = draft; close() }
                }
            } }
            }
            if saved { Label(model.scopeSaveFeedback, systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green) }
            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                if model.savedButton == button && model.runtimeReport.lastObservedButton == button && ProcessInfo.processInfo.systemUptime - model.runtimeReport.lastObservedTime < 2 {
                    Label(model.text("Button received. Check the result on your Mac."), systemImage: "hand.tap.fill").font(.caption).foregroundStyle(Color.accentColor)
                }
            }
            if kind == .buttonHold { Text(model.text("Hold the button briefly without moving the mouse.")).font(.caption).foregroundStyle(.secondary) }
        }.padding(15).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
            .onAppear { load() }.onChange(of: model.selectedGesture) { _, trigger in
                guard let trigger, trigger.button == button else { return }
                press = trigger.kind == .buttonHold ? .hold : trigger.clicks == 2 || button < 2 ? .doubleClick : .click; load()
            }.onChange(of: model.effectiveProfile.mappings) { _, _ in load(resetFeedback: false) }
            .sheet(isPresented: $choosingAction) { ActionChooser(model: model, action: Binding(get: { draft.action }, set: { draft.action = $0; actionChosen = true }), triggerKind: kind) }
    }
    private func load(resetFeedback: Bool = true) {
        draft = model.simpleMapping(button: button, kind: kind, clicks: press.count) ?? Mapping(trigger: .init(kind: kind, button: button, clicks: press.count), action: .none)
        actionChosen = false
        if resetFeedback { saved = false; removed = false }
        if ownMapping != nil { removed = false }
        recording = false
    }
    private func save() {
        removed = false
        let clean = draft.name?.trimmingCharacters(in: .whitespacesAndNewlines); draft.name = clean?.isEmpty == false ? clean : nil
        model.saveSimpleMapping(draft); saved = model.errorMessage == nil
    }
    private var positionPicker: some View {
        EasyDropdown(title: model.calibratedButtons.first { $0.button == button }.map { model.text($0.position.rawValue) } ?? model.text("Set position")) { close in
            ForEach(ButtonPosition.allCases, id: \.self) { position in
                DropdownOption(title: model.text(position.rawValue)) { model.calibrate(button: button, position: position); close() }
            }
        }
    }
    private func chooseTarget() {
        let panel = NSOpenPanel(); panel.title = model.text("Choose target"); panel.prompt = model.text("Choose target"); panel.canChooseDirectories = draft.action == .openFolder; panel.canChooseFiles = draft.action == .openApp
        if draft.action == .openApp { panel.allowedContentTypes = [.application] }
        if panel.runModal() == .OK { draft.options.target = panel.url?.path ?? "" }
    }
}

struct AdvancedBindings: View {
    @ObservedObject var model: AppModel
    @State private var expanded: Bool
    init(model: AppModel, initiallyExpanded: Bool = false) { self.model = model; _expanded = State(initialValue: initiallyExpanded) }
    private var otherMappings: [Mapping] { model.effectiveProfile.mappings.filter { ![.button, .buttonHold].contains($0.trigger.kind) || ![1, 2].contains($0.trigger.clicks) || !$0.trigger.modifiers.isEmpty } }
    var body: some View {
        DisclosureGroup(model.text("Other saved gestures") + " (\(otherMappings.count))", isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 12) {
                Text(model.text("These are saved actions for holding and moving, holding and scrolling, or other button combinations.")).font(.caption).foregroundStyle(.secondary)
                if otherMappings.isEmpty { Text(model.text("No other gestures saved. Add one only if you need it.")).foregroundStyle(.secondary) }
                ForEach(otherMappings) { mapping in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) { if let name = mapping.name, !name.isEmpty { Text(name).font(.headline) }
                            Text(triggerLabel(mapping.trigger, model: model)).fixedSize(horizontal: false, vertical: true)
                            Text(model.text("Then") + ": " + model.text("action." + mapping.action.rawValue)).font(.caption).foregroundStyle(.secondary) }
                        Spacer(); Button(model.text("Edit")) { model.pendingMapping = mapping }
                        Button(model.text("Remove"), role: .destructive) { model.removeMapping(mapping.id) }
                    }
                    Divider()
                }
                Button(model.text("Add advanced mapping")) { model.pendingMapping = Mapping(trigger: .init(), action: .none) }
                if model.devices.contains(where: { $0.magicMouse }) {
                    Toggle(model.text("Enable Magic Mouse gestures"), isOn: Binding(get: { model.configuration.touchEnabled }, set: { v in model.update { $0.touchEnabled = v } }))
                    Text(model.text("Magic Mouse gestures are still being tested.")).font(.caption)
                }
            }.padding(.top, 12)
        }
    }
}
