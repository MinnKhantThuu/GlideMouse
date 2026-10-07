import SwiftUI
import MouseCore

struct CalibrationControls: View {
    @ObservedObject var model: AppModel
    @State private var capturing = false
    @State private var detected: Int?
    @State private var position: ButtonPosition = .extra
    @State private var confirmed = false
    private var canCapture: Bool { model.devices.count == 1 && model.accessibility && model.inputMonitoring }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(model.text("Press a real button, then tell us where it is.")).font(.headline)
            Text(model.text("Your mouse reports button numbers, not their positions. This setup keeps the picture correct after reopening the app.")).font(.caption).foregroundStyle(.secondary)
            if model.devices.count > 1 { Text(model.text("Connect only the mouse you are setting up. Mouse input cannot yet be separated by device.")).foregroundStyle(.orange) }
            if model.devices.isEmpty { Text(model.text("Connect a USB or Bluetooth mouse, then refresh.")); Button(model.text("Refresh")) { model.refresh() } }
            Button(model.text(capturing ? "Stop capture" : "Start capture")) { capturing.toggle(); if !capturing { model.setMouseCaptureArea(nil) } }.disabled(!canCapture)
            MouseCaptureArea(armed: capturing && canCapture, label: model.text(capturing ? "Press one wheel or side button inside this box." : "Start capture, then move the pointer into this box."), holdDelay: model.configuration.tuning.holdDelay, dragDistance: model.configuration.tuning.dragDistance, areaChanged: { model.setMouseCaptureArea($1, owner: $0) }) { trigger, _ in
                if let trigger { detected = trigger.button; confirmed = false; position = trigger.button == 2 ? .wheel : .extra }
            }.frame(height: 90)
            if let detected {
                HStack {
                    Text(model.text("Detected button") + " \(detected + 1)")
                    Spacer()
                    EasyPicker(label: model.text("Position"), selection: $position, values: ButtonPosition.allCases) { model.text($0.rawValue) }.frame(width: 245)
                }
                Button(model.text("Confirm position")) { model.calibrate(button: detected, position: position); confirmed = model.errorMessage == nil }
                if confirmed { Label(model.text("Position saved. Press another button to add it."), systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green) }
            }
            if !model.calibratedButtons.isEmpty {
                Divider()
                ForEach(model.calibratedButtons, id: \.button) { button in
                    HStack { Text(model.text(button.position.rawValue)); Spacer(); Text(model.text("Button") + " \(button.button + 1)").font(.caption).foregroundStyle(.secondary) }
                }
            }
            Text(model.text("Left and right clicks keep working. Existing actions outside the capture box stay active.")).font(.caption).foregroundStyle(.secondary)
        }
    }
}
struct CalibrationSheet: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(model.text("Identify your mouse buttons")).font(.title2.bold())
            ScrollView { CalibrationControls(model: model).padding(.vertical, 4) }
            HStack { Spacer(); Button(model.text("Done")) { model.setMouseCaptureArea(nil); model.showCalibration = false }.keyboardShortcut(.defaultAction) }
        }.padding(24).frame(width: 560,height: 575).buttonStyle(PointingButtonStyle()).background(Color(nsColor: .windowBackgroundColor))
    }
}
struct MouseSetupWizard: View {
    @ObservedObject var model: AppModel
    @State private var step = 0
    @State private var setup = "keep"
    init(model: AppModel, initialStep: Int = 0) {
        self.model = model; _step = State(initialValue: initialStep)
        _setup = State(initialValue: model.configuration.globalDefaults.mappings.isEmpty ? "smooth" : "keep")
    }
    private var hasSides: Bool { model.calibratedButtons.contains { $0.position == .upper } && model.calibratedButtons.contains { $0.position == .lower } }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text(model.text("Set up your mouse")).font(.title2.bold()); Spacer(); Text("\(step + 1) / 3").font(.caption).foregroundStyle(.secondary) }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if step == 0 {
                        Text(model.text("Allow mouse control")).font(.headline)
                        PermissionControls(model: model)
                        Text(model.text("After access is granted, you can identify a button and choose its action.")).foregroundStyle(.secondary)
                    } else if step == 1 {
                        CalibrationControls(model: model)
                    } else {
                        Text(model.text("Choose how to start")).font(.headline)
                        Picker(model.text("Starter setup"), selection: $setup) {
                            Text(model.text("Keep my current settings")).tag("keep")
                            Text(model.text("Smooth scrolling only")).tag("smooth")
                            Text(model.text("Desktop navigation")).tag("desktop").disabled(!hasSides)
                            Text(model.text("Browser navigation")).tag("browser").disabled(!hasSides)
                        }.pickerStyle(.radioGroup)
                        Text(model.text("Only the listed inputs change. Your other mappings stay in place. Undo restores the previous settings.")).font(.caption).foregroundStyle(.secondary)
                        ForEach(model.proposedPreset(setup)) { mapping in
                            HStack { Text(model.buttonTitle(mapping.button) + " · " + model.text(mapping.trigger.kind == .buttonHold ? "Hold" : "Click")); Spacer(); Text(model.text("action." + mapping.action.rawValue)) }
                        }
                        if !hasSides { Text(model.text("Identify both side buttons to use a starter setup.")).font(.caption) }
                        Text(model.text("You can change Click and Hold actions separately from the mouse picture.")).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 5)
            }
            Divider()
            HStack {
                Button(model.text("Later")) { model.setMouseCaptureArea(nil); model.showMouseSetup = false }
                if step > 0 { Button(model.text("Back")) { model.setMouseCaptureArea(nil); step -= 1 } }
                Spacer()
                Button(model.text(step == 2 ? "Start using GlideMouse" : "Next")) {
                    model.setMouseCaptureArea(nil)
                    if step < 2 { step += 1 }
                    else {
                        if setup == "smooth" { model.update { $0.scroll = ScrollPreset.smooth.applying(to: $0.scroll); $0.engineEnabled = true } }
                        else if setup != "keep" { model.preset(setup); if model.errorMessage == nil { model.update { $0.engineEnabled = true } } }
                        if model.errorMessage == nil { model.completeSetup() }
                    }
                }.buttonStyle(PointingButtonStyle(prominent: true)).disabled((step == 0 && (!model.accessibility || !model.inputMonitoring)) || (step == 2 && ["desktop", "browser"].contains(setup) && !hasSides))
            }
        }.padding(24).frame(width: 590,height: 610).buttonStyle(PointingButtonStyle()).background(Color(nsColor: .windowBackgroundColor))
    }
}
