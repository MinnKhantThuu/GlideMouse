import SwiftUI
import AppKit
import MouseCore

enum SettingsPage: String, CaseIterable, Identifiable {
    case welcome = "Welcome", devices = "Devices", mappings = "Gestures & buttons", scrolling = "Scrolling", profiles = "Profiles", tuning = "Tuning", general = "General"
    var id: String { rawValue }
    var symbol: String {
        switch self { case .welcome: "sparkles"; case .devices: "computermouse"; case .mappings: "hand.tap"; case .scrolling: "arrow.up.arrow.down"; case .profiles: "square.stack"; case .tuning: "slider.horizontal.3"; case .general: "gearshape" }
    }
}
struct SettingsRoot: View {
    @ObservedObject var model: AppModel
    @State private var page: SettingsPage
    @State private var hoveredPage: SettingsPage?
    @State private var advancedExpanded: Bool
    init(model: AppModel, initialPage: SettingsPage = .mappings) {
        self.model = model; _page = State(initialValue: initialPage)
        _advancedExpanded = State(initialValue: ![.mappings, .scrolling, .general].contains(initialPage))
    }
    private func title(_ page: SettingsPage) -> String { model.text(page == .mappings ? "Buttons" : page == .general ? "Settings" : page == .profiles ? "App-specific settings" : page.rawValue) }
    private func navigation(_ target: SettingsPage) -> some View {
        Button { page = target } label: {
            Label(title(target), systemImage: target.symbol).frame(maxWidth: .infinity, alignment: .leading).padding(11)
                .background(page == target ? Color.accentColor.opacity(0.16) : hoveredPage == target ? Color.primary.opacity(0.05) : Color.clear, in: RoundedRectangle(cornerRadius: 9)).contentShape(Rectangle())
        }.buttonStyle(.plain).modifier(PointingHandCursor()).onHover { hoveredPage = $0 ? target : nil }
            .accessibilityAddTraits(page == target ? .isSelected : [])
    }
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                Text("GlideMouse").font(.title3.bold()).padding(.horizontal, 11).padding(.vertical, 18)
                ForEach([SettingsPage.mappings, .scrolling, .general]) { navigation($0) }
                Divider().padding(.vertical, 10)
                Button { withAnimation { advancedExpanded.toggle() } } label: {
                    HStack { Label(model.text("Advanced"), systemImage: "slider.horizontal.3"); Spacer(); Image(systemName: advancedExpanded ? "chevron.down" : "chevron.right") }.padding(11).contentShape(Rectangle())
                }.buttonStyle(.plain).modifier(PointingHandCursor()).accessibilityValue(model.text(advancedExpanded ? "Expanded" : "Collapsed"))
                if advancedExpanded { ForEach([SettingsPage.profiles, .tuning, .devices]) { navigation($0) } }
                Spacer()
                Button { model.showMouseSetup = true } label: { Label(model.text("Mouse setup"), systemImage: "questionmark.circle").frame(maxWidth: .infinity, alignment: .leading).padding(11).contentShape(Rectangle()) }.buttonStyle(.plain).modifier(PointingHandCursor())
                HStack { Circle().fill(model.runtimeReport.active ? Color.green : Color.secondary).frame(width: 7,height: 7); Text(model.text(model.runtimeReport.active ? "Ready" : "Paused")).font(.caption); Spacer() }.padding(11)
            }.padding(10).frame(width: 185).background(Color(nsColor: .controlBackgroundColor))
            Divider()
            VStack(spacing: 0) {
                HStack {
                    Text(title(page)).font(.title2.bold()); Spacer()
                    Button(model.text("Undo")) { model.undo() }.disabled(!model.canUndo)
                    Toggle(model.text("Enable"), isOn: Binding(get: { model.configuration.engineEnabled }, set: { v in model.update { $0.engineEnabled = v } })).toggleStyle(.switch).modifier(PointingHandCursor())
                }.padding(22)
                Divider()
                if [.mappings, .scrolling, .profiles].contains(page) {
                    AppScopeBar(model: model, scrolling: page == .scrolling).padding(.horizontal, 22).padding(.vertical, 10)
                    Divider()
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: page == .mappings ? 12 : 22) {
                        switch page {
                        case .welcome: WelcomePage(model: model)
                        case .devices: DevicesPage(model: model)
                        case .mappings: SimpleMousePage(model: model)
                        case .scrolling: ScrollingPage(model: model)
                        case .profiles: ProfilesPage(model: model)
                        case .tuning: TuningPage(model: model)
                        case .general: GeneralPage(model: model)
                        }
                    }.padding(.horizontal, 22).padding(.vertical, page == .mappings ? 12 : 22).frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider()
                HStack {
                    Text(model.userFacingMessage.isEmpty ? model.text("Emergency pause: ⌃⌥⌘ Esc") : model.userFacingMessage).lineLimit(2)
                    Spacer(); Text("v" + AppResources.version).foregroundStyle(.secondary)
                }.font(.caption).padding(12)
            }
        }.background(Color(nsColor: .windowBackgroundColor)).controlSize(.large)
        .environment(\.locale, Locale(identifier: model.configuration.language.resourceIdentifier))
        .alert(model.text("Could not save or run"), isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) { Button(model.text("OK")) { model.errorMessage = nil } } message: { Text(model.errorMessage ?? "") }
        .sheet(isPresented: Binding(get: { model.pendingPreset != nil }, set: { if !$0 { model.pendingPreset = nil } })) { if let kind = model.pendingPreset { PresetReview(model: model, kind: kind) } }
        .sheet(item: $model.pendingMapping) { MappingEditor(model: model, mapping: $0) }
        .sheet(isPresented: Binding(get: { model.importPreview != nil }, set: { if !$0 { model.importPreview = nil } })) { ImportReview(model: model) }
        .sheet(isPresented: $model.showCalibration) { CalibrationSheet(model: model) }
        .sheet(isPresented: $model.showMouseSetup) { MouseSetupWizard(model: model) }
        .sheet(isPresented: $model.showTroubleshooting) { TroubleshootingSheet(model: model) }
        .onAppear {
            if !model.isTesting && model.configuration.globalDefaults.mappings.isEmpty && model.configuration.usability?.setupCompleted != true { model.showMouseSetup = true }
        }
        .buttonStyle(PointingButtonStyle())
        .disclosureGroupStyle(ClickableDisclosureStyle(model: model))
    }
}
struct SectionBox<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View { GroupBox { VStack(alignment: .leading, spacing: 14) { content }.padding(12).frame(maxWidth: .infinity, alignment: .leading) } label: { Text(title).font(.headline) } }
}
struct WelcomePage: View {
    @ObservedObject var model: AppModel
    var body: some View {
        HStack(spacing: 22) {
            if let url = AppResources.bundle.url(forResource: "AppIcon", withExtension: "png"), let image = NSImage(contentsOf: url) { Image(nsImage: image).resizable().frame(width: 100, height: 100).accessibilityHidden(true) }
            VStack(alignment: .leading, spacing: 8) { Text("GlideMouse").font(.largeTitle.bold()); Text(model.text("Make your mouse feel at home.")).font(.title3).foregroundStyle(.secondary) }
        }
        Text(model.text("Smooth scrolling, useful buttons, and gestures for your mouse. Everything stays on this Mac."))
        SectionBox(title: model.text("Get started")) {
            Label(model.devices.isEmpty ? model.text("Connect a mouse") : model.text("Input devices connected"), systemImage: model.devices.isEmpty ? "computermouse" : "checkmark.circle")
            PermissionControls(model: model)
            HStack {
                Button(model.text("3-button preset")) { model.pendingPreset = "three" }
                Button(model.text("5-button preset")) { model.pendingPreset = "five" }
                if model.devices.contains(where: { $0.magicMouse }) { Button(model.text("Magic Mouse preset")) { model.pendingPreset = "magic" } }
            }
            Text(model.text("Presets replace mappings in the selected profile. Undo restores the previous settings.")).font(.caption).foregroundStyle(.secondary)
        }
        GestureTutorial(model: model)
        DisclosureGroup(model.text("Mouse compatibility")) {
            VStack(alignment: .leading, spacing: 10) {
                Text(model.text("Use your mouse buttons and wheel to create mappings."))
                Text(model.text("Some trackpad-style gestures are not available yet."))
                Text(model.text("Magic Mouse gestures are still being tested."))
                Text(model.text("Left and right physical clicks always keep working."))
            }.padding(.top, 8)
        }
        if model.dirtyRecovery { Text(model.text("Settings recovery needed. Existing files are preserved; review before saving changes.")).foregroundStyle(.orange) }
    }
}
struct PermissionControls: View {
    @ObservedObject var model: AppModel
    var body: some View {
        HStack { Label(model.text(model.accessibility ? "Accessibility granted" : "Accessibility needed"), systemImage: model.accessibility ? "checkmark.shield" : "exclamationmark.shield"); Spacer(); Button(model.text("Open Accessibility")) { model.permission("accessibility") } }
        HStack { Label(model.text(model.inputMonitoring ? "Input Monitoring granted" : "Input Monitoring needed"), systemImage: model.inputMonitoring ? "checkmark.shield" : "exclamationmark.shield"); Spacer(); Button(model.text("Open Input Monitoring")) { model.permission("input") } }
        Text(model.text("Accessibility lets GlideMouse perform the actions you choose, such as switching desktops. Input Monitoring lets it recognize mouse buttons and wheel input. It does not save what you type.")).font(.caption).foregroundStyle(.secondary)
        Text(model.text("After allowing access in System Settings, refresh. If access is still unavailable, quit and reopen GlideMouse.")).font(.caption).foregroundStyle(.secondary)
        Button(model.text("Refresh")) { model.refresh() }
    }
}
struct DevicesPage: View {
    @ObservedObject var model: AppModel
    var body: some View {
        PermissionControls(model: model)
        if !model.competingUtilities.isEmpty {
            Label(model.text("Another mouse utility is running. Test with one active utility at a time."), systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
            Text(model.competingUtilities.joined(separator: ", ")).font(.caption)
        }
        if model.devices.isEmpty { ContentUnavailableView(model.text("No mouse connected"), systemImage: "computermouse", description: Text(model.text("Connect a USB or Bluetooth mouse, then refresh."))) }
        ForEach(model.devices) { d in
            SectionBox(title: d.name) {
                HStack {
                    MouseDiagram(model: model, contacts: [], magic: d.magicMouse).frame(width: 150, height: 170)
                    VStack(alignment: .leading, spacing: 10) {
                        Text(d.transport).foregroundStyle(.secondary)
                        Text(model.text(d.magicMouse ? "Magic Mouse" : "Mouse buttons and wheel"))
                        DisclosureGroup(model.text("Technical details")) {
                            Text(model.text("Standard buttons") + ": \(d.buttons)")
                            Text(model.text(d.stableIdentity ? "Stable identity available" : "Session identity only"))
                            Text(model.text(d.magicMouse ? "Touch adapter: experimental" : "Touch surface: unavailable"))
                        }
                    }
                }
            }
        }
        Text(model.text("Mouse-specific settings are not available yet. Use All apps or an app profile.")).foregroundStyle(.secondary)
    }
}
struct MouseDiagram: View {
    @ObservedObject var model: AppModel
    var contacts: [TouchPoint]
    var magic = true
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                RoundedRectangle(cornerRadius: w * 0.42).fill(.regularMaterial).overlay(RoundedRectangle(cornerRadius: w * 0.42).stroke(.secondary.opacity(0.4), lineWidth: 1)).padding(.horizontal, w * 0.18)
                if !magic { Path { p in p.move(to: CGPoint(x: w/2, y: 4)); p.addLine(to: CGPoint(x: w/2, y: h * 0.35)) }.stroke(.secondary.opacity(0.5), lineWidth: 1); Capsule().fill(.secondary).frame(width: 12, height: 28).offset(y: -h*0.3) }
                ForEach(contacts, id: \.id) { t in Circle().fill(Color.accentColor).frame(width: 18, height: 18).position(x: w*0.18 + t.x*w*0.64, y: (1-t.y)*h).accessibilityLabel(model.text("Touch") + " \(t.id)") }
            }
        }.accessibilityLabel(model.text("Mouse touch surface"))
    }
}
struct AppScopeBar: View {
    @ObservedObject var model: AppModel
    var scrolling = false
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 10) {
                EasyDropdown(title: String(format: model.text("Editing for: %@"), model.editingScopeName)) { close in
                    DropdownOption(title: model.text("All apps — default actions")) { model.selectedProfileID = nil; close() }
                    ForEach(model.configuration.profiles.filter { $0.bundleID != nil && $0.deviceID == nil }) { profile in
                        DropdownOption(title: profile.name + (model.selectedProfileID == profile.id ? "  ✓" : "")) { model.selectedProfileID = profile.id; close() }
                    }
                }.accessibilityLabel(model.text("Editing scope")).accessibilityValue(model.editingScopeName)
                Button { model.addAppProfile() } label: { Label(model.text("Add app"), systemImage: "plus") }
                if !model.isGlobal {
                    Button(role: .destructive) { model.removeProfile() } label: {
                        Label(model.text("Remove app"), systemImage: "minus.circle")
                    }
                    .accessibilityLabel(String(format: model.text("Remove %@ from GlideMouse"), model.editingScopeName))
                    .help(model.text("Removes this app's mouse settings from GlideMouse. The app itself stays installed. Undo restores the setup."))
                }
            }
            Text(model.isGlobal ? model.text(scrolling ? "Default scrolling for all apps. Each app can have its own changes." : "Default actions for all apps. Each app can have its own changes.") : String(format: model.text(scrolling ? "Scrolling changes apply only while using %@. Other apps keep their own settings." : "Changes apply only while using %@."), model.editingScopeName))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if !model.isGlobal && model.effectiveProfile.paused { Label(model.text("Mouse changes are paused in this app."), systemImage: "pause.circle").font(.caption).foregroundStyle(.orange) }
        }
    }
}
struct MappingsPage: View {
    @ObservedObject var model: AppModel
    var body: some View { SimpleMousePage(model: model) }
}
@MainActor func triggerLabel(_ t: Trigger, model: AppModel) -> String {
    var suffix: [String] = []
    if t.modifiers.contains(.control) { suffix.append("⌃") }; if t.modifiers.contains(.option) { suffix.append("⌥") }; if t.modifiers.contains(.shift) { suffix.append("⇧") }; if t.modifiers.contains(.command) { suffix.append("⌘") }
    switch t.kind {
    case .button:
        let key = t.clicks == 2 ? "Double-click button %d" : t.clicks == 3 ? "Triple-click button %d" : "Click button %d once"
        suffix.append(String(format: model.text(key), t.button + 1))
    case .buttonHold: suffix.append(String(format: model.text("Hold button %d"), t.button + 1))
    case .buttonDrag:
        let key: String = switch t.direction {
        case .left: "Hold button %d and move the mouse left"
        case .right: "Hold button %d and move the mouse right"
        case .up: "Hold button %d and move the mouse up"
        case .down: "Hold button %d and move the mouse down"
        }
        suffix.append(String(format: model.text(key), t.button + 1))
    case .buttonWheel:
        let key: String = switch t.direction {
        case .left: "Hold button %d and scroll the wheel left"
        case .right: "Hold button %d and scroll the wheel right"
        case .up: "Hold button %d and scroll the wheel up"
        case .down: "Hold button %d and scroll the wheel down"
        }
        suffix.append(String(format: model.text(key), t.button + 1))
    case .buttonChord: suffix.append(String(format: model.text("Hold button %d and press button %d"), t.button + 1, t.chordButton + 1))
    case .tap, .rightTap: suffix.append("\(t.fingers) " + model.text("finger tap") + " · \(t.clicks)×" + (t.kind == .rightTap ? " · " + model.text("Right zone") : ""))
    case .swipe: suffix.append("\(t.fingers) " + model.text("finger swipe") + " " + model.text(t.direction.rawValue))
    case .pinchIn: suffix.append(model.text("Pinch in"))
    case .pinchOut: suffix.append(model.text("Spread"))
    case .touchHold: suffix.append(model.text("Tap then hold"))
    }
    return suffix.joined(separator: " ")
}

