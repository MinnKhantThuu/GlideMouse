import SwiftUI
import AppKit
@preconcurrency import ApplicationServices
import MouseCore

@main enum GlideMouseLauncher {
    @MainActor static func main() {
        if let i = CommandLine.arguments.firstIndex(of: "--render-mapping-list"), CommandLine.arguments.count > i + 1 {
            UIHarness.renderMappingList(to: URL(fileURLWithPath: CommandLine.arguments[i + 1])); exit(0)
        }
        if CommandLine.arguments.contains("--list-preview") || Bundle.main.object(forInfoDictionaryKey: "GMListPreview") as? Bool == true {
            NSApplication.shared.setActivationPolicy(.regular)
            MappingListPreview.main(); return
        }
        if let i = CommandLine.arguments.firstIndex(of: "--render-magic"), CommandLine.arguments.count > i + 1 {
            exit(UIHarness.magicReadiness(to: URL(fileURLWithPath: CommandLine.arguments[i + 1])) ? 0 : 1)
        }
        if CommandLine.arguments.contains("--magic-preview") || Bundle.main.object(forInfoDictionaryKey: "GMMagicPreview") as? Bool == true {
            NSApplication.shared.setActivationPolicy(.regular)
            MagicMouseSettingsPreview.main(); return
        }
        if CommandLine.arguments.contains("--guide-preview") || Bundle.main.object(forInfoDictionaryKey: "GMGuidePreview") as? Bool == true {
            NSApplication.shared.setActivationPolicy(.regular)
            MouseActionGuidePreview.main()
            return
        }
        if let index = CommandLine.arguments.firstIndex(of: "--render-tutorials"), CommandLine.arguments.count > index + 1 {
            UIHarness.renderTutorials(to: URL(fileURLWithPath: CommandLine.arguments[index + 1])); exit(0)
        }
        if CommandLine.arguments.contains("--probe") {
            struct Probe: Codable { var os: String; var accessibility: Bool; var inputMonitoring: Bool; var devices: [MouseDevice]; var touch: TouchProbe }
            let report = Probe(os: ProcessInfo.processInfo.operatingSystemVersionString, accessibility: AXIsProcessTrusted(), inputMonitoring: CGPreflightListenEventAccess(), devices: DeviceRegistry().enumerate(), touch: TouchProbe.run())
            let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted,.sortedKeys]; if let data = try? e.encode(report) { print(String(decoding: data, as: UTF8.self)) }; exit(0)
        }
        if let index = CommandLine.arguments.firstIndex(of: "--check-localization"), CommandLine.arguments.count > index + 1 {
            exit(UIHarness.checkLocalization(to: URL(fileURLWithPath: CommandLine.arguments[index + 1])) ? 0 : 1)
        }
        if let index = CommandLine.arguments.firstIndex(of: "--render-localization"), CommandLine.arguments.count > index + 1 {
            let directory = URL(fileURLWithPath: CommandLine.arguments[index + 1])
            UIHarness.render(to: directory); UIHarness.renderTroubleshooting(to: directory); UIHarness.renderLocalizedSheets(to: directory); exit(0)
        }
        if let index = CommandLine.arguments.firstIndex(of: "--render-troubleshooting"), CommandLine.arguments.count > index + 1 {
            UIHarness.renderTroubleshooting(to: URL(fileURLWithPath: CommandLine.arguments[index + 1])); exit(0)
        }
        if let index = CommandLine.arguments.firstIndex(of: "--render-app-removal"), CommandLine.arguments.count > index + 1 {
            UIHarness.renderAppRemoval(to: URL(fileURLWithPath: CommandLine.arguments[index + 1])); exit(0)
        }
        if let index = CommandLine.arguments.firstIndex(of: "--render-responsive-buttons"), CommandLine.arguments.count > index + 1 {
            UIHarness.renderResponsiveButtons(to: URL(fileURLWithPath: CommandLine.arguments[index + 1])); exit(0)
        }
        if let index = CommandLine.arguments.firstIndex(of: "--render-profile-list"), CommandLine.arguments.count > index + 1 {
            UIHarness.renderProfileList(to: URL(fileURLWithPath: CommandLine.arguments[index + 1])); exit(0)
        }
        if let index = CommandLine.arguments.firstIndex(of: "--render-ui"), CommandLine.arguments.count > index + 1 {
            UIHarness.render(to: URL(fileURLWithPath: CommandLine.arguments[index + 1])); exit(0)
        }
        if CommandLine.arguments.contains("--test-space-right") || CommandLine.arguments.contains("--test-space-left") {
            let app = NSApplication.shared; app.finishLaunching()
            let executor = ActionExecutor()
            executor.report = { print($0) }
            executor.execute(Mapping(button: 3, action: CommandLine.arguments.contains("--test-space-right") ? .spaceRight : .spaceLeft))
            RunLoop.main.run(until: Date().addingTimeInterval(2)); exit(0)
        }
        if CommandLine.arguments.contains("--observe-hardware") { exit(HardwareObserver.run(seconds: 30)) }
        if CommandLine.arguments.contains("--hardware-calibration") { exit(IntegrationHarness.run(physical: true,calibration: true)) }
        if CommandLine.arguments.contains("--hardware-remap-test") { exit(IntegrationHarness.run(physical: true)) }
        if CommandLine.arguments.contains("--ux-self-test") { exit(UsabilityHarness.run()) }
        if CommandLine.arguments.contains("--primary-button-test") { exit(PrimaryButtonHarness.run()) }
        if CommandLine.arguments.contains("--integration-test") { exit(IntegrationHarness.run()) }
        if CommandLine.arguments.contains("--test-desktop-latency") { exit(DesktopLatencyHarness.run()) }
        if CommandLine.arguments.contains("--test-desktop-keyboard") { exit(DesktopKeyboardHarness.run()) }
        GlideMouseApp.main()
    }
}

