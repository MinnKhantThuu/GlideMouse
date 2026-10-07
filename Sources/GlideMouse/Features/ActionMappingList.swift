import SwiftUI
import AppKit
import MouseCore

/// One input, its effective action, and its removal control share one row.
struct ActionMappingList: View {
    @ObservedObject var model: AppModel
    let touch: Bool
    private var triggers: [Trigger] { model.listTriggers(touch: touch) }
    private var sections: [String] {
        if touch { return ["Taps", "Swipes", "Pinch and drag", "Modified gestures"].filter { section in triggers.contains { group($0) == section } } }
        return Array(Set(triggers.map(\.button))).sorted().map { String($0) }
    }
    private func group(_ trigger: Trigger) -> String {
        guard trigger.modifiers.isEmpty else { return "Modified gestures" }
        switch trigger.kind { case .tap, .rightTap: return "Taps"; case .swipe: return "Swipes"; default: return "Pinch and drag" }
    }
    var body: some View {
        if triggers.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(model.text(touch ? "No gestures added yet" : "No button actions added yet")).font(.headline)
                Text(model.text(touch ? "Use Add gesture to choose a tap, swipe or pinch." : "Use Add button action, then press a button or choose it from the list.")).foregroundStyle(.secondary)
            }.padding(.vertical, 24)
        } else {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(sections, id: \.self) { section in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(touch ? model.text(section) : model.buttonTitle(Int(section)!)).font(.headline).foregroundStyle(.secondary).padding(.bottom, 6)
                        ForEach(triggers.filter { touch ? group($0) == section : String($0.button) == section }, id: \.self) { trigger in
                            MappingActionRow(model: model, trigger: trigger)
                            Divider().padding(.leading, 54)
                        }
                    }
                }
            }
        }
    }
}

@MainActor func friendlyInputTitle(_ trigger: Trigger, model: AppModel) -> String {
    let t = trigger.canonical
    if !t.modifiers.isEmpty { return triggerLabel(t, model: model) }
    switch t.kind {
    case .button: return model.text(t.clicks == 1 ? "Click once" : t.clicks == 2 ? "Double click" : "Triple click")
    case .buttonHold: return model.text("Hold")
    case .tap:
        let key = t.clicks == 1 ? "%d-finger tap" : t.clicks == 2 ? "%d-finger double tap" : "%d-finger triple tap"
        return String(format: model.text(key), t.fingers)
    case .rightTap: return model.text(t.clicks == 1 ? "Right-side tap" : t.clicks == 2 ? "Right-side double tap" : "Right-side triple tap")
    case .swipe:
        return String(format: model.text("%d-finger swipe %@"), t.fingers, model.text(t.direction.rawValue))
    case .pinchIn: return model.text("Pinch in")
    case .pinchOut: return model.text("Spread")
    case .touchHold: return model.text("Tap then hold")
    default: return triggerLabel(t, model: model)
    }
}