struct GestureTutorial: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0
    var body: some View {
        DisclosureGroup(model.text("Input guide")) {
            HStack(spacing: 22) {
                ZStack {
                    RoundedRectangle(cornerRadius: 42).stroke(Color.secondary, lineWidth: 2).frame(width: 90,height: 130)
                    if step == 0 {
                        Circle().fill(Color.accentColor.opacity(0.25)).frame(width: 28,height: 28).offset(x: -20,y: -38)
                        Circle().fill(Color.accentColor).frame(width: 10,height: 10).offset(x: -20,y: -38)
                    } else if step == 1 {
                        Image(systemName: "arrow.up.arrow.down").foregroundStyle(Color.accentColor).font(.title2).offset(y: -20)
                    } else {
                        Circle().stroke(Color.accentColor,lineWidth: 2).frame(width: 26,height: 26).offset(x: -18,y: -30)
                        Image(systemName: "hand.tap").foregroundStyle(Color.accentColor).offset(x: -18,y: -30)
                    }
                }.frame(width: 120,height: 145).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 12) {
                    Text(model.text(["Button guide","Wheel guide","Touch guide"][step]))
                    HStack {
                        ForEach(0..<3) { index in
                            Button(model.text(["Buttons","Scrolling","Touch"][index])) {
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { step = index }
                            }
                        }
                    }
                }
            }.padding(.vertical, 12)
        }
    }
}