struct GlideMouseApp: App {
    @StateObject private var model: AppModel
    init() {
        if CommandLine.arguments.contains("--ui-test") || CommandLine.arguments.contains("--ui-cursor-report") { NSApplication.shared.setActivationPolicy(.regular) }
        let instance = AppModel(testing: CommandLine.arguments.contains("--ui-test"))
        if instance.isTesting && CommandLine.arguments.contains("--ui-app-scope-test") {
            instance.configuration.globalDefaults.mappings = [Mapping(button: 3, action: .spaceLeft), Mapping(button: 4, action: .spaceRight)]
            instance.configuration.profiles = [Profile(name: "Microsoft PowerPoint", bundleID: "com.microsoft.Powerpoint")]
            instance.selectedButton = 3
        }
        _model = StateObject(wrappedValue: instance)
        if CommandLine.arguments.contains("--setup-mouse") {
            Task { @MainActor in try? await Task.sleep(for: .milliseconds(600)); instance.showMouseSetup = true }
        }
        if CommandLine.arguments.contains("--identify-buttons") {
            Task { @MainActor in try? await Task.sleep(for: .milliseconds(600)); instance.showCalibration = true }
        }
        if CommandLine.arguments.contains("--review-preset") {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                instance.pendingPreset = "five"
            }
        }
        if CommandLine.arguments.contains("--capture-input") {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                instance.pendingMapping = Mapping(trigger: .init(), action: .middleClick)
            }
        }
        if let index = CommandLine.arguments.firstIndex(of: "--runtime-report"), CommandLine.arguments.count > index + 1 {
            let url = URL(fileURLWithPath: CommandLine.arguments[index + 1])
            Task { @MainActor in
                while !Task.isCancelled { try? await Task.sleep(for: .seconds(1)); instance.writeRuntimeReport(to: url) }
            }
        }
        if let index = CommandLine.arguments.firstIndex(of: "--ui-cursor-report"), CommandLine.arguments.count > index + 1 {
            let url = URL(fileURLWithPath: CommandLine.arguments[index + 1])
            Task { @MainActor in
                while !Task.isCancelled { try? await Task.sleep(for: .milliseconds(200)); UIHarness.writeCursorReport(to: url) }
            }
        }
        if let index = CommandLine.arguments.firstIndex(of: "--launch-report"), CommandLine.arguments.count > index + 1 {
            let path = CommandLine.arguments[index + 1]
            Task { @MainActor in try? await Task.sleep(for: .seconds(1)); instance.writeLaunchReport(to: URL(fileURLWithPath: path)) }
        }
    }
    var body: some Scene {
        WindowGroup("GlideMouse", id: "settings") {
            SettingsRoot(model: model).frame(minWidth: 820, minHeight: 580).preferredColorScheme(model.colorScheme)
                .onAppear {
                    if CommandLine.arguments.contains("--ui-test") || CommandLine.arguments.contains("--ui-cursor-report") {
                        NSApplication.shared.setActivationPolicy(.regular)
                        NSApplication.shared.activate(ignoringOtherApps: true)
                    }
                }
        }.defaultSize(width: 1040, height: 730)
        .commands {
            CommandGroup(replacing: .undoRedo) { Button(model.text("Undo")) { model.undo() }.keyboardShortcut("z").disabled(!model.canUndo) }
            CommandGroup(replacing: .appTermination) { Button(model.text("Quit GlideMouse")) { model.quit() }.keyboardShortcut("q") }
            TroubleshootingCommands(model: model)
        }
        MenuBarExtra { MenuContent(model: model) } label: { StartupMenuLabel(model: model) }
    }
}
struct TroubleshootingCommands: Commands {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow
    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button(model.text("Troubleshooting")) {
                if let window = NSApplication.shared.windows.first(where: { $0.title == "GlideMouse" && $0.isVisible }) { window.makeKeyAndOrderFront(nil) }
                else { openWindow(id: "settings") }
                NSApplication.shared.activate(ignoringOtherApps: true)
                model.showTroubleshooting = true
            }
        }
    }
}
struct MenuContent: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Text(model.text(model.runtimeReport.status))
        Button(model.text(model.configuration.engineEnabled ? "Pause" : "Enable")) { model.update { $0.engineEnabled.toggle() } }
        Text(model.text("Emergency pause: ⌃⌥⌘ Esc"))
        Divider()
        ForEach(model.devices) { Text($0.name) }
        Button(model.text("Settings")) {
            if let window = NSApplication.shared.windows.first(where: { $0.title == "GlideMouse" && $0.isVisible }) { window.makeKeyAndOrderFront(nil) }
            else { openWindow(id: "settings") }
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        Divider()
        Button(model.text("Quit GlideMouse")) { model.quit() }
    }
}