struct MappingActionRow: View {
    @ObservedObject var model: AppModel
    let trigger: Trigger
    @State private var choosing = false
    @State private var picked: MouseAction?
    @State private var details: Mapping?
    private var mapping: Mapping? { model.listMapping(for: trigger) }
    private var inherited: Bool { !model.isGlobal && !model.ownsListMapping(trigger) }
    private var actionTitle: String {
        guard let mapping else { return model.text("Choose an action") }
        if !mapping.enabled { return model.text("Disabled") }
        if mapping.action == .shortcut { return ShortcutDisplay.label(keyCode: mapping.options.keyCode, modifiers: mapping.options.modifiers, translate: model.text) }
        return model.text("action." + mapping.action.rawValue)
    }
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 12) {
                InputGlyph(trigger: trigger, position: model.calibratedButtons.first { $0.button == trigger.button }?.position)
                    .frame(width: 42, height: 54).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(friendlyInputTitle(trigger, model: model)).fixedSize(horizontal: false, vertical: true)
                    if !model.isGlobal { Text(model.text(inherited ? "From All apps" : "Custom for this app")).font(.caption).foregroundStyle(.secondary) }
                }.frame(maxWidth: .infinity, alignment: .leading)
                Button { picked = nil; choosing = true } label: { DropdownLabel(title: actionTitle) }
                    .buttonStyle(SurfaceButtonStyle()).frame(width: min(300, geometry.size.width * 0.44))
                    .accessibilityLabel(friendlyInputTitle(trigger, model: model) + ": " + model.text("Action")).accessibilityValue(actionTitle)
                Button(role: .destructive) { model.removeListAction(for: trigger) } label: {
                    Image(systemName: inherited ? "link" : "trash").frame(width: 38, height: 40).contentShape(Rectangle())
                }.buttonStyle(SurfaceButtonStyle()).disabled(inherited)
                    .accessibilityLabel(model.text(inherited ? "From All apps" : "Remove action"))
                    .help(model.text(inherited ? "This action comes from All apps. Choose another action to change it only here." : "Removes this action only. Undo restores it."))
                Menu {
                    if let mapping, mapping.action.requiresTarget || mapping.action == .shortcut {
                        Button(model.text("Edit action details")) { details = mapping }
                    }
                    Button(model.text("Advanced mapping")) {
                        var draft = mapping ?? Mapping(trigger: trigger, action: .none)
                        if inherited { draft.id = UUID() }
                        model.pendingMapping = draft
                    }
                    if !model.isGlobal && model.ownsListMapping(trigger) {
                        Button(model.text("Reset to All apps action")) { model.removeListAction(for: trigger) }
                    }
                } label: { Image(systemName: "ellipsis").frame(width: 18, height: 40) }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().modifier(PointingHandCursor())
                    .accessibilityLabel(model.text("More options"))
            }
        }.frame(height: model.isGlobal ? 76 : 84)
        .sheet(isPresented: $choosing, onDismiss: applyChoice) {
            ActionChooser(model: model, action: Binding(get: { picked ?? mapping?.action ?? .none }, set: { picked = $0 }), triggerKind: trigger.kind)
        }
        .sheet(item: $details) { draft in ActionDetailsSheet(model: model, mapping: draft) }
    }
    private func applyChoice() {
        guard let action = picked else { return }; picked = nil
        if action.requiresTarget || action == .shortcut {
            var draft = mapping ?? Mapping(trigger: trigger, action: action)
            if draft.action != action { draft.options = ActionOptions() }
            draft.action = action; draft.enabled = true; details = draft
        } else { model.setListAction(action, for: trigger) }
    }
}

/// Small diagrams identify input rather than act as the settings navigation.
struct InputGlyph: View {
    let trigger: Trigger
    var position: ButtonPosition?
    private var touch: Bool { MagicMouseCatalog.touchKinds.contains(trigger.kind) }
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(Color(nsColor: .controlBackgroundColor))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.secondary.opacity(0.55), lineWidth: 1.4))
            if !touch {
                Path { p in p.move(to: .init(x: 21, y: 2)); p.addLine(to: .init(x: 21, y: 19)); p.move(to: .init(x: 3, y: 19)); p.addLine(to: .init(x: 39, y: 19)) }.stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                // A number alone is honest when the physical position is not known.
                if trigger.button < 2 || position != nil {
                    Circle().fill(Color.accentColor).frame(width: 8, height: 8)
                        .offset(x: trigger.button == 0 ? -9 : trigger.button == 1 ? 9 : position == .upper || position == .lower ? -16 : 0, y: trigger.button < 2 ? -17 : position == .lower ? 5 : position == .upper ? -6 : -16)
                }
                Text("\(trigger.button + 1)").font(.system(size: 10, weight: .semibold)).offset(y: 13)
            } else if [.tap, .rightTap].contains(trigger.kind) {
                HStack(spacing: 3) { ForEach(0..<trigger.fingers, id: \.self) { _ in Circle().fill(Color.accentColor).frame(width: 7, height: 7) } }.offset(x: trigger.kind == .rightTap ? 9 : 0, y: -12)
            } else {
                Image(systemName: trigger.kind == .swipe ? (trigger.direction == .left ? "arrow.left" : trigger.direction == .right ? "arrow.right" : trigger.direction == .up ? "arrow.up" : "arrow.down") : trigger.kind == .touchHold ? "hand.draw" : trigger.kind == .pinchIn ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(Color.accentColor)
            }
            if trigger.clicks > 1 { Text("\(trigger.clicks)×").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.accentColor).offset(y: touch ? 15 : -3) }
            if trigger.kind == .buttonHold { Image(systemName: "clock").font(.system(size: 9)).foregroundStyle(Color.accentColor).offset(x: 11, y: 14) }
        }
    }
}

