import AppKit
import SwiftUI
@preconcurrency import ApplicationServices
import ServiceManagement
import UniformTypeIdentifiers
import MouseCore

@MainActor final class AppModel: ObservableObject {
    @Published var configuration = Configuration()
    @Published var devices: [MouseDevice] = []
    @Published var competingUtilities: [String] = []
    @Published var runtimeReport = RuntimeReport()
    @Published var accessibility = false
    @Published var inputMonitoring = false
    @Published var lastMessage = ""
    @Published var errorMessage: String?
    @Published var pendingPreset: String?
    @Published var importPreview: ImportPreview?
    @Published var selectedProfileID: UUID?
    @Published var frontmostApp = ""
    @Published var frontmostBundleID: String?
    @Published var loginEnabled = false
    @Published var feedbackMessage = ""
    @Published var pendingMapping: Mapping?
    @Published var selectedButton: Int?
    @Published var selectedGesture: Trigger?
    @Published var showMouseSetup = false
    @Published var showCalibration = false
    @Published var showTroubleshooting = false
    @Published var savedButton: Int?
    let isTesting: Bool
    @Published var dirtyRecovery = false
    private let registry = DeviceRegistry()
    private let executor = ActionExecutor()
    let updater: UpdateController
    private let store: ConfigurationStore
    private var runtime: InputRuntime?
    var hasInputRuntime: Bool { runtime != nil }
    private var observations: [NSObjectProtocol] = []
    private var permissionTimer: Timer?
    private var history: [Configuration] = []
    private var lastFocus: String?
    private var feedbackPanel: NSPanel?
    init(testing: Bool = false, rendering: Bool = false) {
        isTesting = testing || rendering
        updater = UpdateController(enabled: !isTesting)
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("GlideMouse", isDirectory: true)
        store = ConfigurationStore(url: (testing || rendering) ? FileManager.default.temporaryDirectory.appendingPathComponent("GlideMouse-test-" + UUID().uuidString).appendingPathComponent("settings.json") : support.appendingPathComponent("settings.json"))
        do { configuration = try store.load(); dirtyRecovery = store.recoveredBackup }
        catch { errorMessage = localizedError(error); dirtyRecovery = true }
        // Rendering must never create an input thread, probe private touch devices,
        // register event taps, start updates, or read the user's settings.
        if rendering { return }
        executor.report = { [weak self] text in self?.lastMessage = text }
        runtime = InputRuntime(report: { [weak self] report in Task { @MainActor in self?.runtimeReport = report } }, action: { [weak self] request in Task { @MainActor in
            guard let self, self.runtime?.isCurrent(request.epoch) == true, self.configuration.engineEnabled else { return }
            if !request.alreadyInjected { self.runtime?.recordDispatch(recognizedAt: request.recognizedAt) }
            self.executor.execute(request.mapping, alreadyInjected: request.alreadyInjected, switchDelay: self.configuration.tuning.appSwitchDelay)
            self.runtime?.setDragging(self.executor.dragging, epoch: request.epoch)
            if self.configuration.showFeedback { self.showFeedback(self.text("action." + request.mapping.action.rawValue)) }
        } }, cancellation: { [weak self] in Task { @MainActor in self?.executor.cancel() } }, pause: { [weak self] in Task { @MainActor in self?.update { $0.engineEnabled = false } } }, drag: { [weak self] point, release in Task { @MainActor in if release { self?.executor.releaseDrag() } else { self?.executor.moveDrag(point) } } })
        if !testing { updater.start(automaticChecks: configuration.automaticUpdates) }
        if !rendering { registry.start { [weak self] in self?.refresh() } }
        refresh()
        let center = NSWorkspace.shared.notificationCenter
        observations.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let name = app.localizedName ?? "", id = app.bundleIdentifier
            Task { @MainActor in self?.frontmostApp = name; self?.frontmostBundleID = id; self?.runtime?.focusChanged(id); self?.lastFocus = id }
        })
        observations.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.runtime?.suspend(); self?.executor.cancel() } })
        observations.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.refresh() } })
        observations.append(center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.runtime?.suspend(); self?.executor.cancel() } })
        observations.append(center.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.refresh() } })
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in Task { @MainActor in self?.pollPermissions() } }
        loginEnabled = SMAppService.mainApp.status == .enabled
    }
    func text(_ key: String) -> String {
        let language = configuration.language.resourceIdentifier
        let path = AppResources.bundle.path(forResource: language, ofType: "lproj")
        let bundle = path.flatMap { Bundle(path: $0) } ?? AppResources.bundle
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
    /// Translate app-owned failures at the presentation boundary, keeping the
    /// configuration codec and its diagnostics independent of the UI language.
    func localizedError(_ error: Error) -> String {
        if let configurationError = error as? ConfigurationError {
            switch configurationError {
            case .futureVersion(let version): return String(format: text("Unsupported configuration schema %d."), version)
            case .recoveryFailed: return text("Settings and backup could not be read. Existing files have been preserved.")
            case .invalid(let message):
                let patterns = [
                    ("Conflicting mappings in ", ".", "Conflicting mappings in %@."),
                    ("Merge conflicts with profile ", ". Use replace or change its selectors.", "Merge conflicts with profile %@. Use replace or change its selectors."),
                    ("", " is outside its valid range.", "%@ is outside its valid range."),
                    ("", " needs a target.", "%@ needs a target.")
                ]
                for (prefix, suffix, key) in patterns where message.hasPrefix(prefix) && message.hasSuffix(suffix) {
                    let parameter = String(message.dropFirst(prefix.count).dropLast(suffix.count))
                    let value = key == "%@ needs a target." ? text("action." + parameter) : key == "%@ is outside its valid range." ? text(parameter) : parameter
                    return String(format: text(key), value)
                }
                return text(message)
            }
        }
        if error is DecodingError { return text("The settings file contains invalid or unsupported values.") }
        if (error as NSError).domain == NSCocoaErrorDomain { return text("The file could not be read or saved. Check its format, location and access permissions.") }
        return error.localizedDescription // System services supply their own localized messages.
    }
    func diagnosticDetail(_ detail: String) -> String {
        if detail.hasPrefix("Button "), let number = Int(detail.dropFirst(7)) { return text("Button") + " \(number + 1)" }
        if TriggerKind.allCases.contains(where: { $0.rawValue == detail }) { return text("trigger." + detail) }
        return text(detail)
    }
    var userFacingMessage: String {
        if lastMessage.hasPrefix("Executed:") { return "" }
        if lastMessage.hasPrefix("Preview:") {
            let action = lastMessage.dropFirst("Preview:".count).trimmingCharacters(in: .whitespaces)
            return text("Selected action") + ": " + text("action." + action)
        }
        if lastMessage.hasPrefix("Command finished: ") {
            return String(format: text("Command finished: %@"), String(lastMessage.dropFirst("Command finished: ".count)))
        }
        return text(lastMessage)
    }
    var effectiveProfile: Profile { configuration.profiles.first { $0.id == selectedProfileID } ?? configuration.globalDefaults }
    var isGlobal: Bool { !configuration.profiles.contains { $0.id == selectedProfileID } }
    var editingScopeName: String { isGlobal ? text("All apps") : effectiveProfile.name }
    var scopeSaveTitle: String { isGlobal ? text("Save for all apps") : text("Save for this app") }
    var scopeSaveFeedback: String { isGlobal ? text("Saved for all apps. Try your mouse button.") : String(format: text("Saved for %@. Open that app to try it."), editingScopeName) }
    var canUndo: Bool { !history.isEmpty }
    var colorScheme: ColorScheme? { configuration.appearance == .system ? nil : configuration.appearance == .dark ? .dark : .light }
    func update(_ change: (inout Configuration) -> Void) {
        var next = configuration; change(&next)
        do {
            try ConfigurationValidator.validate(next)
            try store.save(next)
            history.append(configuration); if history.count > 20 { history.removeFirst() }
            configuration = next; dirtyRecovery = false; errorMessage = nil
            if !isTesting { updater.setAutomaticChecks(next.automaticUpdates) }
            apply(); lastMessage = text("Saved")
        } catch { errorMessage = localizedError(error) }
    }
    private func apply() { runtime?.apply(configuration, bundleID: frontmostBundleID, magicMousePresent: devices.contains { $0.magicMouse }) }
    func refresh() {
        pollPermissions(); let previous = Set(devices.map(\.id)); devices = registry.enumerate()
        frontmostApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
        frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if previous != Set(devices.map(\.id)) { executor.cancel() }
        competingUtilities = NSWorkspace.shared.runningApplications.compactMap { app in
            let name = app.localizedName ?? "", id = app.bundleIdentifier?.lowercased() ?? ""
            return ["mac-mouse-fix", "macmousefix", "linearmouse", "bettertouchtool", "com.caldis.mos"].contains(where: { id.contains($0) }) ? name : nil
        }
        apply(); loginEnabled = SMAppService.mainApp.status == .enabled
    }
    private func pollPermissions() {
        let ax = AXIsProcessTrusted(), im = CGPreflightListenEventAccess()
        let changed = ax != accessibility || im != inputMonitoring
        if accessibility != ax { accessibility = ax }; if inputMonitoring != im { inputMonitoring = im }
        if changed { apply() }
    }
    func permission(_ kind: String) {
        if kind == "accessibility" { accessibility = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary) }
        else { inputMonitoring = CGRequestListenEventAccess() }
        let pane = kind == "accessibility" ? "Privacy_Accessibility" : "Privacy_ListenEvent"
        if let u = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") { NSWorkspace.shared.open(u) }
    }
    func undo() {
        guard let previous = history.popLast() else { return }
        do { try store.save(previous); configuration = previous; errorMessage = nil; apply(); lastMessage = text("Undone") } catch { errorMessage = localizedError(error) }
    }
    func mutateProfile(_ mutation: (inout Profile) -> Void) {
        update { c in if let id = selectedProfileID, let i = c.profiles.firstIndex(where: { $0.id == id }) { mutation(&c.profiles[i]) } else { mutation(&c.globalDefaults) } }
    }
    func saveMapping(_ m: Mapping) {
        mutateProfile { p in if let i = p.mappings.firstIndex(where: { $0.id == m.id }) { p.mappings[i] = m } else { p.mappings = MappingEdits.merge([m], into: p.mappings) } }
    }
    func removeMapping(_ id: UUID) { mutateProfile { $0.mappings.removeAll { $0.id == id } } }
    var currentMouse: MouseDevice? { devices.first { $0.name.localizedCaseInsensitiveContains("mouse") } ?? devices.first }
    var calibrationIdentity: String? { currentMouse.map { "\($0.vendor):\($0.product):\($0.transport):\($0.name)" } }
    var calibratedButtons: [CalibratedButton] { configuration.usability?.calibrations.first { $0.identity == calibrationIdentity }?.buttons ?? [] }
    func calibrate(button: Int, position: ButtonPosition) {
        guard let identity = calibrationIdentity else { return }
        update { c in
            var preferences = c.usability ?? UsabilityPreferences()
            var calibration = preferences.calibrations.first { $0.identity == identity } ?? MouseCalibration(identity: identity)
            calibration.assign(button: button, position: position)
            preferences.calibrations.removeAll { $0.identity == identity }; preferences.calibrations.append(calibration)
            c.usability = preferences
        }
        selectedButton = button
    }
    func completeSetup() { update { var ui = $0.usability ?? UsabilityPreferences(); ui.setupCompleted = true; $0.usability = ui }; showMouseSetup = false }
    func proposedPreset(_ kind: String) -> [Mapping] { ["keep", "smooth"].contains(kind) ? [] : MappingEdits.starter(kind, buttons: calibratedButtons) }
    func preset(_ kind: String) { let additions = proposedPreset(kind); guard !additions.isEmpty else { return }; mutateProfile { $0.mappings = MappingEdits.merge(additions, into: $0.mappings) } }
    func buttonTitle(_ button: Int) -> String { if button < 2 { return text(button == 0 ? "Left button" : "Right button") + " · \(button + 1)" }; return calibratedButtons.first { $0.button == button }.map { text($0.position.rawValue) + " · \(button + 1)" } ?? text("Button") + " \(button + 1)" }
    func simpleMapping(button: Int, kind: TriggerKind, clicks: Int = 1) -> Mapping? {
        let trigger = Trigger(kind: kind, button: button, clicks: clicks).canonical
        return effectiveProfile.mappings.first { $0.trigger.canonical == trigger } ?? (isGlobal ? nil : configuration.globalDefaults.mappings.first { $0.trigger.canonical == trigger })
    }
    func saveSimpleMapping(_ mapping: Mapping) {
        errorMessage = nil
        mutateProfile { $0.mappings = MappingEdits.merge([mapping], into: $0.mappings) }
        if errorMessage == nil { savedButton = mapping.button; lastMessage = scopeSaveFeedback }
    }
    func addAppProfile() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.application]; panel.canChooseDirectories = false
        panel.title = text("Add app"); panel.prompt = text("Add app")
        guard panel.runModal() == .OK, let url = panel.url, let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { return }
        selectAppProfile(name: url.deletingPathExtension().lastPathComponent, bundleID: id)
    }
    func selectAppProfile(name: String, bundleID: String) {
        if let existing = configuration.profiles.first(where: { $0.bundleID == bundleID && $0.deviceID == nil }) { selectedProfileID = existing.id; return }
        let profile = Profile(name: name, bundleID: bundleID)
        update { $0.profiles.append(profile) }
        if errorMessage == nil { selectedProfileID = profile.id }
    }
    func addDeviceProfile(_ d: MouseDevice) {
        guard d.stableIdentity else { errorMessage = text("This device has no stable identity."); return }
        let p = Profile(name: d.name, deviceID: d.id)
        update { $0.profiles.append(p) }; selectedProfileID = p.id
    }
    func removeProfile() {
        guard let id = selectedProfileID, let profile = configuration.profiles.first(where: { $0.id == id }) else { return }
        update { $0.profiles.removeAll { $0.id == id } }
        guard errorMessage == nil else { return }
        selectedProfileID = nil; savedButton = nil
        lastMessage = String(format: text("Removed %@. All apps settings now apply. Undo restores its setup."), profile.name)
    }
    func exportConfiguration() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "GlideMouse-settings.json"; panel.allowedContentTypes = [.json]
        panel.title = text("Export settings"); panel.prompt = text("Save")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try ConfigurationCodec.encode(configuration).write(to: url, options: .atomic); lastMessage = text("Exported") } catch { errorMessage = localizedError(error) }
    }
    func chooseImport() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]
        panel.title = text("Import settings"); panel.prompt = text("Import settings")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { importPreview = try ConfigurationCodec.preview(Data(contentsOf: url)) } catch { errorMessage = localizedError(error) }
    }
    func applyImport(merge: Bool) {
        guard let preview = importPreview else { return }
        do { let next = merge ? try ConfigurationCodec.merge(current: configuration, imported: preview.configuration) : preview.configuration; update { $0 = next }; importPreview = nil; selectedProfileID = nil } catch { errorMessage = localizedError(error) }
    }
    func setMouseCaptureArea(_ rect: CGRect?, owner: UUID? = nil) { runtime?.setCaptureArea(rect, owner: owner) }
    func learnButton() { runtime?.beginLearning(); lastMessage = text("Press a mouse button, then stop learning.") }
    func stopLearning() { runtime?.endLearning() }
    func preview(_ m: Mapping) { executor.execute(m, preview: true) }
    func runTest(_ m: Mapping) { executor.execute(m); runtime?.setDragging(executor.dragging) }
    func clearDiagnostics() { runtime?.clearDiagnostics() }
    func exportDiagnostics() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "GlideMouse-diagnostics.json"; panel.allowedContentTypes = [.json]
        panel.title = text("Export diagnostics"); panel.prompt = text("Save")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        struct Diagnostic: Codable { var version: String; var os: String; var accessibility: Bool; var inputMonitoring: Bool; var engine: String; var devices: [String]; var events: UInt64; var syntheticIgnored: UInt64; var timeouts: Int; var touchStatus: String; var touchDrops: UInt64; var maxCallbackMS: Double; var p95CallbackMS: Double; var records: [InputRecord] }
        let callbacks = runtimeReport.callbacks.sorted(); let p95 = callbacks.isEmpty ? 0 : callbacks[min(callbacks.count - 1, Int(Double(callbacks.count) * 0.95))]
        let diagnostic = Diagnostic(version: AppResources.version, os: ProcessInfo.processInfo.operatingSystemVersionString, accessibility: accessibility, inputMonitoring: inputMonitoring, engine: runtimeReport.status, devices: devices.map { $0.name + " (" + $0.transport + ")" }, events: runtimeReport.events, syntheticIgnored: runtimeReport.injectedIgnored, timeouts: runtimeReport.timeouts, touchStatus: runtimeReport.touchStatus, touchDrops: runtimeReport.touchDrops, maxCallbackMS: runtimeReport.maximumCallbackMS, p95CallbackMS: p95, records: runtimeReport.records)
        do { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]; try encoder.encode(diagnostic).write(to: url, options: .atomic); lastMessage = text("Exported") } catch { errorMessage = localizedError(error) }
    }
    func setLogin(_ enabled: Bool) {
        do { if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }; loginEnabled = SMAppService.mainApp.status == .enabled }
        catch { errorMessage = localizedError(error); loginEnabled = SMAppService.mainApp.status == .enabled }
    }
    private func showFeedback(_ message: String) {
        feedbackMessage = message
        if feedbackPanel == nil {
            let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 280, height: 58), styleMask: [.borderless,.nonactivatingPanel], backing: .buffered, defer: false)
            p.level = .floating; p.isOpaque = false; p.backgroundColor = .clear; p.ignoresMouseEvents = true; p.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary]; feedbackPanel = p
        }
        if let p = feedbackPanel, let screen = NSScreen.main {
            p.contentView = NSHostingView(rootView: Text(message).font(.headline).padding(18).frame(width: 280).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)))
            p.setFrameOrigin(NSPoint(x: screen.visibleFrame.midX - 140, y: screen.visibleFrame.minY + 60)); p.orderFrontRegardless()
            Task { @MainActor [weak self] in try? await Task.sleep(for: .seconds(1.2)); if self?.feedbackMessage == message { self?.feedbackPanel?.orderOut(nil) } }
        }
    }
    func writeLaunchReport(to url: URL) {
        struct Report: Codable { var version: String; var launchedNormally: Bool; var accessibility: Bool; var inputMonitoring: Bool; var engine: String; var devices: [String]; var competingUtilities: [String]; var finishedLaunching: Bool; var visibleWindows: Int; var temporarySettings: Bool; var settingsWindowVisible: Bool; var updateConfigured: Bool; var updateCanCheck: Bool }
        let result = Report(version: AppResources.version, launchedNormally: true, accessibility: AXIsProcessTrusted(), inputMonitoring: CGPreflightListenEventAccess(), engine: runtimeReport.status, devices: devices.map(\.name), competingUtilities: competingUtilities, finishedLaunching: NSRunningApplication.current.isFinishedLaunching, visibleWindows: NSApplication.shared.windows.filter(\.isVisible).count, temporarySettings: CommandLine.arguments.contains("--ui-test"), settingsWindowVisible: NSApplication.shared.windows.contains { $0.title.contains("GlideMouse") && $0.isVisible }, updateConfigured: updater.configured, updateCanCheck: updater.canCheck)
        let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted,.sortedKeys]
        if let data = try? e.encode(result) { try? data.write(to: url, options: .atomic) }
        if CommandLine.arguments.contains("--ui-test") { UIHarness.captureSettingsWindow(to: url.deletingLastPathComponent().appendingPathComponent("glidemouse-settings-visible.png")) }
    }
    func writeRuntimeReport(to url: URL) {
        struct Snapshot: Encodable { var configuration: Configuration; var status: String; var events: UInt64; var records: [InputRecord]; var actionDispatchMS: [Double]; var fastDesktopActions: UInt64; var recoveredBackup: Bool; var error: String?; var lastMessage: String? }
        let snapshot = Snapshot(configuration: configuration, status: runtimeReport.status, events: runtimeReport.events, records: runtimeReport.records, actionDispatchMS: runtimeReport.actionDispatchMS, fastDesktopActions: runtimeReport.fastDesktopActions, recoveredBackup: dirtyRecovery, error: errorMessage, lastMessage: lastMessage)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(snapshot) { try? data.write(to: url, options: .atomic) }
    }
    func quit() { registry.stop(); permissionTimer?.invalidate(); executor.cancel(); runtime?.shutdown(); observations.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }; NSApplication.shared.terminate(nil) }
}
