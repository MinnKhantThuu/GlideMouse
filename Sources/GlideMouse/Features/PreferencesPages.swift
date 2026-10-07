import SwiftUI
import AppKit
import MouseCore

struct ScrollingPage: View {
    @ObservedObject var model: AppModel
    @State private var advancedScroll = false
    private var settings: ScrollSettings { model.effectiveProfile.scroll ?? model.configuration.scroll }
    private func edit(_ mutation: (inout ScrollSettings) -> Void) {
        if model.isGlobal { model.update { mutation(&$0.scroll) } }
        else { model.mutateProfile { p in var s = p.scroll ?? model.configuration.scroll; mutation(&s); p.scroll = s } }
    }
    private func toggle(_ title: String, _ key: WritableKeyPath<ScrollSettings,Bool>) -> some View {
        Toggle(model.text(title), isOn: Binding(get: { settings[keyPath: key] }, set: { v in edit { $0[keyPath: key] = v } }))
    }
    var body: some View {
        if !model.isGlobal { Toggle(model.text("Use different scrolling in this app"), isOn: Binding(get: { model.effectiveProfile.scroll != nil }, set: { enabled in model.mutateProfile { $0.scroll = enabled ? model.configuration.scroll : nil } })) }
        if !model.isGlobal && model.effectiveProfile.scroll == nil { Text(model.text("Using All apps scrolling. Enable the switch above to customize this app.")).font(.caption).foregroundStyle(.secondary) }
        SectionBox(title: model.text("Wheel feel")) {
            toggle("Enable wheel processing", \.enabled)
            Picker(model.text("Scroll feel"), selection: Binding(get: { ScrollPreset.matching(settings) }, set: { preset in if preset == .custom { advancedScroll = true } else { edit { $0 = preset.applying(to: $0) } } })) { ForEach(ScrollPreset.allCases, id: \.self) { Text(model.text($0.rawValue)).tag($0) } }.pickerStyle(.segmented).modifier(PointingHandCursor())
            slider("Speed", key: \.speed, range: 0.2...5)
            Picker(model.text("Scroll direction"), selection: Binding(get: { settings.reverseVertical }, set: { value in edit { $0.reverseVertical = value } })) { Text(model.text("Standard direction")).tag(false); Text(model.text("Reverse direction")).tag(true) }.pickerStyle(.segmented).modifier(PointingHandCursor())
            DisclosureGroup(model.text("Fine-tune scrolling"), isExpanded: $advancedScroll) {
            VStack(alignment: .leading, spacing: 12) {
            Picker(model.text("Smoothness"), selection: Binding(get: { settings.smoothness }, set: { v in edit { $0.smoothness = v } })) { ForEach(Smoothness.allCases, id: \.self) { Text(model.text($0.rawValue)).tag($0) } }.pickerStyle(.segmented).modifier(PointingHandCursor())
            toggle("Momentum", \.momentum)
            slider("Acceleration", key: \.acceleration, range: 0...1)
            toggle("Reverse vertical", \.reverseVertical)
            toggle("Reverse horizontal", \.reverseHorizontal)
            toggle("Shift + wheel scrolls horizontally", \.shiftHorizontal)
            toggle("Option + wheel zooms", \.optionZoom)
            toggle("Control + wheel precision", \.precisionModifier)
            }.padding(.top, 10)
            }
        }
        .disabled(!model.isGlobal && model.effectiveProfile.scroll == nil)
        Text(model.text("Trackpad and Magic Mouse continuous scrolling stays native. These settings process discrete mouse wheels only.")).foregroundStyle(.secondary)
        SectionBox(title: model.text("Try scrolling here")) {
            ScrollView { VStack(alignment: .leading, spacing: 18) { ForEach(1...35, id: \.self) { i in Text("\(i). " + model.text("A smooth scroll keeps your place.")).frame(maxWidth: .infinity, alignment: .leading) } }.padding() }.frame(height: 170)
        }
    }
    private func slider(_ name: String, key: WritableKeyPath<ScrollSettings,Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
        HStack { Text(model.text(name)).frame(width: 115, alignment: .leading); Slider(value: Binding(get: { settings[keyPath: key] }, set: { v in edit { $0[keyPath: key] = v } }), in: range, step: 0.05); Text(settings[keyPath: key], format: .number.precision(.fractionLength(2))).monospacedDigit().frame(width: 48) }
        Text(model.text(name == "Speed" ? "Higher values move the page farther with each wheel step." : "Higher values scroll farther when you turn the wheel quickly. Zero keeps the speed consistent.")).font(.caption).foregroundStyle(.secondary)
        }
    }
}
struct ProfilesPage: View {
    @ObservedObject var model: AppModel
    var body: some View {
        Text(model.text("Choose an app above, then change only the actions it needs.")).font(.headline)
        if !model.isGlobal {
            SectionBox(title: model.effectiveProfile.name) {
                ProfileIdentityEditor(model: model, profile: model.effectiveProfile).id(model.effectiveProfile.id)
                Toggle(model.text("Pause this profile"), isOn: Binding(get: { model.effectiveProfile.paused }, set: { v in model.mutateProfile { $0.paused = v } }))
            }
        }
        SectionBox(title: model.text("Actions for the selected app")) {
            Text(model.editingScopeName)
            let profiles = (model.isGlobal ? [] : [model.effectiveProfile]) + [model.configuration.globalDefaults]
            let triggers = ProfileResolver.displayTriggers(in: profiles)
            ForEach(triggers, id: \.self) { trigger in
                if let r = ProfileResolver.resolve(trigger: trigger, bundleID: model.isGlobal ? nil : model.effectiveProfile.bundleID, deviceID: nil, profiles: profiles) {
                    HStack { Text(triggerLabel(trigger, model: model)); Spacer(); Text(model.text(r.mapping.enabled ? "action." + r.mapping.action.rawValue : "Disabled")); Text(r.source == model.configuration.globalDefaults.name ? model.text("All apps") : r.source).font(.caption).foregroundStyle(.secondary) }
                }
            }
        }
        Text(model.text("Mouse-specific settings are not available yet. Use All apps or an app profile.")).foregroundStyle(.secondary)
        HStack { Button(model.text("Export settings")) { model.exportConfiguration() }; Button(model.text("Import settings")) { model.chooseImport() } }
    }
}
struct TuningPage: View {
    @ObservedObject var model: AppModel
    @State private var advancedButtons = false
    var body: some View {
        SectionBox(title: model.text("Button feel")) {
            Picker(model.text("Response"), selection: Binding(get: { ButtonFeelPreset.matching(model.configuration.tuning) }, set: { preset in if preset == .custom { advancedButtons = true } else { model.update { $0.tuning = preset.applying(to: $0.tuning) } } })) { ForEach(ButtonFeelPreset.allCases, id: \.self) { Text(model.text($0.rawValue)).tag($0) } }.pickerStyle(.segmented).modifier(PointingHandCursor())
            Text(model.text("Choose a comfortable response first. Adjust individual values only if needed.")).font(.caption).foregroundStyle(.secondary)
            DisclosureGroup(model.text("Fine-tune buttons"), isExpanded: $advancedButtons) {
            VStack(alignment: .leading, spacing: 12) {
            tuningSlider("Hold delay", \.holdDelay, 0.15...1.5)
            tuningSlider("Multi-tap interval", \.multiTapInterval, 0.1...0.8)
            tuningSlider("Button drag distance", \.dragDistance, 5...200)
            Button(model.text("Reset tuning")) { model.update { $0.tuning = Tuning() } }
            }.padding(.top, 10)
            }
        }
        if model.devices.contains(where: { $0.magicMouse }) {
            DisclosureGroup(model.text("Advanced touch settings")) {
                VStack(alignment: .leading, spacing: 14) {
                    tuningSlider("Tap duration", \.tapDuration, 0.05...0.6)
                    tuningSlider("Tap movement", \.tapMovement, 0.005...0.2)
                    tuningSlider("Swipe distance", \.swipeDistance, 0.04...0.6)
                    tuningSlider("Pinch distance", \.pinchDistance, 0.02...0.5)
                    tuningSlider("Edge margin", \.edgeMargin, 0...0.2)
                    tuningSlider("Right zone", \.rightZone, 0.3...0.8)
                    tuningSlider("Contact area", \.contactArea, 0...5)
                    tuningSlider("Resting delay", \.restingDelay, 0.3...3)
                    Text(model.text("Contact area is capacitive size, not measured pressure.")).font(.caption)
                    Text(model.text("Distance values use normalized touch coordinates; button drag distance uses screen points.")).font(.caption)
                }.padding(.top, 12)
            }
        }
    }
    private func tuningSlider(_ label: String, _ key: WritableKeyPath<Tuning,Double>, _ range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
        HStack { Text(model.text(label)).frame(width: 155, alignment: .leading); Slider(value: Binding(get: { model.configuration.tuning[keyPath: key] }, set: { v in model.update { $0.tuning[keyPath: key] = v } }), in: range); Text(model.configuration.tuning[keyPath: key], format: .number.precision(.fractionLength(3))).monospacedDigit().frame(width: 55) }
        if label == "Hold delay" { Text(model.text("Seconds to hold a button before its long-press action runs. Lower means faster.")).font(.caption).foregroundStyle(.secondary) }
        if label == "Multi-tap interval" { Text(model.text("Seconds allowed between clicks for a double or triple click. Increase if you click slowly.")).font(.caption).foregroundStyle(.secondary) }
        if label == "Button drag distance" { Text(model.text("Distance to move while holding a button before a drag action starts. Increase to avoid accidental drags.")).font(.caption).foregroundStyle(.secondary) }
        }
    }
}
struct DiagnosticsPage: View {
    @ObservedObject var model: AppModel
    @State private var testAction: MouseAction = .middleClick
    @State private var confirmRun = false
    @State private var technicalExpanded: Bool
    init(model: AppModel, initiallyExpanded: Bool = false) {
        self.model = model; _technicalExpanded = State(initialValue: initiallyExpanded)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(model.text("If your mouse actions do not work, check these permissions and reopen GlideMouse.")).fixedSize(horizontal: false, vertical: true)
            SectionBox(title: model.text("Mouse control")) {
                LabeledContent(model.text("Status"), value: model.text(model.runtimeReport.status))
                PermissionControls(model: model)
            }
            DisclosureGroup(model.text("Technical details"), isExpanded: $technicalExpanded) {
                VStack(alignment: .leading, spacing: 18) {
                    SectionBox(title: model.text("Engine health")) {
                        LabeledContent(model.text("Observed events"), value: "\(model.runtimeReport.events)")
                        LabeledContent(model.text("Own events ignored"), value: "\(model.runtimeReport.injectedIgnored)")
                        LabeledContent(model.text("Tap timeouts"), value: "\(model.runtimeReport.timeouts)")
                        LabeledContent(model.text("Maximum callback"), value: String(format: "%.3f ms", model.runtimeReport.maximumCallbackMS))
                        Text(model.text(model.runtimeReport.touchStatus)).foregroundStyle(.secondary)
                    }
                    SectionBox(title: model.text("Test an action")) {
                        EasyPicker(label: model.text("Action"), selection: $testAction, values: MouseAction.allCases.filter { !$0.requiresTarget && $0 != .smartZoom && $0 != .canvasPan }) { model.text("action." + $0.rawValue) }
                        HStack { Button(model.text("Run action")) { confirmRun = true }.disabled(!model.accessibility); Button(model.text("Learn button")) { model.learnButton() }; Button(model.text("Stop learning")) { model.stopLearning() } }
                        Text(model.text("Run action performs the selected action on this Mac.")).font(.caption).foregroundStyle(.secondary)
                    }
                    HStack { Button(model.text("Clear")) { model.clearDiagnostics() }; Button(model.text("Export diagnostics")) { model.exportDiagnostics() } }
                    Text(model.text("Export includes engine counters, mouse names and recent input types. It excludes typed text, screenshots, device serials and command contents.")).font(.caption).foregroundStyle(.secondary)
                    ForEach(model.runtimeReport.records.reversed()) { r in HStack { Text(model.text(r.kind)); Text(model.diagnosticDetail(r.detail)).foregroundStyle(.secondary); Spacer(); if let a = r.action { Text(model.text("action." + a)) }; if let s = r.source { Text(s == model.configuration.globalDefaults.name ? model.text("All apps") : s).font(.caption).foregroundStyle(.secondary) } }.font(.caption) }
                }.padding(.top, 12)
            }
        }
        .confirmationDialog(model.text("Run this action now?"), isPresented: $confirmRun, titleVisibility: .visible) {
            Button(model.text("Run action")) { model.runTest(Mapping(trigger: .init(), action: testAction)) }
            Button(model.text("Cancel"), role: .cancel) {}
        }
    }
}
struct TroubleshootingSheet: View {
    @ObservedObject var model: AppModel
    var initiallyExpanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(model.text("Troubleshooting")).font(.title2.bold())
                Spacer()
                Button(model.text("Done")) { model.stopLearning(); model.showTroubleshooting = false }.keyboardShortcut(.cancelAction)
            }
            ScrollView {
                DiagnosticsPage(model: model, initiallyExpanded: initiallyExpanded).padding(.trailing, 4)
            }
        }.padding(22).frame(width: 640, height: 560)
            .buttonStyle(PointingButtonStyle())
            .disclosureGroupStyle(ClickableDisclosureStyle(model: model))
            .onDisappear { model.stopLearning() }
    }
}
struct GeneralPage: View {
    @ObservedObject var model: AppModel
    @State private var reset = false
    var body: some View {
        SectionBox(title: model.text("Mouse setup")) {
            Button(model.text("Set up your mouse")) { model.showMouseSetup = true }
            Button(model.text("Identify buttons")) { model.showCalibration = true }
            if model.accessibility && model.inputMonitoring { Label(model.text("Mouse control is allowed"), systemImage: "checkmark.shield").foregroundStyle(.secondary) }
            else { PermissionControls(model: model) }
        }
        SectionBox(title: model.text("Preferences")) {
            Picker(model.text("Language"), selection: Binding(get: { model.configuration.language }, set: { v in model.update { $0.language = v } })) { ForEach(AppLanguage.allCases, id: \.self) { Text($0.nativeName).tag($0) } }.pickerStyle(.segmented).modifier(PointingHandCursor())
            Picker(model.text("Appearance"), selection: Binding(get: { model.configuration.appearance }, set: { v in model.update { $0.appearance = v } })) { ForEach(AppAppearance.allCases, id: \.self) { Text(model.text($0.rawValue)).tag($0) } }.pickerStyle(.segmented).modifier(PointingHandCursor())
            Toggle(model.text("Launch at login"), isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) }))
            Toggle(model.text("Show action name on screen"), isOn: Binding(get: { model.configuration.showFeedback }, set: { v in model.update { $0.showFeedback = v } }))
        }
        UpdatePreferences(model: model, updater: model.updater)
        AboutGlideMouse(model: model)
        SectionBox(title: model.text("Your settings")) {
            Text(model.text("Back up or transfer your mouse settings.")).font(.caption).foregroundStyle(.secondary)
            HStack { Button(model.text("Export settings")) { model.exportConfiguration() }; Button(model.text("Import settings")) { model.chooseImport() }; Button(model.text("Restore defaults"), role: .destructive) { reset = true } }
        }.confirmationDialog(model.text("Restore all defaults?"), isPresented: $reset, titleVisibility: .visible) {
            Button(model.text("Restore defaults"), role: .destructive) { model.update { $0 = Configuration() }; model.selectedProfileID = nil }
            Button(model.text("Cancel"), role: .cancel) {}
        }
    }
}