struct AddInputSheet: View {
    @ObservedObject var model: AppModel
    let touch: Bool
    let buttons: [Int]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedButton: Int?
    @State private var captured: Trigger?
    @State private var choosing = false
    @State private var picked: MouseAction?
    @State private var details: Mapping?
    @State private var advanced: Mapping?
    private var button: Int? { selectedButton ?? model.selectedButton }
    private var inputs: [Trigger] {
        guard let button else { return [] }
        return (button < 2 ? [Trigger(button: button, clicks: 2), Trigger(kind: .buttonHold, button: button)] : [Trigger(button: button), Trigger(button: button, clicks: 2), Trigger(kind: .buttonHold, button: button)])
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text(model.text(touch ? "Add gesture" : "Add button action")).font(.title2.bold()); Spacer(); Button(model.text("Cancel")) { dismiss() }.keyboardShortcut(.cancelAction) }
            Text(String(format: model.text("Saving these changes affects: %@"), model.editingScopeName)).font(.caption).foregroundStyle(.secondary)
            if touch {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(["Taps", "Swipes", "Pinch and drag"], id: \.self) { group in
                            Text(model.text(group)).font(.headline).padding(.top, 8)
                            ForEach(MagicMouseCatalog.triggers.filter { group == "Taps" ? [.tap, .rightTap].contains($0.kind) : group == "Swipes" ? $0.kind == .swipe : [.pinchIn, .pinchOut, .touchHold].contains($0.kind) }, id: \.self) { trigger in inputOption(trigger) }
                        }
                    }
                }
            } else {
                Text(model.text("Press a mouse button in this box, or choose it below.")).foregroundStyle(.secondary)
                MouseCaptureArea(armed: !choosing && details == nil && advanced == nil, label: model.text("Press your mouse button here"), holdDelay: model.configuration.tuning.holdDelay, dragDistance: model.configuration.tuning.dragDistance, areaChanged: { model.setMouseCaptureArea($1, owner: $0) }) { trigger, _ in
                    if let trigger { selectedButton = trigger.button }
                }.frame(height: 64)
                EasyDropdown(title: button.map { model.buttonTitle($0) } ?? model.text("Choose a mouse button")) { close in
                    ForEach(Array(Set([0, 1] + buttons + (button.map { [$0] } ?? []))).sorted(), id: \.self) { number in
                        DropdownOption(title: model.buttonTitle(number)) { selectedButton = number; close() }
                    }
                }
                if let button {
                    ForEach(inputs, id: \.self) { trigger in inputOption(trigger) }
                    if button < 2 { Text(model.text("Select 1 or 2 to assign double click or hold.")).font(.caption).foregroundStyle(.secondary) }
                    Text(model.text("Double click adds a brief wait to the single-click action on this button.")).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            DisclosureGroup(model.text("Advanced")) {
                Button(model.text("Advanced mapping")) {
                    let trigger = touch ? Trigger(kind: .tap) : Trigger(kind: (button ?? 2) < 2 ? .buttonHold : .buttonDrag, button: button ?? 2)
                    advanced = Mapping(trigger: trigger, action: .none)
                }
            }
        }.padding(24).frame(width: 540, height: 590).buttonStyle(PointingButtonStyle())
        .onDisappear { model.setMouseCaptureArea(nil) }
        .sheet(isPresented: $choosing, onDismiss: applyChoice) {
            if let captured { ActionChooser(model: model, action: Binding(get: { picked ?? model.listMapping(for: captured)?.action ?? .none }, set: { picked = $0 }), triggerKind: captured.kind) }
        }
        .sheet(item: $advanced) { mapping in MappingEditor(model: model, mapping: mapping) }
        .sheet(item: $details) { mapping in ActionDetailsSheet(model: model, mapping: mapping, saved: { dismiss() }) }
    }
    private func inputOption(_ trigger: Trigger) -> some View {
        Button { captured = trigger; picked = nil; model.setMouseCaptureArea(nil); choosing = true } label: {
            HStack(spacing: 14) {
                InputGlyph(trigger: trigger, position: model.calibratedButtons.first { $0.button == trigger.button }?.position).frame(width: 34, height: 46).accessibilityHidden(true)
                Text(friendlyInputTitle(trigger, model: model)); Spacer()
                Image(systemName: model.listMapping(for: trigger) == nil ? "chevron.right" : "checkmark").foregroundStyle(.secondary)
            }.padding(10).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        }.buttonStyle(SurfaceButtonStyle())
    }
    private func applyChoice() {
        guard let action = picked, let captured else { return }; picked = nil
        if action.requiresTarget || action == .shortcut {
            var mapping = model.listMapping(for: captured) ?? Mapping(trigger: captured, action: action)
            if mapping.action != action { mapping.options = ActionOptions() }
            mapping.action = action; mapping.enabled = true; details = mapping
        } else {
            model.setListAction(action, for: captured)
            if model.errorMessage == nil { dismiss() }
        }
    }
}