private struct StartupMenuLabel: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @State private var presented = false
    var body: some View {
        Image(nsImage: MenuIcon.make(paused: !model.configuration.engineEnabled)).accessibilityLabel("GlideMouse")
            .task {
                guard !presented else { return }; presented = true
                try? await Task.sleep(for: .milliseconds(300))
                if !NSApplication.shared.windows.contains(where: { $0.title == "GlideMouse" && $0.isVisible }) { openWindow(id: "settings") }
            }
    }
}

struct MagicMouseSettingsPreview: App {
    @StateObject private var model = AppModel(testing: true, rendering: true)
    var body: some Scene {
        WindowGroup("GlideMouse — Magic Mouse preview") {
            SettingsRoot(model: model, initialPage: .magic).frame(minWidth: 820, minHeight: 580)
                .onAppear {
                    model.configuration.language = AppLanguage(rawValue: Bundle.main.object(forInfoDictionaryKey: "GMMagicPreviewLanguage") as? String ?? "en") ?? .en
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
        }.defaultSize(width: 1040, height: 780)
    }
}

/// Preview fixtures never create a second input engine or read personal settings.
struct MappingListPreview: App {
    @StateObject private var model = AppModel(testing: true, rendering: true)
    var body: some Scene {
        WindowGroup("GlideMouse — Settings preview") {
            SettingsRoot(model: model).frame(minWidth: 820, minHeight: 580)
                .onAppear {
                    UIHarness.configureMappingListFixture(model)
                    model.configuration.language = .my
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
        }.defaultSize(width: 1040, height: 760)
        .commands { CommandGroup(replacing: .undoRedo) { Button(model.text("Undo")) { model.undo() }.keyboardShortcut("z").disabled(!model.canUndo) } }
    }
}