struct PointingHandCursor: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 15, *) {
            content.pointerStyle(isEnabled ? .link : .default)
        } else {
            content.background(LegacyPointingCursor(enabled: isEnabled))
        }
    }
}

/// Transparent AppKit cursor region for macOS 14. It never receives clicks.
private struct LegacyPointingCursor: NSViewRepresentable {
    let enabled: Bool
    final class CursorView: NSView {
        var enabled = true
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func resetCursorRects() {
            super.resetCursorRects()
            if enabled { addCursorRect(visibleRect.intersection(bounds), cursor: .pointingHand) }
        }
        override func layout() { super.layout(); window?.invalidateCursorRects(for: self) }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); window?.invalidateCursorRects(for: self) }
    }
    func makeNSView(context: Context) -> CursorView { CursorView() }
    func updateNSView(_ view: CursorView, context: Context) { view.enabled = enabled; view.window?.invalidateCursorRects(for: view) }
}

/// Shared dimensions and states keep ordinary actions consistent across pages.
struct PointingButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var enabled
    @State private var hovered = false
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        let destructive = configuration.role == .destructive
        let tint: Color = destructive ? .red : .accentColor
        return configuration.label
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14).padding(.vertical, 6).frame(minHeight: 40)
            .foregroundStyle(prominent ? Color.white : destructive ? Color.red : Color.primary)
            .background(prominent ? tint : Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9))
            .overlay { RoundedRectangle(cornerRadius: 9).fill(tint.opacity(configuration.isPressed ? 0.18 : hovered ? 0.09 : 0)) }
            .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(prominent ? tint : hovered ? tint.opacity(0.65) : Color.primary.opacity(0.24), lineWidth: 1) }
            .opacity(enabled ? 1 : 0.42).contentShape(RoundedRectangle(cornerRadius: 9))
            .modifier(PointingHandCursor()).onHover { hovered = enabled && $0 }
    }
}

/// Custom dropdowns and picture labels retain their layout but share visible states.
struct SurfaceButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    @State private var hovered = false
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .overlay { RoundedRectangle(cornerRadius: 9).fill(Color.accentColor.opacity(configuration.isPressed ? 0.18 : hovered ? 0.09 : 0)) }
            .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(hovered ? Color.accentColor.opacity(0.7) : Color.primary.opacity(0.24), lineWidth: 1) }
            .opacity(enabled ? 1 : 0.42).contentShape(RoundedRectangle(cornerRadius: 9))
            .modifier(PointingHandCursor()).onHover { hovered = enabled && $0 }
    }
}

struct ClickableDisclosureStyle: DisclosureGroupStyle {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: DisclosureGroupStyleConfiguration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) { configuration.isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: configuration.isExpanded ? "chevron.down" : "chevron.right").font(.caption)
                    configuration.label
                    Spacer(minLength: 0)
                }.padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: 40, alignment: .leading).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9)).contentShape(Rectangle())
            }.buttonStyle(SurfaceButtonStyle())
                .accessibilityValue(model.text(configuration.isExpanded ? "Expanded" : "Collapsed"))
            if configuration.isExpanded { configuration.content }
        }
    }
}