struct AboutGlideMouse: View {
    @ObservedObject var model: AppModel
    @Environment(\.openURL) private var openURL
    var body: some View {
        SectionBox(title: model.text("About GlideMouse")) {
            HStack(alignment: .center, spacing: 16) {
                if let icon = AppResources.bundle.url(forResource: "AppIcon", withExtension: "png").flatMap({ NSImage(contentsOf: $0) }) {
                    Image(nsImage: icon).resizable().scaledToFit().frame(width: 64, height: 64).accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("GlideMouse").font(.title3.bold())
                    Text(String(format: model.text("Developed by %@"), AppResources.developerName)).fixedSize(horizontal: false, vertical: true)
                    Text(String(format: model.text("Version %@"), AppResources.version)).font(.caption).foregroundStyle(.secondary)
                }
            }
            if let url = AppResources.supportURL {
                Text(model.text("Enjoy using GlideMouse? Support its development or get in touch.")).font(.callout).fixedSize(horizontal: false, vertical: true)
                Button { openURL(url) } label: { Label("Buy Me a Coffee", systemImage: "cup.and.saucer.fill").frame(maxWidth: .infinity) }
                    .buttonStyle(PointingButtonStyle(prominent: true)).help(url.absoluteString)
            }
            Divider()
            Text(model.text("Questions or feedback? Get in touch.")).font(.callout).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                if let url = AppResources.emailURL { contactButton(model.text("Email"), symbol: "envelope", url: url) }
                if let url = AppResources.websiteURL { contactButton(model.text("Website"), symbol: "globe", url: url) }
            }
        }.buttonStyle(PointingButtonStyle())
    }
    private func contactButton(_ title: String, symbol: String, url: URL) -> some View {
        Button { openURL(url) } label: { Label(title, systemImage: symbol).frame(maxWidth: .infinity) }.help(url.absoluteString)
    }
}