struct ActionDetailsSheet: View {
    @ObservedObject var model: AppModel
    @State var mapping: Mapping
    var saved: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @State private var recording = true
    @State private var recorded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(model.text("action." + mapping.action.rawValue)).font(.title2.bold())
            Text(friendlyInputTitle(mapping.trigger, model: model)).foregroundStyle(.secondary)
            if mapping.action == .shortcut {
                Text(model.text("Click the field, then press your shortcut.")).font(.callout)
                ShortcutRecorder(model: model, keyCode: Binding(get: { mapping.options.keyCode }, set: { mapping.options.keyCode = $0; recorded = true }), modifiers: $mapping.options.modifiers, recording: $recording).frame(height: 44)
            }
            if mapping.action.requiresTarget { TextField(model.text("Target"), text: $mapping.options.target).textFieldStyle(.roundedBorder) }
            if [.openApp, .openFolder].contains(mapping.action) { Button(model.text("Choose target")) { chooseTarget() } }
            if mapping.action == .shell {
                Toggle(model.text("Allow this shell command"), isOn: $mapping.options.shellEnabled)
                DisclosureGroup(model.text("Advanced")) {
                    TextField(model.text("Working directory"), text: $mapping.options.workingDirectory).textFieldStyle(.roundedBorder)
                    Slider(value: $mapping.options.timeout, in: 1...60, step: 1) { Text(model.text("Timeout")) }
                }
            }
            HStack {
                Button(model.text("Cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(model.text("Save")) {
                    model.setListAction(mapping.action, for: mapping.trigger, options: mapping.options)
                    if model.errorMessage == nil { recording = false; dismiss(); saved() }
                }.buttonStyle(PointingButtonStyle(prominent: true)).keyboardShortcut(.defaultAction)
                    .disabled((mapping.action.requiresTarget && mapping.options.target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) || (mapping.action == .shortcut && !recorded && model.listMapping(for: mapping.trigger)?.action != .shortcut))
            }
        }.padding(24).frame(width: 480).buttonStyle(PointingButtonStyle())
    }
    private func chooseTarget() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = mapping.action == .openApp ? [.application] : [.folder]; panel.canChooseDirectories = mapping.action == .openFolder
        panel.title = model.text("Choose target"); panel.prompt = model.text("Choose target")
        if panel.runModal() == .OK, let url = panel.url { mapping.options.target = url.path }
    }
}
