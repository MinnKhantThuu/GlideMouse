import SwiftUI
import MouseCore

/// Gesture settings can be prepared before the hardware arrives. Viewing this
/// page never starts a touch adapter; only the explicit switch does that.
struct MagicMousePage: View {
    @ObservedObject var model: AppModel
    @State private var kind: TriggerKind = .tap
    @State private var fingers = 1
    @State private var clicks = 1
    @State private var direction: Direction = .left
    @State private var modifiers: Modifiers = []
    @State private var guide = false
    @State private var tuning = false
    private var connected: Bool { model.devices.contains { $0.magicMouse } }
    private var trigger: Trigger { Trigger(kind: kind, fingers: [.tap, .swipe].contains(kind) ? fingers : 1, clicks: clicks, direction: direction, modifiers: modifiers).canonical }
    private var current: Mapping? { model.effectiveProfile.mappings.first { $0.trigger.canonical == trigger } ?? (model.isGlobal ? nil : model.configuration.globalDefaults.mappings.first { $0.trigger.canonical == trigger }) }
    private var inherited: Bool { !model.isGlobal && !model.effectiveProfile.mappings.contains { $0.trigger.canonical == trigger } && current != nil }
    private var saved: [Mapping] {
        let profiles = [model.effectiveProfile]
        return ProfileResolver.displayTriggers(in: profiles).filter { MagicMouseCatalog.touchKinds.contains($0.kind) }.compactMap { input in model.effectiveProfile.mappings.first { $0.trigger.canonical == input } }
    }
    var body: some View {
        SectionBox(title: model.text("Magic Mouse")) {
            HStack {
                Label(model.text(connected ? "Magic Mouse connected" : "Set up now, try when connected"), systemImage: connected ? "checkmark.circle" : "computermouse")
                Spacer()
                Button(model.text("See gesture examples")) { guide = true }
            }
            Text(model.text("Prepare gestures here even without a Magic Mouse. These settings do not remap the buttons on your other mouse.")).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Toggle(model.text("Use Magic Mouse touch gestures"), isOn: Binding(get: { model.configuration.touchEnabled }, set: { enabled in model.update { $0.touchEnabled = enabled } })).modifier(PointingHandCursor())
                Spacer()
                Button(model.text("Review suggested gestures")) { model.pendingPreset = "magic" }
            }
            DisclosureGroup(model.text("Connection and permissions")) {
                Text(model.text(connected ? "Touch input is experimental. Enable GlideMouse and allow its permissions to try it." : "Your setup is saved. Touch input starts only when a supported Magic Mouse is connected and GlideMouse is enabled.")).font(.caption).foregroundStyle(.secondary)
            }
        }
        SectionBox(title: model.text("Choose a gesture")) {
            Text(triggerLabel(trigger, model: model)).font(.headline)
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(current.map { model.text($0.enabled ? "action." + $0.action.rawValue : "Disabled") } ?? model.text("No action set"))
                    if inherited { Text(model.text("Inherited from All apps. Save here to change it only for this app.")).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
                Button(model.text(current == nil ? "Set action" : "Change action")) {
                    var mapping = current ?? Mapping(trigger: trigger, action: .none)
                    if inherited { mapping.id = UUID() }
                    mapping.trigger = trigger
                    model.pendingMapping = mapping
                }
            }
            Divider()
            EasyPicker(label: model.text("Gesture"), selection: $kind, values: [TriggerKind.tap, .rightTap, .swipe, .pinchIn, .pinchOut, .touchHold]) { model.text("trigger." + $0.rawValue) }
            if [.tap, .swipe].contains(kind) {
                EasyPicker(label: model.text("Fingers"), selection: $fingers, values: [1, 2, 3]) { String($0) }
            }
            if [.tap, .rightTap].contains(kind) {
                EasyPicker(label: model.text("Number of taps"), selection: $clicks, values: [1, 2, 3]) { model.text($0 == 1 ? "Single tap" : $0 == 2 ? "Double tap" : "Triple tap") }
            }
            if kind == .swipe {
                EasyPicker(label: model.text("Direction"), selection: $direction, values: fingers == 1 ? [.left, .right] : Direction.allCases) { model.text($0.rawValue) }
            }
            if kind == .touchHold { Text(model.text("Tap once, then touch again and hold or move. Move the mouse to drag; lift that finger to release. Use another finger to scroll while dragging.")).font(.callout).foregroundStyle(.secondary) }
            DisclosureGroup(model.text("Add a modifier key")) {
                HStack {
                    modifier(.command, "⌘"); modifier(.option, "⌥"); modifier(.control, "⌃"); modifier(.shift, "⇧")
                }.padding(.top, 8)
                Text(model.text("An explicit modifier gesture overrides the ordinary one. Otherwise Command, Option, Control and Shift stay attached to click and drag actions.")).font(.caption).foregroundStyle(.secondary)
            }

        }
        DisclosureGroup(model.text("Saved touch gestures") + " (\(saved.count))") {
            if saved.isEmpty { Text(model.text("No touch gestures saved yet. Review the suggested gestures or set an action above.")).foregroundStyle(.secondary).padding(.top, 10) }
            ForEach(saved) { mapping in
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) { Text(triggerLabel(mapping.trigger, model: model)); Text(model.text(mapping.enabled ? "action." + mapping.action.rawValue : "Disabled")).font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    Button(model.text("Edit")) { model.pendingMapping = mapping }
                    Button(model.text("Delete"), role: .destructive) { model.removeMapping(mapping.id) }
                }.padding(.vertical, 10)
                Divider()
            }
        }
        DisclosureGroup(model.text("Touch feel"), isExpanded: $tuning) { MagicTouchTuning(model: model).padding(.top, 12) }
        SectionBox(title: model.text("Before your first test")) {
            Text(model.text("If a double tap also triggers macOS Smart Zoom, turn Smart Zoom off in System Settings → Mouse → More Gestures. Pause other mouse utilities while testing.")).font(.callout).fixedSize(horizontal: false, vertical: true)
            Text(model.text("Start with tap and right-side tap, then try swipes, pinch, drag and drag scrolling. The examples are illustrations; real Magic Mouse testing is still required.")).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .sheet(isPresented: $guide) { MouseActionGuide(model: model, initialMode: "touch") }
        .onChange(of: fingers) { _, value in if value == 1 && [.up, .down].contains(direction) { direction = .left } }
    }
    private func modifier(_ flag: Modifiers, _ label: String) -> some View {
        Toggle(label, isOn: Binding(get: { modifiers.contains(flag) }, set: { enabled in if enabled { modifiers.insert(flag) } else { modifiers.remove(flag) } })).toggleStyle(.button).modifier(PointingHandCursor())
    }
}