private struct ProfileIdentityEditor: View {
    @ObservedObject var model: AppModel
    @State private var name: String
    @State private var bundleID: String
    @State private var deviceID: String
    init(model: AppModel, profile: Profile) {
        self.model = model
        _name = State(initialValue: profile.name)
        _bundleID = State(initialValue: profile.bundleID ?? "")
        _deviceID = State(initialValue: profile.deviceID ?? "")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(model.text("Name"), text: $name)
            DisclosureGroup(model.text("Technical details")) {
                TextField(model.text("Bundle identifier"), text: $bundleID)
                TextField(model.text("Device identifier"), text: $deviceID)
            }
            Button(model.text("Save profile")) {
                model.mutateProfile { p in p.name = name; p.bundleID = bundleID.isEmpty ? nil : bundleID; p.deviceID = deviceID.isEmpty ? nil : deviceID }
            }
        }
    }
}

private struct UpdatePreferences: View {
    @ObservedObject var model: AppModel
    @ObservedObject var updater: UpdateController
    var body: some View {
        SectionBox(title: model.text("Updates")) {
            if !updater.configured { Text(model.text("The update server has not been connected yet.")) }
            Toggle(model.text("Check automatically"), isOn: Binding(get: { model.configuration.automaticUpdates }, set: { enabled in model.update { $0.automaticUpdates = enabled } })).disabled(!updater.configured)
            Toggle(model.text("Download and install updates automatically"), isOn: Binding(get: { updater.automaticallyDownloads }, set: { updater.setAutomaticDownloads($0) })).disabled(!updater.configured || !model.configuration.automaticUpdates)
            Text(model.text("Automatic updates install signed releases when the app can safely restart. Your mouse settings are retained.")).font(.caption).foregroundStyle(.secondary)
            Button(model.text("Check for updates")) { updater.check() }.disabled(!updater.canCheck)
        }
    }
}
