import SwiftUI
import MouseCore

/// Gesture settings can be prepared before the hardware arrives. Viewing this
/// page never starts a touch adapter; only the explicit switch does that.
struct MagicMousePage: View {
    @ObservedObject var model: AppModel
    @State private var adding = false
    @State private var guide = false
    @State private var tuning = false
    private var connected: Bool { model.devices.contains { $0.magicMouse } }
    var body: some View {
        HStack {
            Toggle(model.text("Use Magic Mouse touch gestures"), isOn: Binding(get: { model.configuration.touchEnabled }, set: { enabled in model.update { $0.touchEnabled = enabled } })).modifier(PointingHandCursor())
            Spacer()
            Button { guide = true } label: { Image(systemName: "questionmark.circle") }.accessibilityLabel(model.text("See gesture examples"))
            Button { adding = true } label: { Label(model.text("Add gesture"), systemImage: "plus") }.buttonStyle(PointingButtonStyle(prominent: true))
        }
        if !connected { Text(model.text("Set up now, try when connected")).font(.caption).foregroundStyle(.secondary) }
        Text(model.text("Choose an action in each row. Changes save automatically.")).font(.caption).foregroundStyle(.secondary)
        ActionMappingList(model: model, touch: true)
        DisclosureGroup(model.text("Ready-made setups")) {
            Button(model.text("Review suggested gestures")) { model.pendingPreset = "magic" }
            Text(model.text("Only the listed actions change. Other mappings are kept.")).font(.caption).foregroundStyle(.secondary)
        }
        DisclosureGroup(model.text("Touch feel"), isExpanded: $tuning) { MagicTouchTuning(model: model).padding(.top, 12) }
        DisclosureGroup(model.text("Connection and permissions")) {
            Text(model.text(connected ? "Touch input is experimental. Enable GlideMouse and allow its permissions to try it." : "Your setup is saved. Touch input starts only when a supported Magic Mouse is connected and GlideMouse is enabled.")).font(.caption).foregroundStyle(.secondary)
            Text(model.text("If a double tap also triggers macOS Smart Zoom, turn Smart Zoom off in System Settings → Mouse → More Gestures. Pause other mouse utilities while testing.")).font(.caption).foregroundStyle(.secondary)
        }
        .sheet(isPresented: $guide) { MouseActionGuide(model: model, initialMode: "touch") }
        .sheet(isPresented: $adding) { AddInputSheet(model: model, touch: true, buttons: []) }
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