struct MagicTouchTuning: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(model.text("Change one setting at a time. Larger movement thresholds reduce accidental gestures.")).font(.caption).foregroundStyle(.secondary)
            control("Tap duration", "How long a touch can last and still count as a tap.", \.tapDuration, 0.05...0.6)
            control("Multi-tap interval", "Time allowed between taps. Increase if you double-tap slowly.", \.multiTapInterval, 0.1...0.8)
            control("Tap movement", "How far your finger can move during a tap. Lower values reject more accidental touches.", \.tapMovement, 0.005...0.2)
            control("Tap slide speed", "Reject a fast brush across the mouse even if the total movement is small.", \.tapSlideSpeed, 0.1...10)
            control("Swipe distance", "How far to swipe before the action runs.", \.swipeDistance, 0.04...0.6)
            control("Swipe speed", "Minimum swipe speed. Zero accepts slow, deliberate swipes.", \.swipeSpeed, 0...5)
            control("Pinch distance", "How much to pinch or spread before a zoom shortcut runs.", \.pinchDistance, 0.02...0.5)
            control("Right zone", "Where the right-click zone starts, from the left edge of the mouse.", \.rightZone, 0.3...0.8)
            control("Right zone front", "Limit right-side taps to the front of the mouse. Zero uses the whole right side.", \.rightZoneFront, 0...0.8)
            control("Resting delay", "How long a stationary finger waits before new touches can ignore it.", \.restingDelay, 0.3...3)
            control("Touch hold delay", "Time to hold the second touch before dragging starts. Moving that finger also starts a drag. Mouse button holds are unchanged.", \.touchHoldDelay, 0.15...1.5)
            control("Drag scroll speed", "How far the page scrolls as the second finger moves during a drag.", \.dragScrollSpeed, 100...2000)
            Toggle(model.text("Reverse scroll while dragging"), isOn: Binding(get: { model.configuration.tuning.dragScrollReverse }, set: { value in model.update { $0.tuning.dragScrollReverse = value } })).modifier(PointingHandCursor())
            control("App switch delay", "Keep the app chooser open between swipes; select the highlighted app after this pause.", \.appSwitchDelay, 0.2...3)
            Text(model.text("Tap and swipe distances are fractions of the touch surface. Timing is in seconds; drag scroll speed uses pixels per surface length.")).font(.caption).foregroundStyle(.secondary)
        }
    }
    private func control(_ label: String, _ help: String, _ key: WritableKeyPath<Tuning, Double>, _ range: ClosedRange<Double>) -> some View {
        MagicTuningSlider(model: model, label: label, help: help, key: key, range: range)
    }
}
private struct MagicTuningSlider: View {
    @ObservedObject var model: AppModel
    let label: String; let help: String; let key: WritableKeyPath<Tuning, Double>; let range: ClosedRange<Double>
    @State private var draft: Double?
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(model.text(label)).frame(width: 155, alignment: .leading)
                Slider(value: Binding(get: { draft ?? model.configuration.tuning[keyPath: key] }, set: { draft = $0 }), in: range, onEditingChanged: { active in if !active, let value = draft { model.update { $0.tuning[keyPath: key] = value }; draft = nil } })
                Text(draft ?? model.configuration.tuning[keyPath: key], format: .number.precision(.fractionLength(2))).monospacedDigit().frame(width: 55)
            }
            Text(model.text(help)).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
