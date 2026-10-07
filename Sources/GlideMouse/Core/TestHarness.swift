import Foundation
import AppKit
import SwiftUI
@preconcurrency import ApplicationServices
import MouseCore

@MainActor enum UIHarness {
    /// Exercise the actual compiled language bundles and presentation helpers.
    static func checkLocalization(to url: URL) -> Bool {
        let model = AppModel(testing: true, rendering: true)
        var checks: [String: Bool] = [:]
        for language in AppLanguage.allCases {
            model.configuration.language = language
            let prefix = language.rawValue + "."
            checks[prefix + "bundle"] = AppResources.bundle.path(forResource: language.resourceIdentifier, ofType: "lproj") != nil
            checks[prefix + "actions"] = MouseAction.allCases.allSatisfy { model.text("action." + $0.rawValue) != "action." + $0.rawValue }
            checks[prefix + "triggers"] = TriggerKind.allCases.allSatisfy { model.text("trigger." + $0.rawValue) != "trigger." + $0.rawValue }
            let original = model.configuration
            model.update { $0.language = language }
            checks[prefix + "saved"] = model.configuration.language == language && model.errorMessage == nil
            model.undo()
            checks[prefix + "undo"] = model.configuration == original
        }
        model.configuration.language = .zh
        checks["zh.settings"] = model.text("Settings") == "设置"
        checks["zh.recording"] = model.text("Press shortcut…") == "请按下快捷键…"
        checks["zh.shortcutLabel"] = ShortcutDisplay.label(keyCode: 49, modifiers: .command, translate: model.text) == "⌘空格" && ShortcutDisplay.label(keyCode: 0, modifiers: .command, translate: model.text) == "⌘A"
        checks["zh.scopeFormat"] = String(format: model.text("Changes apply only while using %@."), "Safari") == "更改仅在使用 Safari 时生效。"
        checks["zh.triggerFormat"] = triggerLabel(.init(kind: .buttonChord, button: 3, chordButton: 4), model: model) == "按住按钮 4，再点击按钮 5"
        checks["zh.futureVersion"] = model.localizedError(ConfigurationError.futureVersion(999)) == "不支持设置格式版本 999。"
        checks["zh.validation"] = model.localizedError(ConfigurationError.invalid("Hold delay is outside its valid range.")) == "长按等待时间 超出允许范围。"
        checks["zh.targetError"] = model.localizedError(ConfigurationError.invalid("openURL needs a target.")) == "打开网页 需要指定目标。"
        checks["zh.profileError"] = model.localizedError(ConfigurationError.invalid("Conflicting mappings in Safari.")) == "Safari 中的操作设置存在冲突。"
        checks["zh.mergeError"] = model.localizedError(ConfigurationError.invalid("Merge conflicts with profile Safari. Use replace or change its selectors.")) == "合并内容与配置 Safari 冲突。请使用替换，或更改该配置的应用或设备。"
        model.lastMessage = "Command finished: 0"
        checks["zh.commandStatus"] = model.userFacingMessage == "命令已结束，退出代码：0"
        checks["zh.diagnostics"] = model.diagnosticDetail("Button 3") == "按钮 4" && model.diagnosticDetail("buttonHold") == "长按按钮"
        model.configuration.language = .en
        checks["switchBackEnglish"] = model.text("Settings") == "Settings"
        model.configuration.language = .my
        checks["switchBackMyanmar"] = model.text("Settings") != "Settings" && model.text("Settings") != "设置"
        let passed = checks.values.allSatisfy { $0 }
        if let data = try? JSONSerialization.data(withJSONObject: ["passed": passed, "checks": checks], options: [.prettyPrinted, .sortedKeys]) { try? data.write(to: url, options: .atomic) }
        print("Localization checks: \(checks.count), passed: \(passed)")
        return passed
    }
    static func renderLocalizedSheets(to directory: URL) {
        let model = AppModel(testing: true, rendering: true)
        NSApplication.shared.setActivationPolicy(.accessory)
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 600, height: 820), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        var options = ActionOptions(); options.keyCode = 0; options.modifiers = [.command]
        let mapping = Mapping(trigger: .init(kind: .button, button: 3), action: .shortcut, options: options)
        for language in AppLanguage.allCases {
            model.configuration.language = language
            for appearance in [ColorScheme.light, .dark] {
                func capture<V: View>(_ content: V, size: NSSize, name: String) {
                    let view = NSHostingView(rootView: content.preferredColorScheme(appearance).environment(\.locale, Locale(identifier: language.resourceIdentifier)).background(Color(nsColor: .windowBackgroundColor)))
                    view.sizingOptions = []; window.contentView = view; window.setContentSize(size); view.setFrameSize(size); window.orderFront(nil)
                    RunLoop.current.run(until: Date().addingTimeInterval(0.2)); view.layoutSubtreeIfNeeded(); window.display()
                    save(view, directory.appendingPathComponent("\(language.rawValue)-\(name)-\(appearance == .light ? "light" : "dark").png"))
                }
                capture(MappingEditor(model: model, mapping: mapping), size: .init(width: 600, height: 820), name: "mapping-editor")
                var code: UInt16 = 0; var modifiers: Modifiers = .command; var recording = true
                capture(ShortcutRecorder(model: model, keyCode: Binding(get: { code }, set: { code = $0 }), modifiers: Binding(get: { modifiers }, set: { modifiers = $0 }), recording: Binding(get: { recording }, set: { recording = $0 })).frame(height: 36).padding(20), size: .init(width: 420, height: 76), name: "shortcut-recording")
                model.importPreview = try? ConfigurationCodec.preview(ConfigurationCodec.encode(Configuration()))
                capture(ImportReview(model: model), size: .init(width: 530, height: 310), name: "import-review")
                model.pendingPreset = "desktop"
                capture(PresetReview(model: model, kind: "desktop"), size: .init(width: 600, height: 450), name: "preset-review")
            }
        }
        window.orderOut(nil)
    }
    /// UI and persistence verification without event taps, hardware probes or injection.
    static func magicReadiness(to directory: URL) -> Bool {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let model = AppModel(testing: true, rendering: true)
        let physical = Mapping(button: 3, action: .spaceLeft)
        model.configuration.globalDefaults.mappings = [physical]
        model.preset("magic")
        var checks: [String: Bool] = [:]
        checks["previewHasNoInputRuntime"] = !model.hasInputRuntime
        checks["previewHasNoUpdater"] = !model.updater.configured
        let cycleEvents = Injection.keyEvents(48, modifiers: [.command, .shift], original: .maskCommand)?.0 ?? []
        checks["cyclePreservesHeldCommand"] = !cycleEvents.isEmpty && !cycleEvents.contains { $0.type == .flagsChanged && $0.getIntegerValueField(.keyboardEventKeycode) == 55 }
        checks["cycleBalancesShift"] = cycleEvents.filter { $0.type == .flagsChanged && $0.getIntegerValueField(.keyboardEventKeycode) == 56 }.count == 2
        let desktopEvents = Injection.keyEvents(124, modifiers: .control, original: [])?.0 ?? []
        let custom = Injection.keyEvents(49, modifiers: .command, original: .maskAlternate, preservePhysicalModifiers: false)?.0 ?? []
        checks["customShortcutIgnoresTriggerModifier"] = custom.filter { $0.type == .keyDown || $0.type == .keyUp }.count == 2 && custom.filter { $0.type == .keyDown || $0.type == .keyUp }.allSatisfy { $0.flags.contains(.maskCommand) && !$0.flags.contains(.maskAlternate) }
        checks["customShortcutNeverReleasesPhysicalOption"] = !custom.contains { $0.type == .flagsChanged && $0.getIntegerValueField(.keyboardEventKeycode) == 58 }
        checks["desktopArrowIdentity"] = desktopEvents.filter { $0.type == .keyDown || $0.type == .keyUp }.allSatisfy { $0.flags.contains([.maskControl, .maskSecondaryFn, .maskNumericPad]) && !$0.flags.contains(.maskCommand) }
        checks["physicalPreserved"] = model.configuration.globalDefaults.mappings.first == physical
        checks["presetSaved"] = model.configuration.globalDefaults.mappings.count == MagicMouseCatalog.defaults.count + 1 && model.errorMessage == nil
        checks["presetDoesNotEnableEngine"] = !model.configuration.engineEnabled && !model.configuration.touchEnabled
        let app = Profile(name: "Sample editor", bundleID: "sample.editor")
        model.update { $0.profiles.append(app) }; model.selectedProfileID = app.id
        let mapping = Mapping(trigger: .init(kind: .tap, fingers: 2, clicks: 3, modifiers: .command), action: .shortcut)
        model.saveMapping(mapping)
        checks["saveAppOverride"] = model.effectiveProfile.mappings == [mapping] && model.configuration.globalDefaults.mappings.first == physical
        model.removeMapping(mapping.id); checks["deleteAppOverride"] = model.effectiveProfile.mappings.isEmpty
        model.undo(); checks["undoDelete"] = model.effectiveProfile.mappings == [mapping]
        model.selectedProfileID = nil
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 1040, height: 780), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        NSApplication.shared.setActivationPolicy(.accessory)
        for language in AppLanguage.allCases {
            model.configuration.language = language
            checks[language.rawValue + ".localized"] = model.text("Choose a gesture") != "Choose a gesture" || language == .en
            for width in [820, 1040] { for appearance in [ColorScheme.light, .dark] {
                let size = NSSize(width: width, height: width == 820 ? 580 : 780)
                let view = NSHostingView(rootView: SettingsRoot(model: model, initialPage: .magic).preferredColorScheme(appearance))
                view.sizingOptions = []; window.contentView = view; window.setContentSize(size); view.setFrameSize(size); window.orderFront(nil)
                RunLoop.current.run(until: Date().addingTimeInterval(0.2)); view.layoutSubtreeIfNeeded(); window.display()
                save(view, directory.appendingPathComponent("\(language.rawValue)-magic-\(width)-\(appearance == .light ? "light" : "dark").png"))
            } }
        }
        window.orderOut(nil)
        let passed = checks.values.allSatisfy { $0 }
        if let data = try? JSONSerialization.data(withJSONObject: ["passed": passed, "checks": checks, "inputRuntimeCreated": model.hasInputRuntime], options: [.prettyPrinted, .sortedKeys]) { try? data.write(to: directory.appendingPathComponent("native-ui-checks.json")) }
        return passed
    }
    static func render(to directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let model = AppModel(testing: true, rendering: true)
        model.devices = [MouseDevice(id: "render-fixture", name: "Sample Mouse", transport: "Fixture", vendor: 0, product: 0, buttons: 5, stableIdentity: false, magicMouse: false)]
        model.configuration.globalDefaults.mappings = [Mapping(button: 3, action: .spaceLeft), Mapping(button: 4, action: .spaceRight), Mapping(trigger: .init(kind: .buttonHold, button: 3), action: .missionControl)]
        var preferences = UsabilityPreferences(); preferences.setupCompleted = true
        if let identity = model.calibrationIdentity { preferences.calibrations = [MouseCalibration(identity: identity, buttons: [.init(button: 2, position: .wheel), .init(button: 3, position: .lower), .init(button: 4, position: .upper)])] }
        model.configuration.usability = preferences; model.selectedButton = 3
        let app = NSApplication.shared; app.setActivationPolicy(.accessory)
        let window = NSWindow(contentRect: NSRect(x: 0,y: 0,width: 1040,height: 730), styleMask: [.titled,.closable,.resizable], backing: .buffered, defer: false)
        for language in AppLanguage.allCases {
            model.configuration.language = language
            for page in SettingsPage.allCases {
                model.runtimeReport.observedButtons = [2, 3, 4] // Render fixture, not physical detection evidence.
                let view = NSHostingView(rootView: SettingsRoot(model: model, initialPage: page).preferredColorScheme(.light))
                view.sizingOptions = []; window.contentView = view; view.setFrameSize(NSSize(width: 1040,height: 730)); window.orderFront(nil)
                RunLoop.current.run(until: Date().addingTimeInterval(0.2)); view.layoutSubtreeIfNeeded(); window.display()
                save(view, directory.appendingPathComponent("\(language.rawValue)-\(page.id.replacingOccurrences(of: " ", with: "-").replacingOccurrences(of: "&", with: "and"))-light.png"))
            }
        }
        for language in AppLanguage.allCases {
            model.configuration.language = language
            for width in [820, 1040] {
                for appearance in [ColorScheme.light, .dark] {
                    for page in [SettingsPage.mappings, .scrolling, .general] {
                        model.runtimeReport.observedButtons = [2, 3, 4] // Render fixture.
                        let size = NSSize(width: width, height: width == 820 ? 580 : 730)
                        let view = NSHostingView(rootView: SettingsRoot(model: model, initialPage: page).preferredColorScheme(appearance))
                        view.sizingOptions = []; window.contentView = view; window.setContentSize(size); view.setFrameSize(size); window.orderFront(nil)
                        RunLoop.current.run(until: Date().addingTimeInterval(0.2)); view.layoutSubtreeIfNeeded(); window.display()
                        let name = page == .mappings ? "mappings" : page == .scrolling ? "scrolling" : "settings"
                        save(view, directory.appendingPathComponent("\(language.rawValue)-\(name)-\(width)-\(appearance == .light ? "light" : "dark").png"))
                    }
                }
            }
        }
        let calibrated = model.configuration.usability
        model.configuration.usability = UsabilityPreferences()
        window.setContentSize(NSSize(width: 820, height: 580))
        for language in AppLanguage.allCases {
            model.configuration.language = language
            let view = NSHostingView(rootView: SettingsRoot(model: model).preferredColorScheme(.light))
            view.sizingOptions = []; window.contentView = view; view.setFrameSize(NSSize(width: 820, height: 580)); window.orderFront(nil)
            RunLoop.current.run(until: Date().addingTimeInterval(0.2)); view.layoutSubtreeIfNeeded(); window.display()
            save(view, directory.appendingPathComponent("\(language.rawValue)-buttons-unplaced-820.png"))
        }
        model.configuration.usability = calibrated
        window.setContentSize(NSSize(width: 820, height: 580))
        for language in AppLanguage.allCases {
            model.configuration.language = language; model.selectedButton = 0
            let view = NSHostingView(rootView: SettingsRoot(model: model).preferredColorScheme(.light))
            view.sizingOptions = []; window.contentView = view; view.setFrameSize(NSSize(width: 820, height: 580)); window.orderFront(nil)
            RunLoop.current.run(until: Date().addingTimeInterval(0.2)); view.layoutSubtreeIfNeeded(); window.display()
            save(view, directory.appendingPathComponent("\(language.rawValue)-primary-button-820.png"))
            var action = MouseAction.rightClick
            let chooser = NSHostingView(rootView: ActionChooser(model: model, action: Binding(get: { action }, set: { action = $0 }), triggerKind: .button).preferredColorScheme(.light).background(Color(nsColor: .windowBackgroundColor)))
            chooser.sizingOptions = []; window.contentView = chooser; window.setContentSize(NSSize(width: 500, height: 560)); chooser.setFrameSize(NSSize(width: 500, height: 560)); window.orderFront(nil)
            RunLoop.current.run(until: Date().addingTimeInterval(0.2)); chooser.layoutSubtreeIfNeeded(); window.display()
            save(chooser, directory.appendingPathComponent("\(language.rawValue)-action-chooser.png"))
            window.setContentSize(NSSize(width: 820, height: 580))
        }
        model.selectedButton = 3
        let previousMappings = model.configuration.globalDefaults.mappings
        let savedProfiles = model.configuration.profiles
        let scopeProfile = Profile(name: "Microsoft PowerPoint", bundleID: "com.microsoft.Powerpoint")
        model.configuration.profiles = [scopeProfile]; model.selectedProfileID = scopeProfile.id
        for language in AppLanguage.allCases {
            model.configuration.language = language
            for customized in [false, true] {
                model.configuration.profiles[0].mappings = customized ? [Mapping(button: 3, action: .nextTrack)] : []
                for width in [820, 1040] {
                    let size = NSSize(width: width, height: width == 820 ? 580 : 730)
                    window.setContentSize(size)
                    let view = NSHostingView(rootView: SettingsRoot(model: model).preferredColorScheme(.light))
                    view.sizingOptions = []; window.contentView = view; view.setFrameSize(size); window.orderFront(nil)
                    RunLoop.current.run(until: Date().addingTimeInterval(0.2)); view.layoutSubtreeIfNeeded(); window.display()
                    save(view, directory.appendingPathComponent("\(language.rawValue)-app-\(customized ? "custom" : "inherited")-\(width).png"))
                }
            }
        }
        model.configuration.profiles = savedProfiles; model.selectedProfileID = nil
        model.configuration.globalDefaults.mappings = [Mapping(trigger: .init(kind: .buttonDrag, button: 3, direction: .left), action: .spaceLeft), Mapping(trigger: .init(kind: .buttonDrag, button: 3, direction: .right), action: .spaceRight), Mapping(trigger: .init(kind: .buttonWheel, button: 4, direction: .up), action: .zoomIn), Mapping(trigger: .init(kind: .buttonWheel, button: 4, direction: .down), action: .zoomOut)]
        window.setContentSize(NSSize(width: 630, height: 540))
        for language in AppLanguage.allCases {
            model.configuration.language = language
            let view = NSHostingView(rootView: ScrollView { AdvancedBindings(model: model, initiallyExpanded: true) }.padding(20).background(Color(nsColor: .windowBackgroundColor)).preferredColorScheme(.light))
            view.sizingOptions = []; window.contentView = view; view.setFrameSize(NSSize(width: 630, height: 540)); window.orderFront(nil)
            RunLoop.current.run(until: Date().addingTimeInterval(0.2)); view.layoutSubtreeIfNeeded(); window.display()
            save(view, directory.appendingPathComponent("\(language.rawValue)-other-gestures-630.png"))
        }
        model.configuration.globalDefaults.mappings = previousMappings
        window.setContentSize(NSSize(width: 590,height: 610))
        for language in AppLanguage.allCases {
            model.configuration.language = language
            for step in 0...2 {
                let view = NSHostingView(rootView: MouseSetupWizard(model: model, initialStep: step).preferredColorScheme(.light))
                view.sizingOptions = []; window.contentView = view; view.setFrameSize(NSSize(width: 590,height: 610)); window.orderFront(nil)
                RunLoop.current.run(until: Date().addingTimeInterval(0.2)); view.layoutSubtreeIfNeeded(); window.display()
                save(view,directory.appendingPathComponent("\(language.rawValue)-setup-\(step + 1).png"))
            }
        }
        // About is low on Settings: render it directly to review all contact targets.
        for language in AppLanguage.allCases {
            model.configuration.language = language
            for appearance in [ColorScheme.light, .dark] {
                let size = NSSize(width: 630, height: 360)
                let view = NSHostingView(rootView: AboutGlideMouse(model: model).padding(22).background(Color(nsColor: .windowBackgroundColor)).preferredColorScheme(appearance))
                view.sizingOptions = []; window.contentView = view; window.setContentSize(size); view.setFrameSize(size); window.orderFront(nil)
                RunLoop.current.run(until: Date().addingTimeInterval(0.2)); view.layoutSubtreeIfNeeded(); window.display()
                save(view, directory.appendingPathComponent("\(language.rawValue)-about-\(appearance == .light ? "light" : "dark").png"))
            }
        }
        window.orderOut(nil)
        print("Rendered native SwiftUI pages to \(directory.path)")
    }
    /// Review the simplified sidebar and the Help-only troubleshooting sheet.
    static func renderTroubleshooting(to directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let model = AppModel(testing: true, rendering: true)
        model.configuration.usability = UsabilityPreferences(); model.configuration.usability?.setupCompleted = true
        NSApplication.shared.setActivationPolicy(.accessory)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 580), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        for language in AppLanguage.allCases {
            model.configuration.language = language
            for width in [820, 1040] {
                let size = NSSize(width: width, height: width == 820 ? 580 : 730)
                let view = NSHostingView(rootView: SettingsRoot(model: model, initialPage: .profiles).preferredColorScheme(.light))
                view.sizingOptions = []; window.contentView = view; window.setContentSize(size); view.setFrameSize(size); window.orderFront(nil)
                RunLoop.current.run(until: Date().addingTimeInterval(0.2)); view.layoutSubtreeIfNeeded(); window.display()
                save(view, directory.appendingPathComponent("\(language.rawValue)-advanced-sidebar-\(width).png"))
            }
            for appearance in [ColorScheme.light, .dark] {
                for expanded in [false, true] {
                    let size = NSSize(width: 640, height: 560)
                    let view = NSHostingView(rootView: TroubleshootingSheet(model: model, initiallyExpanded: expanded).background(Color(nsColor: .windowBackgroundColor)).preferredColorScheme(appearance))
                    view.sizingOptions = []; window.contentView = view; window.setContentSize(size); view.setFrameSize(size); window.orderFront(nil)
                    RunLoop.current.run(until: Date().addingTimeInterval(0.2)); view.layoutSubtreeIfNeeded(); window.display()
                    save(view, directory.appendingPathComponent("\(language.rawValue)-help-\(expanded ? "expanded" : "collapsed")-\(appearance == .light ? "light" : "dark").png"))
                }
            }
        }
        window.orderOut(nil)
        print("Rendered simplified advanced sidebar and collapsed/expanded Help sheet")
    }
    /// Exercise removal and Undo in the same visible app-scoped settings view.
    static func renderAppRemoval(to directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let model = AppModel(testing: true, rendering: true)
        model.configuration.globalDefaults.mappings = [Mapping(button: 3, action: .spaceLeft)]
        model.configuration.usability = UsabilityPreferences(); model.configuration.usability?.setupCompleted = true
        model.selectedButton = 3; model.runtimeReport.observedButtons = [2, 3, 4]
        var scroll = ScrollSettings(); scroll.speed = 2
        let profile = Profile(name: "Microsoft PowerPoint", bundleID: "com.microsoft.Powerpoint", mappings: [Mapping(button: 3, action: .missionControl)], scroll: scroll)
        let other = Profile(name: "Safari", bundleID: "com.apple.Safari")
        NSApplication.shared.setActivationPolicy(.accessory)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 580), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        for language in AppLanguage.allCases {
            model.configuration.language = language
            for width in [820, 1040] {
                for page in [SettingsPage.mappings, .scrolling, .profiles] {
                    model.configuration.profiles = [profile, other]; model.selectedProfileID = profile.id; model.lastMessage = ""
                    let size = NSSize(width: width, height: width == 820 ? 580 : 730)
                    let view = NSHostingView(rootView: SettingsRoot(model: model, initialPage: page).preferredColorScheme(.light))
                    view.sizingOptions = []; window.contentView = view; window.setContentSize(size); view.setFrameSize(size); window.orderFront(nil)
                    for state in ["selected", "removed", "undone"] {
                        if state == "removed" { model.removeProfile() }
                        if state == "undone" { model.undo() }
                        RunLoop.current.run(until: Date().addingTimeInterval(0.2)); view.layoutSubtreeIfNeeded(); window.display()
                        save(view, directory.appendingPathComponent("\(language.rawValue)-\(page == .mappings ? "buttons" : page == .scrolling ? "scrolling" : "profiles")-\(width)-\(state).png"))
                    }
                }
            }
        }
        window.orderOut(nil)
        print("Rendered selected app, removal and Undo across all app-scoped pages")
    }
    /// Resize the same native Buttons view to inspect proportional labels and anchors.
    static func renderResponsiveButtons(to directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let model = AppModel(testing: true, rendering: true)
        model.devices = [MouseDevice(id: "resize-fixture", name: "Sample Mouse", transport: "Fixture", vendor: 0, product: 0, buttons: 5, stableIdentity: false, magicMouse: false)]
        model.configuration.globalDefaults.mappings = [Mapping(button: 3, action: .spaceLeft), Mapping(button: 4, action: .spaceRight), Mapping(trigger: .init(kind: .buttonHold, button: 3), action: .missionControl)]
        var preferences = UsabilityPreferences(); preferences.setupCompleted = true
        if let identity = model.calibrationIdentity {
            preferences.calibrations = [MouseCalibration(identity: identity, buttons: [.init(button: 2, position: .wheel), .init(button: 3, position: .lower), .init(button: 4, position: .upper)])]
        }
        model.configuration.usability = preferences; model.selectedButton = 3
        NSApplication.shared.setActivationPolicy(.accessory)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 580), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        for language in AppLanguage.allCases {
            model.configuration.language = language
            for appearance in [ColorScheme.light, .dark] {
                model.runtimeReport.observedButtons = [2, 3, 4]
                let view = NSHostingView(rootView: SettingsRoot(model: model).preferredColorScheme(appearance))
                view.sizingOptions = []; window.contentView = view
                // Return to the minimum width to check resizing back down as well.
                for (index, width) in [820, 1040, 1440, 1800, 820].enumerated() {
                    let size = NSSize(width: width, height: width == 820 ? 580 : width == 1040 ? 730 : 1000)
                    window.setContentSize(size); view.setFrameSize(size); window.orderFront(nil)
                    RunLoop.current.run(until: Date().addingTimeInterval(0.2)); view.layoutSubtreeIfNeeded(); window.display()
                    save(view, directory.appendingPathComponent("\(language.rawValue)-buttons-\(width)-\(appearance == .light ? "light" : "dark")\(index == 4 ? "-resized-back" : "").png"))
                }
                model.runtimeReport.observedButtons = [2, 3, 4, 5, 6]
                for width in [820, 1800] {
                    // Include the below-image strip in the capture; ordinary shorter
                    // windows expose the same content by scrolling.
                    let size = NSSize(width: width, height: width == 820 ? 820 : 1200)
                    window.setContentSize(size); view.setFrameSize(size)
                    RunLoop.current.run(until: Date().addingTimeInterval(0.2)); view.layoutSubtreeIfNeeded(); window.display()
                    save(view, directory.appendingPathComponent("\(language.rawValue)-buttons-extra-\(width)-\(appearance == .light ? "light" : "dark").png"))
                }
            }
        }
        window.orderOut(nil)
        print("Rendered Buttons resize sequence and extra-button labels in both languages and appearances")
    }
    /// Exercise the actual profile view while unrelated runtime updates are published.
    static func renderProfileList(to directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let model = AppModel(testing: true, rendering: true)
        model.configuration.globalDefaults.mappings = [Mapping(button: 3, action: .spaceLeft), Mapping(button: 4, action: .spaceRight), Mapping(trigger: .init(kind: .buttonHold, button: 3), action: .missionControl)]
        let app = NSApplication.shared; app.setActivationPolicy(.accessory)
        let size = NSSize(width: 1040, height: 730)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        for language in AppLanguage.allCases {
            model.configuration.language = language
            let view = NSHostingView(rootView: SettingsRoot(model: model, initialPage: .profiles).preferredColorScheme(.light))
            view.sizingOptions = []; window.contentView = view; window.setContentSize(size); view.setFrameSize(size); window.orderFront(nil)
            RunLoop.current.run(until: Date().addingTimeInterval(0.2)); view.layoutSubtreeIfNeeded(); window.display()
            save(view, directory.appendingPathComponent("\(language.rawValue)-profiles-before.png"))
            for tick in 1...40 {
                model.runtimeReport.events = UInt64(tick)
                RunLoop.current.run(until: Date().addingTimeInterval(0.03)); view.layoutSubtreeIfNeeded(); window.display()
            }
            save(view, directory.appendingPathComponent("\(language.rawValue)-profiles-after.png"))
        }
        window.orderOut(nil)
        print("Rendered profile list before/after 40 runtime updates per language")
    }
    static func captureSettingsWindow(to url: URL) {
        guard let window = NSApplication.shared.windows.first(where: { $0.title.contains("GlideMouse") && $0.isVisible }), let view = window.contentView else { return }
        view.layoutSubtreeIfNeeded(); save(view,url)
    }
    /// Read-only diagnostics for native UI checks; never moves the pointer.
    static func writeCursorReport(to url: URL) {
        let cursor = NSCursor.current
        let kind = cursor == .pointingHand ? "pointingHand" : cursor == .arrow ? "arrow" : cursor == .iBeam ? "text" : "other"
        let result: [String: Any] = ["applicationActive": NSApplication.shared.isActive, "cursor": kind, "time": ProcessInfo.processInfo.systemUptime]
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) { try? data.write(to: url, options: .atomic) }
    }
    private static func save(_ view: NSView, _ url: URL) {
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        if let png = bitmap.representation(using: .png, properties: [:]) { try? png.write(to: url) }
    }
}

@MainActor enum IntegrationHarness {
    /// Real CoreGraphics event-tap round trip in a dedicated empty test window.
    /// These are synthetic integration events, never described as physical hardware evidence.
    static func run(physical: Bool = false, calibration: Bool = false) -> Int32 {
        guard AXIsProcessTrusted(), CGPreflightListenEventAccess() else { print("SKIP: macOS input permissions unavailable"); return 77 }
        let app = NSApplication.shared; app.setActivationPolicy(.regular)
        let window = NSWindow(contentRect: NSRect(x: 200,y: 200,width: 400,height: 250), styleMask: [.titled,.closable], backing: .buffered, defer: false)
        window.title = physical ? "GlideMouse — Physical remap test" : "GlideMouse Integration Test"
        let stopTarget = TestStopper()
        if physical { window.delegate = stopTarget }
        if physical {
            let scrollView = NSScrollView(frame: NSRect(x: 0,y: 42,width: 400,height: 208)); scrollView.hasVerticalScroller = true
            let content = NSTextField(wrappingLabelWithString: "Physical test: wheel-click and both side buttons (2–4) → middle click. Scroll up/down.\n" + (1...40).map { "Row \($0) — smooth scrolling preview" }.joined(separator: "\n"))
            content.frame = NSRect(x: 12,y: 0,width: 370,height: 1100); scrollView.documentView = content
            let panel = NSView(frame: NSRect(x: 0,y: 0,width: 400,height: 250)); panel.addSubview(scrollView)
            let finish = NSButton(title: "ပြီးပြီ / Finish test",target: stopTarget,action: #selector(TestStopper.finish))
            finish.frame = NSRect(x: 200,y: 6,width: 185,height: 30); panel.addSubview(finish); window.contentView = panel
        } else { window.contentView = NSView() }
        app.finishLaunching(); window.center()
        window.makeKeyAndOrderFront(nil); app.activate(ignoringOtherApps: true)
        let collector = EventCollector()
        let testSource = CGEventSource(stateID: .privateState)!
        testSource.userData = EventCollector.testTag; testSource.localEventsSuppressionInterval = 0
        let mask = [CGEventType.otherMouseDown,.otherMouseUp,.scrollWheel].reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly, eventsOfInterest: mask, callback: { _,type,event,user in
            if let user { Unmanaged<EventCollector>.fromOpaque(user).takeUnretainedValue().record(type,event) }; return Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(collector).toOpaque()) else { print("FAIL: listener tap creation"); return 1 }
        let source = CFMachPortCreateRunLoopSource(nil,tap,0)!
        CFRunLoopAddSource(CFRunLoopGetMain(),source,.defaultMode); CGEvent.tapEnable(tap: tap,enable: true)
        let executor = ActionExecutor()
        let reportBox = HarnessReportBox()
        let latencyBox = HarnessLatencyBox()
        var runtime: InputRuntime?
        runtime = InputRuntime(report: { report in Task { @MainActor in reportBox.value = report } }, action: { request in Task { @MainActor in latencyBox.values.append((ProcessInfo.processInfo.systemUptime - request.recognizedAt) * 1000); executor.execute(request.mapping, alreadyInjected: request.alreadyInjected) } }, cancellation: { Task { @MainActor in executor.cancel() } }, pause: {}, drag: { _,_ in })
        var c = Configuration(); c.engineEnabled = true; c.globalDefaults.mappings = [.init(button: 3,action: .middleClick)]
        if physical { c.globalDefaults.mappings = (2...4).map { Mapping(button: $0,action: .middleClick) } }
        c.scroll.enabled = true; c.scroll.acceleration = 0
        runtime?.apply(c,bundleID: nil,magicMousePresent: false)
        pump(0.6)
        if physical {
            if calibration {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    let source = CGEventSource(stateID: .privateState)!
                    source.userData = EventCollector.testTag; source.localEventsSuppressionInterval = 0
                    for kind in [CGEventType.otherMouseDown,.otherMouseUp] {
                        let event = CGEvent(mouseEventSource: source,mouseType: kind,mouseCursorPosition: CGPoint(x: window.frame.midX,y: window.frame.midY),mouseButton: CGMouseButton(rawValue: 2)!)!
                        event.post(tap: .cgSessionEventTap)
                    }
                    let wheel = CGEvent(scrollWheelEvent2Source: source,units: .line,wheelCount: 1,wheel1: 2,wheel2: 0,wheel3: 0)!
                    wheel.setIntegerValueField(.scrollWheelEventIsContinuous,value: 0); wheel.post(tap: .cgSessionEventTap)
                }
            }
            let finishTimer = Timer(timeInterval: calibration ? 2 : 300,repeats: false) { _ in
                NSApplication.shared.stop(nil)
                if let wake = NSEvent.otherEvent(with: .applicationDefined,location: .zero,modifierFlags: [],timestamp: ProcessInfo.processInfo.systemUptime,windowNumber: 0,context: nil,subtype: 0,data1: 0,data2: 0) { NSApplication.shared.postEvent(wake,atStart: true) }
            }
            RunLoop.main.add(finishTimer,forMode: .common); withExtendedLifetime(stopTarget) { app.run() }; finishTimer.invalidate()
            runtime?.shutdown(); executor.cancel(); CFMachPortInvalidate(tap); window.orderOut(nil)
            let result: [String:Any] = ["engineStatus":reportBox.value.status,"engineActiveDuringTest":reportBox.value.active,"hardwareTest":!calibration,"deviceAttribution":false,"syntheticInputPostedByHarness":calibration,"auxiliaryButtonToMiddle":collector.syntheticButtons >= 2,"inputRecords":reportBox.value.records.filter { $0.kind == "button down" || $0.kind == "button up" || $0.kind == "recognized" }.map { ["kind":$0.kind,"detail":$0.detail,"action":$0.action ?? ""] },"wheelSmoothing":collector.syntheticScroll > 1,"syntheticButtonEvents":collector.syntheticButtons,"syntheticScrollEvents":collector.syntheticScroll,"ownEventsIgnored":reportBox.value.injectedIgnored,"runtimeEvents":reportBox.value.events,"maximumCallbackMS":reportBox.value.maximumCallbackMS,"scrollPhases":Array(Set(collector.scrollPhases)).sorted(),"momentumPhases":Array(Set(collector.momentumPhases)).sorted(),"note":calibration ? "Synthetic AppKit-loop calibration; not hardware evidence." : "User-operated input; no persistent device attribution. Temporary auxiliary buttons 2–4 mapping only; user configuration unchanged."]
            if let data = try? JSONSerialization.data(withJSONObject: result,options: [.prettyPrinted,.sortedKeys]) { print(String(decoding: data,as: UTF8.self)) }
            return collector.syntheticButtons >= 2 && collector.syntheticScroll > 1 ? 0 : 1
        }
        let target = CGPoint(x: window.frame.midX,y: (NSScreen.main?.frame.height ?? 900) - window.frame.midY)
        for type in [CGEventType.otherMouseDown,.otherMouseUp] {
            let event = CGEvent(mouseEventSource: testSource,mouseType: type,mouseCursorPosition: target,mouseButton: CGMouseButton(rawValue: 3)!)!
            event.setIntegerValueField(.eventSourceUserData,value: EventCollector.testTag); event.post(tap: .cgSessionEventTap); pump(0.08)
        }
        pump(0.25)
        let remapPassed = collector.syntheticButtons == 2 && collector.testButtons == 0
        let scroll = CGEvent(scrollWheelEvent2Source: testSource, units: .line,wheelCount: 1,wheel1: 2,wheel2: 0,wheel3: 0)!
        scroll.setIntegerValueField(.scrollWheelEventIsContinuous,value: 0); scroll.setIntegerValueField(.eventSourceUserData,value: EventCollector.testTag); scroll.post(tap: .cgSessionEventTap); pump(1.4)
        let smoothingPassed = collector.syntheticScroll > 1 && collector.testScroll == 0 && collector.scrollPhases.contains(1) && collector.scrollPhases.contains(4) && collector.momentumPhases.contains(1) && collector.momentumPhases.contains(3)
        let native = CGEvent(scrollWheelEvent2Source: testSource,units: .pixel,wheelCount: 1,wheel1: 20,wheel2: 0,wheel3: 0)!
        native.setIntegerValueField(.scrollWheelEventIsContinuous,value: 1); native.setIntegerValueField(.eventSourceUserData,value: EventCollector.testTag); native.post(tap: .cgSessionEventTap); pump(0.2)
        let nativeScrollPassed = collector.testScroll == 1
        let beforeUnmapped = collector.testButtons
        for type in [CGEventType.otherMouseDown,.otherMouseUp] {
            let unbound = CGEvent(mouseEventSource: testSource,mouseType: type,mouseCursorPosition: target,mouseButton: CGMouseButton(rawValue: 4)!)!
            unbound.post(tap: .cgSessionEventTap); pump(0.04)
        }
        let unmappedPassed = collector.testButtons == beforeUnmapped + 2
        runtime?.setCaptureArea(CGRect(x:target.x-10,y:target.y-10,width:20,height:20)); pump(0.1)
        let beforeCapture = collector.syntheticButtons, beforeCapturedNative = collector.testButtons
        for point in [target, CGPoint(x:target.x+40,y:target.y)] {
            for type in [CGEventType.otherMouseDown,.otherMouseUp] {
                let captured = CGEvent(mouseEventSource:testSource,mouseType:type,mouseCursorPosition:point,mouseButton:CGMouseButton(rawValue:3)!)!
                captured.post(tap:.cgSessionEventTap); pump(0.08)
            }
            pump(0.15)
        }
        let captureIsolationPassed = collector.syntheticButtons == beforeCapture+2 && collector.testButtons == beforeCapturedNative+2
        let oldCaptureOwner = UUID(), sheetCaptureOwner = UUID()
        let captureArea = CGRect(x:target.x-10,y:target.y-10,width:20,height:20)
        runtime?.setCaptureArea(captureArea, owner: oldCaptureOwner)
        runtime?.setCaptureArea(captureArea, owner: sheetCaptureOwner)
        runtime?.setCaptureArea(nil, owner: oldCaptureOwner); pump(0.1)
        let beforeOwnerSynthetic = collector.syntheticButtons, beforeOwnerNative = collector.testButtons
        for type in [CGEventType.otherMouseDown, .otherMouseUp] {
            let event = CGEvent(mouseEventSource:testSource,mouseType:type,mouseCursorPosition:target,mouseButton:CGMouseButton(rawValue:3)!)!
            event.post(tap:.cgSessionEventTap); pump(0.04)
        }
        let captureOwnerIsolationPassed = collector.syntheticButtons == beforeOwnerSynthetic && collector.testButtons == beforeOwnerNative + 2
        runtime?.setCaptureArea(nil); pump(0.1)
        let emergency = CGEvent(keyboardEventSource: testSource,virtualKey: 53,keyDown: true)!
        emergency.flags = [.maskControl,.maskAlternate,.maskCommand]; emergency.post(tap: .cgSessionEventTap)
        let emergencyUp = CGEvent(keyboardEventSource: testSource,virtualKey: 53,keyDown: false)!
        emergencyUp.flags = [.maskControl,.maskAlternate,.maskCommand]; emergencyUp.post(tap: .cgSessionEventTap)
        // The idle report timer can publish after two 250 ms ticks. Wait for
        // the observable state with a bound instead of racing a fixed delay.
        let pauseDeadline = Date().addingTimeInterval(1.5)
        while reportBox.value.status != "Emergency pause" && Date() < pauseDeadline { pump(0.05) }
        let emergencyPassed = reportBox.value.status == "Emergency pause" && !reportBox.value.active
        let beforePaused = collector.testButtons
        c.engineEnabled = false; runtime?.apply(c,bundleID: nil,magicMousePresent: false); pump(0.2)
        let event = CGEvent(mouseEventSource: testSource,mouseType: .otherMouseDown,mouseCursorPosition: target,mouseButton: CGMouseButton(rawValue: 3)!)!
        event.setIntegerValueField(.eventSourceUserData,value: EventCollector.testTag); event.post(tap: .cgSessionEventTap)
        let up = CGEvent(mouseEventSource: testSource,mouseType: .otherMouseUp,mouseCursorPosition: target,mouseButton: CGMouseButton(rawValue: 3)!)!
        up.setIntegerValueField(.eventSourceUserData,value: EventCollector.testTag); up.post(tap: .cgSessionEventTap); pump(0.4)
        let pausePassed = collector.testButtons == beforePaused + 2
        runtime?.shutdown(); pump(0.15); CFMachPortInvalidate(tap); CFRunLoopRemoveSource(CFRunLoopGetMain(),source,.defaultMode); window.orderOut(nil)
        let result: [String: Any] = ["actionDispatchMS":latencyBox.values,"captureOwnerIsolation":captureOwnerIsolationPassed,"captureAreaIsolation":captureIsolationPassed,"syntheticButtonRemap":remapPassed,"wheelSmoothing":smoothingPassed,"pausePassthrough":pausePassed,"syntheticButtons":collector.syntheticButtons,"syntheticScrollEvents":collector.syntheticScroll,"scrollPhases":Array(Set(collector.scrollPhases)).sorted(),"momentumPhases":Array(Set(collector.momentumPhases)).sorted(),"ownEventsIgnored":reportBox.value.injectedIgnored,"maximumCallbackMS":reportBox.value.maximumCallbackMS,"hardwareTest":false,"unmappedPassthrough":unmappedPassed,"nativeContinuousPreserved":nativeScrollPassed,"emergencyPause":emergencyPassed,"postEventAccess":CGPreflightPostEventAccess(),"engineStatus":reportBox.value.status,"runtimeEvents":reportBox.value.events,"listenerEvents":collector.total,"tags":Array(collector.tags).sorted()]
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted,.sortedKeys]) { print(String(decoding: data, as: UTF8.self)) }
        return captureOwnerIsolationPassed && captureIsolationPassed && remapPassed && smoothingPassed && pausePassed && unmappedPassed && nativeScrollPassed && emergencyPassed ? 0 : 1
    }
    private static func pump(_ time: Double) { RunLoop.current.run(until: Date().addingTimeInterval(time)) }
}
private final class EventCollector: @unchecked Sendable {
    static let testTag: Int64 = 0x474D54455354
    // This listener is scheduled only on the main CFRunLoop used by the harness.
    var total = 0
    var tags = Set<Int64>()
    var syntheticButtons = 0
    var testButtons = 0
    var syntheticScroll = 0
    var testScroll = 0
    var scrollPhases: [Int] = []
    var momentumPhases: [Int] = []
    func record(_ type: CGEventType, _ event: CGEvent) {
        let tag = event.getIntegerValueField(.eventSourceUserData)
        total += 1; tags.insert(tag)
        if type == .scrollWheel { if tag == syntheticTag { syntheticScroll += 1; scrollPhases.append(Int(event.getIntegerValueField(.scrollWheelEventScrollPhase))); momentumPhases.append(Int(event.getIntegerValueField(.scrollWheelEventMomentumPhase))) }; if tag == Self.testTag { testScroll += 1 } }
        else { if tag == syntheticTag { syntheticButtons += 1 }; if tag == Self.testTag { testButtons += 1 } }
    }
}

@MainActor private final class HarnessReportBox { var value = RuntimeReport() }

@MainActor enum HardwareObserver {
    static func run(seconds: Double) -> Int32 {
        guard AXIsProcessTrusted(), CGPreflightListenEventAccess() else { print("SKIP: input permissions unavailable"); return 77 }
        let app = NSApplication.shared; app.setActivationPolicy(.regular)
        let window = NSWindow(contentRect: NSRect(x: 250,y: 250,width: 520,height: 180),styleMask: [.titled,.closable],backing: .buffered,defer: false)
        window.title = "GlideMouse — Read-only mouse test"
        let label = NSTextField(wrappingLabelWithString: "30-second read-only test\nMove your mouse, click left/right/middle/side buttons, and scroll up/down.\nNo remapping is active in this test. Keyboard input and pointer locations are not recorded.")
        label.frame = NSRect(x: 24,y: 24,width: 470,height: 130); window.contentView?.addSubview(label)
        app.finishLaunching()
        window.center(); window.makeKeyAndOrderFront(nil); app.activate(ignoringOtherApps: true)
        let counts = HardwareCounts()
        let types: [CGEventType] = [.leftMouseDown,.leftMouseUp,.rightMouseDown,.rightMouseUp,.otherMouseDown,.otherMouseUp,.scrollWheel,.mouseMoved]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,place: .headInsertEventTap,options: .listenOnly,eventsOfInterest: mask,callback: { _,type,event,user in
            guard let user else { return Unmanaged.passUnretained(event) }
            let c = Unmanaged<HardwareCounts>.fromOpaque(user).takeUnretainedValue()
            let tag = event.getIntegerValueField(.eventSourceUserData)
            c.total += 1
            if tag == EventCollector.testTag { c.calibrationSeen = true }
            if tag == 0 {
                c.events += 1
                if type == .scrollWheel { c.wheel += 1 }
                else if type == .mouseMoved { c.moves += 1 }
                else { c.buttons[Int(event.getIntegerValueField(.mouseEventButtonNumber)),default: 0] += 1 }
            } else if tag != syntheticTag && tag != EventCollector.testTag { c.otherTagged += 1 }
            return Unmanaged.passUnretained(event)
        },userInfo: Unmanaged.passUnretained(counts).toOpaque()) else { return 1 }
        let source = CFMachPortCreateRunLoopSource(nil,tap,0)!
        CFRunLoopAddSource(CFRunLoopGetMain(),source,.defaultMode)
        CGEvent.tapEnable(tap: tap,enable: true)
        // A tagged zero-delta sentinel verifies the listener itself before interpreting absent human input.
        let calibrationSource = CGEventSource(stateID: .privateState)!
        calibrationSource.userData = EventCollector.testTag
        let sentinel = CGEvent(scrollWheelEvent2Source: calibrationSource,units: .pixel,wheelCount: 1,wheel1: 0,wheel2: 0,wheel3: 0)!
        sentinel.setIntegerValueField(.eventSourceUserData,value: EventCollector.testTag)
        DispatchQueue.main.async { sentinel.post(tap: .cgSessionEventTap) }
        let finishTimer = Timer(timeInterval: seconds,repeats: false) { _ in
            NSApplication.shared.stop(nil)
            if let wake = NSEvent.otherEvent(with: .applicationDefined,location: .zero,modifierFlags: [],timestamp: ProcessInfo.processInfo.systemUptime,windowNumber: 0,context: nil,subtype: 0,data1: 0,data2: 0) { NSApplication.shared.postEvent(wake,atStart: true) }
        }
        RunLoop.main.add(finishTimer,forMode: .common)
        app.run()
        finishTimer.invalidate()
        CFMachPortInvalidate(tap); CFRunLoopRemoveSource(CFRunLoopGetMain(),source,.defaultMode)
        window.orderOut(nil)
        let report: [String: Any] = ["listenerCalibrationPassed":counts.calibrationSeen,"totalObservedEvents":counts.total,"otherTaggedEvents":counts.otherTagged,"listenOnly":true,"deviceAttribution":false,"untaggedEvents":counts.events,"wheelEvents":counts.wheel,"pointerMoves":counts.moves,"buttonEventCounts":Dictionary(uniqueKeysWithValues: counts.buttons.map { (String($0.key),$0.value) }),"note":"Untagged observed input only; device identity and successful remapping are not proven."]
        if let data = try? JSONSerialization.data(withJSONObject: report,options: [.prettyPrinted,.sortedKeys]) { print(String(decoding: data,as: UTF8.self)) }
        return 0
    }
}
private final class HardwareCounts: @unchecked Sendable { var calibrationSeen = false; var total = 0; var otherTagged = 0; var events = 0; var wheel = 0; var moves = 0; var buttons: [Int:Int] = [:] }

@MainActor private final class TestStopper: NSObject, NSWindowDelegate {
    func windowWillClose(_ notification: Notification) { finish() }
    @objc func finish() {
        NSApplication.shared.stop(nil)
        if let wake = NSEvent.otherEvent(with: .applicationDefined,location: .zero,modifierFlags: [],timestamp: ProcessInfo.processInfo.systemUptime,windowNumber: 0,context: nil,subtype: 0,data1: 0,data2: 0) { NSApplication.shared.postEvent(wake,atStart: true) }
    }
}

@MainActor enum UsabilityHarness {
    static func run() -> Int32 {
        let model = AppModel(testing: true, rendering: true)
        model.devices = [MouseDevice(id: "test-fixture", name: "Test Mouse", transport: "Fixture", vendor: 0, product: 0, buttons: 5, stableIdentity: false, magicMouse: false)]
        let click = Mapping(button: 3, action: .back)
        let advanced = Mapping(trigger: .init(kind: .buttonDrag, button: 3), action: .forward)
        model.configuration.globalDefaults.mappings = [click, advanced]
        let original = model.configuration
        model.calibrate(button: 3, position: .lower)
        model.calibrate(button: 4, position: .upper)
        var result = ["calibrationKeepsMappings": model.configuration.globalDefaults.mappings == original.globalDefaults.mappings]
        model.calibrate(button: 0, position: .wheel)
        result["reservedCalibrationRejected"] = model.errorMessage != nil
        model.calibrate(button: 2, position: .wheel)
        result["validSaveClearsPreviousError"] = model.errorMessage == nil && model.calibratedButtons.count == 3
        let beforePreset = model.configuration
        model.preset("desktop")
        result["starterKeepsAdvanced"] = model.configuration.globalDefaults.mappings.contains(advanced)
        result["starterKeepsClickIdentity"] = model.configuration.globalDefaults.mappings.contains { $0.id == click.id && $0.action == .spaceLeft }
        model.undo()
        result["undoRestoresPreset"] = model.configuration == beforePreset
        model.saveMapping(Mapping(button: 3, action: .spaceRight))
        result["advancedAddMergesExistingTrigger"] = model.configuration.globalDefaults.mappings.count == 2 && model.configuration.globalDefaults.mappings.first { $0.id == click.id }?.action == .spaceRight
        let hold = Mapping(trigger: .init(kind: .buttonHold, button: 3), action: .missionControl)
        model.saveMapping(hold)
        let doubleClick = Mapping(trigger: .init(button: 3, clicks: 2), action: .showDesktop)
        model.saveSimpleMapping(doubleClick)
        result["doubleClickSavesSeparately"] = model.simpleMapping(button: 3, kind: .button, clicks: 2)?.id == doubleClick.id && model.simpleMapping(button: 3, kind: .button)?.action == .spaceRight && model.simpleMapping(button: 3, kind: .buttonHold)?.id == hold.id
        let beforeRemove = model.configuration
        if let click = model.simpleMapping(button: 3, kind: .button) { model.removeMapping(click.id) }
        result["removingClickKeepsHoldAndDrag"] = model.simpleMapping(button: 3, kind: .button) == nil && model.simpleMapping(button: 3, kind: .buttonHold)?.id == hold.id && model.effectiveProfile.mappings.contains(advanced) && model.simpleMapping(button: 3, kind: .button, clicks: 2)?.id == doubleClick.id
        model.undo()
        result["undoRestoresRemovedClick"] = model.configuration == beforeRemove
        model.removeMapping(hold.id)
        result["removingHoldKeepsClickAndDrag"] = model.simpleMapping(button: 3, kind: .button)?.action == .spaceRight && model.effectiveProfile.mappings.contains(advanced)
        model.undo()
        model.removeMapping(doubleClick.id)
        result["removingDoubleClickKeepsClickAndHold"] = model.simpleMapping(button: 3, kind: .button, clicks: 2) == nil && model.simpleMapping(button: 3, kind: .button)?.action == .spaceRight && model.simpleMapping(button: 3, kind: .buttonHold)?.id == hold.id
        model.undo()
        let global = model.configuration.globalDefaults
        let profile = Profile(name: "Test app", bundleID: "example.test")
        model.update { $0.profiles.append(profile) }; model.selectedProfileID = profile.id
        result["appInheritsGlobalClick"] = model.simpleMapping(button: 3, kind: .button)?.action == .spaceRight
        model.saveSimpleMapping(Mapping(button: 3, action: .missionControl))
        result["appSaveKeepsGlobal"] = model.configuration.globalDefaults == global && model.effectiveProfile.mappings.count == 1 && model.savedButton == 3
        if let own = model.effectiveProfile.mappings.first { model.removeMapping(own.id) }
        result["removingOverrideRestoresInheritance"] = model.simpleMapping(button: 3, kind: .button)?.action == .spaceRight
        let beforeSelection = model.configuration
        model.selectAppProfile(name: "Test app again", bundleID: "example.test")
        result["selectingExistingAppDoesNotDuplicateOrChangeSettings"] = model.configuration == beforeSelection && model.selectedProfileID == profile.id
        model.selectedProfileID = nil
        result["switchingToAllAppsOnlyChangesEditorScope"] = model.configuration == beforeSelection && model.isGlobal
        model.selectAppProfile(name: "New empty app", bundleID: "example.new")
        result["newAppStartsWithNoOverrides"] = model.effectiveProfile.mappings.isEmpty && model.configuration.globalDefaults == global
        result["otherAppsKeepGlobalAction"] = ProfileResolver.resolve(trigger: click.trigger, bundleID: "example.other", deviceID: nil, profiles: model.configuration.profiles + [model.configuration.globalDefaults])?.mapping.action == .spaceRight
        var appScroll = ScrollSettings(); appScroll.speed = 2.5
        model.mutateProfile { $0.mappings = [Mapping(button: 3, action: .missionControl)]; $0.scroll = appScroll }
        let removalTarget = model.effectiveProfile
        let unaffected = Profile(name: "Other app", bundleID: "example.untouched", mappings: [Mapping(button: 3, action: .back)], scroll: appScroll)
        model.update { $0.profiles.append(unaffected) }
        let beforeAppRemoval = model.configuration
        model.removeProfile()
        result["removingAppPreservesGlobalAndOtherProfiles"] = model.configuration.globalDefaults == beforeAppRemoval.globalDefaults && model.configuration.scroll == beforeAppRemoval.scroll && model.configuration.profiles == beforeAppRemoval.profiles.filter { $0.id != removalTarget.id }
        result["removingAppReturnsEditorToAllApps"] = model.selectedProfileID == nil && model.isGlobal && model.lastMessage.contains(removalTarget.name)
        result["removedAppUsesGlobalActionsAndScrolling"] = ProfileResolver.resolve(trigger: click.trigger, bundleID: removalTarget.bundleID, deviceID: nil, profiles: model.configuration.profiles + [model.configuration.globalDefaults])?.mapping.action == .spaceRight && ProfileResolver.scroll(bundleID: removalTarget.bundleID, deviceID: nil, configuration: model.configuration) == model.configuration.scroll
        model.undo()
        result["undoRestoresAppMappingsAndScrolling"] = model.configuration == beforeAppRemoval && ProfileResolver.resolve(trigger: click.trigger, bundleID: removalTarget.bundleID, deviceID: nil, profiles: model.configuration.profiles + [model.configuration.globalDefaults])?.mapping.action == .missionControl && ProfileResolver.scroll(bundleID: removalTarget.bundleID, deviceID: nil, configuration: model.configuration) == appScroll
        let beforeNoOpRemoval = model.configuration
        model.selectedProfileID = nil; model.removeProfile()
        result["allAppsCannotBeRemoved"] = model.configuration == beforeNoOpRemoval && model.isGlobal
        model.selectedProfileID = UUID()
        model.removeProfile()
        result["staleProfileRemovalKeepsSettings"] = model.configuration == beforeNoOpRemoval
        result["missingAppSelectionDisplaysAllApps"] = model.isGlobal && model.editingScopeName == model.text("All apps")
        model.completeSetup()
        result["setupCompletionPreservesMappings"] = model.configuration.usability?.setupCompleted == true && model.configuration.globalDefaults == global
        // Inline edits and app inheritance use the same mutation path as the new rows.
        let listModel = AppModel(testing: true, rendering: true)
        let input = Trigger(button: 3)
        listModel.configuration.globalDefaults.mappings = [Mapping(trigger: input, action: .back), Mapping(trigger: .init(kind: .buttonHold, button: 3), action: .missionControl)]
        let initialList = listModel.configuration
        listModel.setListAction(.spaceLeft, for: input)
        result["inlineActionSavesAndKeepsOtherGestures"] = listModel.listMapping(for: input)?.action == .spaceLeft && listModel.configuration.globalDefaults.mappings.count == 2
        listModel.undo()
        result["inlineActionUndoRestoresExactly"] = listModel.configuration == initialList
        listModel.selectAppProfile(name: "List app", bundleID: "example.list")
        let initialApp = listModel.configuration
        let globalID = listModel.configuration.globalDefaults.mappings[0].id
        result["listShowsInheritedRowsWithoutCopying"] = listModel.listTriggers(touch: false).count == 2 && listModel.effectiveProfile.mappings.isEmpty && !listModel.ownsListMapping(input)
        listModel.removeListAction(for: input)
        result["inheritedRemovalCannotDeleteGlobal"] = listModel.configuration == initialApp
        listModel.setListAction(.forward, for: input)
        result["inlineOverrideHasOwnIdentity"] = listModel.listMapping(for: input)?.id != globalID && listModel.configuration.globalDefaults == initialApp.globalDefaults
        result["inlineOverrideHasNoDuplicateRow"] = listModel.listTriggers(touch: false).count == 2 && listModel.ownsListMapping(input)
        listModel.removeListAction(for: input)
        result["inlineRemoveOverrideRestoresDefault"] = listModel.listMapping(for: input)?.action == .back && listModel.effectiveProfile.mappings.isEmpty
        listModel.undo()
        result["inlineRemovalUndoRestoresOverride"] = listModel.listMapping(for: input)?.action == .forward
        var shortcutOptions = ActionOptions(); shortcutOptions.keyCode = 49; shortcutOptions.modifiers = [.control]
        listModel.setListAction(.shortcut, for: input, options: shortcutOptions)
        result["inlineShortcutKeepsRecordedOptions"] = listModel.listMapping(for: input)?.options == shortcutOptions
        listModel.setListAction(.spaceRight, for: input)
        result["inlineNewActionClearsPreviousOptions"] = listModel.listMapping(for: input)?.options == ActionOptions()
        listModel.selectedProfileID = nil
        listModel.removeListAction(for: input)
        result["inlineTrashKeepsHoldAndOtherApp"] = listModel.configuration.globalDefaults.mappings.count == 1 && listModel.configuration.profiles[0].mappings[0].action == .spaceRight
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) { print(String(decoding: data, as: UTF8.self)) }
        return result.values.allSatisfy { $0 } ? 0 : 1
    }
}

@MainActor private final class HarnessLatencyBox { var values: [Double] = [] }

/// Exercise the real event-tap/recognition path while the main actor is blocked.
/// The injected desktop action is replaced by a recorder: no Spaces are changed.
@MainActor enum DesktopLatencyHarness {
    static func run() -> Int32 {
        guard AXIsProcessTrusted(), CGPreflightListenEventAccess() else { print("SKIP: macOS input permissions unavailable"); return 77 }
        let probe = DesktopLatencyProbe()
        let delivered = HarnessLatencyBox()
        let runtime = InputRuntime(report: { _ in }, action: { request in
            Task { @MainActor in delivered.values.append(request.alreadyInjected ? 1 : 0) }
        }, cancellation: {}, pause: {}, drag: { _,_ in }, fastDesktopAction: { action in
            probe.record(action); return true
        })
        var configuration = Configuration(); configuration.engineEnabled = true
        configuration.globalDefaults.mappings = [Mapping(button: 3, action: .spaceRight), Mapping(trigger: .init(kind: .buttonHold, button: 3), action: .missionControl)]
        runtime.apply(configuration, bundleID: nil, magicMousePresent: false)
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        let source = CGEventSource(stateID: .privateState)!
        source.userData = EventCollector.testTag; source.localEventsSuppressionInterval = 0
        let location = Injection.pointer()
        let down = CGEvent(mouseEventSource: source, mouseType: .otherMouseDown, mouseCursorPosition: location, mouseButton: CGMouseButton(rawValue: 3)!)!
        down.post(tap: .cgSessionEventTap)
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        let up = CGEvent(mouseEventSource: source, mouseType: .otherMouseUp, mouseCursorPosition: location, mouseButton: CGMouseButton(rawValue: 3)!)!
        let releasedAt = ProcessInfo.processInfo.systemUptime
        up.post(tap: .cgSessionEventTap)
        Thread.sleep(forTimeInterval: 0.20)
        let snapshot = probe.snapshot()
        let beforeMain = delivered.values.count
        RunLoop.main.run(until: Date().addingTimeInterval(0.08))
        let elapsed = snapshot.time.map { ($0 - releasedAt) * 1000 } ?? -1
        let passed = snapshot.actions == [.spaceRight] && elapsed >= 0 && elapsed < 100 && beforeMain == 0 && delivered.values == [1]
        runtime.shutdown(); RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        let result: [String: Any] = ["desktopActionWhileMainActorBlocked": passed, "releaseToDispatchMS": elapsed, "mainActorBlockedMS": 200, "exactlyOneAction": snapshot.actions.count == 1 && delivered.values == [1], "hardwareTest": false, "actualDesktopInjection": false]
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) { print(String(decoding: data, as: UTF8.self)) }
        return passed ? 0 : 1
    }
}
private final class DesktopLatencyProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var actions: [MouseAction] = []
    private var time: Double?
    func record(_ action: MouseAction) { lock.lock(); defer { lock.unlock() }; actions.append(action); time = ProcessInfo.processInfo.systemUptime }
    func snapshot() -> (actions: [MouseAction], time: Double?) { lock.lock(); defer { lock.unlock() }; return (actions, time) }
}

@MainActor enum DesktopKeyboardHarness {
    static func run() -> Int32 {
        guard AXIsProcessTrusted(), CGPreflightListenEventAccess() else { print("SKIP: macOS input permissions unavailable"); return 77 }
        let collector = DesktopKeyboardCollector()
        let mask = [CGEventType.keyDown, .keyUp, .flagsChanged].reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        // Swallow only our tagged test shortcuts, so the test cannot switch Spaces
        // or interfere with physical keys typed by the user.
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, user in
            guard event.getIntegerValueField(.eventSourceUserData) == syntheticTag, let user else { return Unmanaged.passUnretained(event) }
            let collector = Unmanaged<DesktopKeyboardCollector>.fromOpaque(user).takeUnretainedValue()
            if type == .keyDown || type == .keyUp { collector.arrows.append(Int(event.getIntegerValueField(.keyboardEventKeycode))); collector.flags.append(event.flags) }
            return nil
        }, userInfo: Unmanaged.passUnretained(collector).toOpaque()) else { print("FAIL: shortcut listener creation"); return 1 }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)!
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode); CGEvent.tapEnable(tap: tap, enable: true)
        let left = Injection.desktopAction(.spaceLeft), right = Injection.desktopAction(.spaceRight)
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        CFMachPortInvalidate(tap); CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        let required: CGEventFlags = [.maskControl, .maskSecondaryFn, .maskNumericPad]
        let passed = left && right && collector.arrows == [123, 123, 124, 124] && collector.flags.allSatisfy { $0.intersection(required) == required }
        let result: [String: Any] = ["desktopShortcutEvents": passed, "arrowKeyCodes": collector.arrows, "controlAndArrowIdentityPreserved": collector.flags.count == 4 && collector.flags.allSatisfy { $0.intersection(required) == required }, "hardwareTest": false, "shortcutsInterceptedBeforeDock": true]
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) { print(String(decoding: data, as: UTF8.self)) }
        return passed ? 0 : 1
    }
}
private final class DesktopKeyboardCollector: @unchecked Sendable {
    // Callback and inspection both run on the harness's main CFRunLoop.
    var arrows: [Int] = []
    var flags: [CGEventFlags] = []
}

// Documentation captures use isolated sample settings, never a customer's
// desktop, input injection or a recording of someone else's application.
extension UIHarness {
    static func renderTutorials(to directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSApplication.shared.setActivationPolicy(.accessory)
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 1440, height: 1080), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        var manifest: [[String: Any]] = []
        for language in [AppLanguage.en, .my] {
            let model = AppModel(testing: true, rendering: true)
            model.configuration.language = language
            model.devices = [MouseDevice(id: "tutorial-mouse", name: "Sample 5-button Mouse", transport: "USB", vendor: 0, product: 0, buttons: 5, stableIdentity: false, magicMouse: false)]
            model.configuration.usability = UsabilityPreferences(); model.configuration.usability?.setupCompleted = true
            let localized: (String, String) -> String = { en, my in language == .my ? my : en }
            func snapshot<V: View>(_ content: V) -> NSImage {
                let view = NSHostingView(rootView: content.preferredColorScheme(.light).environment(\.locale, Locale(identifier: language.resourceIdentifier)).background(Color(nsColor: .windowBackgroundColor)))
                view.sizingOptions = []; window.contentView = view; window.setContentSize(.init(width: 1040, height: 730)); view.setFrameSize(.init(width: 1040, height: 730)); window.orderFront(nil)
                RunLoop.current.run(until: Date().addingTimeInterval(0.12)); view.layoutSubtreeIfNeeded(); window.display()
                let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
                view.cacheDisplay(in: view.bounds, to: bitmap)
                return NSImage(data: bitmap.representation(using: .png, properties: [:])!)!
            }
            func scene<V: View>(_ topic: String, _ number: Int, title: String, en: String, my: String, content: V, seconds: Double = 7) {
                let image = snapshot(content)
                let name = "\(language.rawValue)-\(topic)-\(number).png"
                let caption = localized(en, my)
                let card = TutorialCard(image: image, title: title, caption: caption, step: number, language: language)
                let view = NSHostingView(rootView: card); view.sizingOptions = []; window.contentView = view
                window.setContentSize(.init(width: 1440, height: 1080)); view.setFrameSize(.init(width: 1440, height: 1080)); window.orderFront(nil)
                RunLoop.current.run(until: Date().addingTimeInterval(0.05)); view.layoutSubtreeIfNeeded(); window.display()
                save(view, directory.appendingPathComponent(name))
                manifest.append(["language": language.rawValue, "topic": topic, "step": number, "title": title, "caption": caption, "image": name, "seconds": seconds])
            }
            let setup = localized("01 · Start and label your mouse", "01 · စတင်သုံးရန်နှင့် ခလုတ်နေရာ သတ်မှတ်ရန်")
            scene("setup", 1, title: setup, en: "Open Settings → Language. Choose English, မြန်မာ or 简体中文.", my: "ဆက်တင်များ → ဘာသာစကား မှာ English၊ မြန်မာ၊ 简体中文 ကို ရွေးနိုင်ပါတယ်။", content: SettingsRoot(model: model, initialPage: .general))
            scene("setup", 2, title: setup, en: "Open Mouse setup. Allow Accessibility and Input Monitoring in macOS System Settings, then return and Refresh.", my: "Mouse သတ်မှတ်ရန် ကိုဖွင့်ပါ။ macOS မှာ Accessibility နဲ့ Input Monitoring ကို Allow လုပ်ပြီး ပြန်လာကာ Refresh နှိပ်ပါ။", content: MouseSetupWizard(model: model, initialStep: 0), seconds: 9)
            scene("setup", 3, title: setup, en: "In Identify buttons, start capture. Press one wheel or side button inside the box. Select its position and confirm.", my: "ခလုတ်နေရာ သတ်မှတ်ရန် မှာ capture စပါ။ အကွက်ထဲ၌ ဘီးခလုတ် သို့မဟုတ် ဘေးခလုတ်နှိပ်ပြီး နေရာရွေးကာ အတည်ပြုပါ။", content: MouseSetupWizard(model: model, initialStep: 1), seconds: 9)
            model.calibrate(button: 2, position: .wheel); model.calibrate(button: 3, position: .lower); model.calibrate(button: 4, position: .upper)
            scene("setup", 4, title: setup, en: "This sample mouse uses 3 = wheel, 4 = lower side, 5 = upper side. Your mouse may report different numbers.", my: "နမူနာ mouse မှာ 3 က ဘီးခလုတ်၊ 4 က အောက်ဘေးခလုတ်၊ 5 က အပေါ်ဘေးခလုတ်ပါ။ သင့် mouse မှာ နံပါတ်ကွာနိုင်ပါတယ်။", content: MouseSetupWizard(model: model, initialStep: 1), seconds: 9)
            scene("setup", 5, title: setup, en: "Keep your existing settings, or choose a starter setup. Only the listed inputs change; Undo can restore them.", my: "ရှိပြီးသား setting ကို ထိန်းထားနိုင်သလို အဆင်သင့် setting ကိုလည်း ရွေးနိုင်ပါတယ်။ ဖော်ပြထားတဲ့ ခလုတ်တွေပဲ ပြောင်းပြီး Undo ပြန်လုပ်နိုင်ပါတယ်။", content: MouseSetupWizard(model: model, initialStep: 2), seconds: 9)
            scene("setup", 6, title: setup, en: "Return to Buttons. Select a numbered label to edit its action. Enable GlideMouse when ready.", my: "ခလုတ်များ စာမျက်နှာကို ပြန်လာပါ။ နံပါတ်ပါတဲ့ label ကိုရွေးပြီး လုပ်ဆောင်ချက်ပြင်နိုင်ပါတယ်။ အဆင်သင့်ဖြစ်ရင် GlideMouse ကို ဖွင့်ပါ။", content: SettingsRoot(model: model))

            let buttons = localized("02 · Click, double click and hold", "02 · တချက်နှိပ်၊ နှစ်ချက်နှိပ်နှင့် ဖိထား")
            model.selectedButton = 3; model.selectedGesture = nil
            scene("buttons", 1, title: buttons, en: "Choose the lower-side label. Select Click once. The first control describes how YOU press the button.", my: "အောက်ဘေးခလုတ် label ကို ရွေးပြီး တချက်နှိပ် ကိုရွေးပါ။ ဒီရွေးချယ်မှုက သင်နှိပ်မယ့်ပုံစံကို ဆိုလိုပါတယ်။", content: SettingsRoot(model: model))
            var action = MouseAction.spaceLeft
            scene("buttons", 2, title: buttons, en: "Open the action chooser. Pick Desktop left. This is what the APP will do after your button press.", my: "လုပ်ဆောင်ချက်ရွေးတဲ့နေရာကို ဖွင့်ပြီး Desktop ဘယ်ဘက်သို့ ကို ရွေးပါ။ ဒီရွေးချယ်မှုက app က လုပ်ပေးမယ့်အရာပါ။", content: ActionChooser(model: model, action: Binding(get: { action }, set: { action = $0 }), triggerKind: .button))
            model.saveSimpleMapping(Mapping(button: 3, action: .spaceLeft))
            scene("buttons", 3, title: buttons, en: "Save for all apps. Lower-side single click now has Desktop left as its saved action.", my: "App အားလုံးအတွက် သိမ်းရန် ကိုနှိပ်ပါ။ အောက်ဘေးခလုတ် တချက်နှိပ်အတွက် Desktop ဘယ်ဘက်သို့ ကို သိမ်းထားပါပြီ။", content: SettingsRoot(model: model))
            model.selectedButton = 4; model.saveSimpleMapping(Mapping(button: 4, action: .spaceRight))
            scene("buttons", 4, title: buttons, en: "Choose the upper-side label. Set Click once → Desktop right, then Save for all apps.", my: "အပေါ်ဘေးခလုတ်ကို ရွေးပြီး တချက်နှိပ် → Desktop ညာဘက်သို့ ကို ရွေးကာ သိမ်းပါ။", content: SettingsRoot(model: model))
            model.selectedButton = 3; model.selectedGesture = .init(kind: .buttonHold, button: 3)
            model.saveSimpleMapping(Mapping(trigger: .init(kind: .buttonHold, button: 3), action: .missionControl))
            scene("buttons", 5, title: buttons, en: "Choose Hold → Mission Control and save. The same button can have separate click and hold actions.", my: "ဖိထား → Window အားလုံး ကြည့်ရန် ကိုရွေးပြီး သိမ်းပါ။ ခလုတ်တခုတည်းမှာ တချက်နှိပ်နဲ့ ဖိထားအတွက် သီးခြားသတ်မှတ်နိုင်ပါတယ်။", content: SettingsRoot(model: model))
            model.selectedGesture = .init(kind: .button, button: 3, clicks: 2)
            model.saveSimpleMapping(Mapping(trigger: .init(kind: .button, button: 3, clicks: 2), action: .quickLook))
            scene("buttons", 6, title: buttons, en: "Double click can use a third action. It adds a short wait so single and double clicks can be distinguished.", my: "နှစ်ချက်နှိပ်အတွက်လည်း သီးခြားသတ်မှတ်နိုင်ပါတယ်။ တချက်နှိပ်နဲ့ နှစ်ချက်နှိပ်ကို ခွဲဖို့ ခဏစောင့်ရတာကြောင့် တချက်နှိပ်မှာ အနည်းငယ်နှောင့်နှေးနိုင်ပါတယ်။", content: SettingsRoot(model: model), seconds: 9)
            model.selectedButton = 0; model.selectedGesture = nil
            scene("buttons", 7, title: buttons, en: "Buttons 1 and 2 support double click and hold. Ordinary left/right clicks and dragging stay available.", my: "ဘယ်ခလုတ် 1 နဲ့ ညာခလုတ် 2 မှာ နှစ်ချက်နှိပ်နဲ့ ဖိထားကို သတ်မှတ်နိုင်ပါတယ်။ ပုံမှန် click နဲ့ drag တွေက ဆက်သုံးနိုင်ပါတယ်။", content: SettingsRoot(model: model))

            let profiles = localized("03 · Different actions in one app", "03 · App တခုအတွက် သီးခြားလုပ်ဆောင်ချက်")
            model.selectedButton = 3; model.selectedGesture = nil
            scene("profiles", 1, title: profiles, en: "All apps is the default. Add an app only when it needs different actions.", my: "App အားလုံးအတွက် က ပုံမှန် setting ပါ။ သီးခြားလုပ်ဆောင်ချက်လိုတဲ့ app ရှိမှ App ထည့်ရန် ကို သုံးပါ။", content: SettingsRoot(model: model))
            model.selectAppProfile(name: "Safari", bundleID: "com.apple.Safari")
            scene("profiles", 2, title: profiles, en: "Choose Add app and select Safari.app. The editing scope now says Safari. Existing buttons inherit All apps.", my: "App ထည့်ရန် မှာ Safari.app ကိုရွေးပါ။ အပေါ်က ပြင်နေသော app မှာ Safari ဖြစ်လာပြီး ခလုတ်တွေက ပုံမှန် setting ကို အရင်ဆက်သုံးပါတယ်။", content: SettingsRoot(model: model), seconds: 9)
            model.saveSimpleMapping(Mapping(button: 3, action: .back))
            scene("profiles", 3, title: profiles, en: "Save for this app: lower-side click → Back. It works in Safari; other apps still use Desktop left.", my: "ဒီ app အတွက် သိမ်းရန် နဲ့ အောက်ဘေးခလုတ် → နောက်ပြန် ကို သိမ်းပါ။ Safari မှာသာ သက်ရောက်ပြီး အခြား app တွေမှာ Desktop ဘယ်ဘက်သို့ ပဲ ဆက်သုံးပါတယ်။", content: SettingsRoot(model: model), seconds: 10)
            scene("profiles", 4, title: profiles, en: "Advanced → App-specific settings lists the actions used by the selected app, including inherited defaults.", my: "အဆင့်မြင့် → App အလိုက် ဆက်တင်များ မှာ ရွေးထားတဲ့ app အတွက် သုံးမယ့်လုပ်ဆောင်ချက်နဲ့ ပုံမှန် setting က ဆက်ယူထားတာတွေကို ကြည့်နိုင်ပါတယ်။", content: SettingsRoot(model: model, initialPage: .profiles))
            model.removeProfile()
            scene("profiles", 5, title: profiles, en: "Remove app deletes its GlideMouse setup, not the installed app. All apps defaults apply again.", my: "App ဖြုတ်ရန် က GlideMouse ထဲက setting ကိုပဲ ဖြုတ်တာပါ။ App ကို uninstall မလုပ်ပါ။ ပုံမှန် setting ပြန်သက်ရောက်ပါတယ်။", content: SettingsRoot(model: model))
            model.undo()
            scene("profiles", 6, title: profiles, en: "Undo restores the app setup. Choose Safari again from the scope dropdown to continue editing it.", my: "အရင်အတိုင်း ပြန်ထားရန် ကိုနှိပ်ရင် app setting ပြန်ရပါတယ်။ ဆက်ပြင်ချင်ရင် အပေါ် dropdown မှာ Safari ကို ပြန်ရွေးပါ။", content: SettingsRoot(model: model))
            model.selectedProfileID = nil

            let scrolling = localized("04 · Scrolling, response and language", "04 · Scroll၊ နှိပ်ချိန်နှင့် ဘာသာစကား")
            scene("scrolling", 1, title: scrolling, en: "Open Scrolling. Choose Standard or Smooth first; use Custom only for fine adjustments.", my: "စာမျက်နှာ ရွေ့ပုံ ကိုဖွင့်ပြီး ပုံမှန် ဒါမှမဟုတ် ချောမွေ့ ကို အရင်ရွေးပါ။ သီးခြားချိန်ဖို့လိုမှ အသေးစိတ်ပြင်ပါ။", content: SettingsRoot(model: model, initialPage: .scrolling))
            model.update { $0.scroll = ScrollPreset.smooth.applying(to: $0.scroll); $0.scroll.speed = 1.6 }
            scene("scrolling", 2, title: scrolling, en: "Speed controls distance per wheel step. Higher moves farther. Direction switches reverse the scroll direction.", my: "အမြန်နှုန်းက ဘီးတချက်လှည့်ရင် ရွေ့မယ့်အကွာအဝေးပါ။ တန်ဖိုးတိုးရင် ပိုရွေ့ပါတယ်။ ဦးတည်ချက်မှာ scroll ပြောင်းပြန်ကို ရွေးနိုင်ပါတယ်။", content: SettingsRoot(model: model, initialPage: .scrolling), seconds: 9)
            model.selectedProfileID = model.configuration.profiles.first?.id
            scene("scrolling", 3, title: scrolling, en: "In an app profile, enable its scrolling override to customize only that app. Leave it off to inherit All apps.", my: "App တခုရွေးထားချိန် သီးခြား scroll setting ကို ဖွင့်မှ အဲဒီ app အတွက် ပြင်နိုင်ပါတယ်။ ပိတ်ထားရင် ပုံမှန် setting ကို ဆက်သုံးပါတယ်။", content: SettingsRoot(model: model, initialPage: .scrolling), seconds: 9)
            model.selectedProfileID = nil
            scene("scrolling", 4, title: scrolling, en: "Advanced → Button response: choose Fast, Normal or Relaxed. Fine-tune hold/double-click timing only if needed.", my: "အဆင့်မြင့် → ခလုတ်နှိပ်ချိန် မှာ မြန်၊ ပုံမှန်၊ ဖြည်း ကို ရွေးနိုင်ပါတယ်။ လိုအပ်မှ ဖိထားချိန်နဲ့ နှစ်ချက်နှိပ်ကြားကာလကို အသေးစိတ်ချိန်ပါ။", content: SettingsRoot(model: model, initialPage: .tuning), seconds: 9)
            scene("scrolling", 5, title: scrolling, en: "Settings contains language, appearance, login launch and updates. Show action name on screen is optional.", my: "ဆက်တင်များ မှာ ဘာသာစကား၊ အရောင်ပုံစံ၊ Mac စဖွင့်ချိန် run ရန်နဲ့ update တွေရှိပါတယ်။ Screen ပေါ် action နာမည်ပြတာကို ကြိုက်မှဖွင့်ပါ။", content: SettingsRoot(model: model, initialPage: .general), seconds: 9)
            scene("scrolling", 6, title: scrolling, en: "About contains developer contact and Buy Me a Coffee. Export/import your settings before moving to another Mac.", my: "About မှာ developer ကို ဆက်သွယ်ရန်နဲ့ Buy Me a Coffee ရှိပါတယ်။ တခြား Mac သို့ရွှေ့ဖို့ setting ကို Export / Import လုပ်နိုင်ပါတယ်။", content: AboutGlideMouse(model: model).padding(30))

            let advanced = localized("05 · Shortcuts, delete, Undo and help", "05 · Shortcut၊ ဖျက်ရန်၊ Undo နှင့် အကူအညီ")
            var options = ActionOptions(); options.keyCode = 8; options.modifiers = .command
            let shortcut = Mapping(trigger: .init(kind: .button, button: 2), action: .shortcut, options: options)
            scene("shortcuts", 1, title: advanced, en: "Choose Keyboard shortcut as the action. Record while its field is focused; this sample uses ⌘C.", my: "လုပ်ဆောင်ချက်မှာ Keyboard shortcut ကိုရွေးပြီး မှတ်တမ်းတင်တဲ့အကွက်ကို focus လုပ်ထားကာ နှိပ်ပါ။ ဒီနမူနာမှာ ⌘C ကို သုံးထားပါတယ်။", content: MappingEditor(model: model, mapping: shortcut), seconds: 9)
            var code: UInt16 = 8; var mods: Modifiers = .command; var recording = true
            scene("shortcuts", 2, title: advanced, en: "Press Record shortcut, focus this field, then press the key combination. It stops recording after one shortcut.", my: "Shortcut မှတ်တမ်းတင်ရန် ကိုနှိပ်ပြီး ဒီအကွက်မှာ ခလုတ်တွဲနှိပ်ပါ။ Shortcut တခု ဖမ်းမိတာနဲ့ မှတ်တမ်းတင်တာ ရပ်ပါမယ်။", content: ShortcutRecorder(model: model, keyCode: Binding(get: { code }, set: { code = $0 }), modifiers: Binding(get: { mods }, set: { mods = $0 }), recording: Binding(get: { recording }, set: { recording = $0 })).frame(width: 600, height: 40).padding(40))
            model.selectedButton = 2; model.selectedGesture = nil; model.saveSimpleMapping(shortcut)
            scene("shortcuts", 3, title: advanced, en: "Save the shortcut. Normal actions outside the mouse capture box keep working while you edit a mapping.", my: "Shortcut ကို သိမ်းပါ။ Mouse input ဖမ်းတဲ့အကွက်အပြင်ဘက်မှာ ရှိပြီးသားလုပ်ဆောင်ချက်တွေကို mapping ပြင်နေချိန်လည်း သုံးနိုင်ပါတယ်။", content: SettingsRoot(model: model))
            model.selectedButton = 3
            scene("shortcuts", 4, title: advanced, en: "To delete, select the button AND its press type, then Remove action. Click, double click and hold are separate.", my: "ဖျက်ဖို့ ခလုတ်နဲ့ နှိပ်ပုံကို အရင်ရွေးပြီး လုပ်ဆောင်ချက် ဖျက်ရန် ကိုနှိပ်ပါ။ တချက်နှိပ်၊ နှစ်ချက်နှိပ်နဲ့ ဖိထားက သီးခြားဖြစ်ပါတယ်။", content: SettingsRoot(model: model), seconds: 9)
            if let mapping = model.simpleMapping(button: 3, kind: .button) { model.removeMapping(mapping.id) }
            scene("shortcuts", 5, title: advanced, en: "The single-click action is removed. Undo restores it; other gestures on this button remain saved.", my: "တချက်နှိပ်လုပ်ဆောင်ချက်ကို ဖျက်ထားပါပြီ။ Undo နဲ့ ပြန်ယူနိုင်ပြီး ဒီခလုတ်ရဲ့ အခြားနှိပ်ပုံ setting တွေကို မဖျက်ပါ။", content: SettingsRoot(model: model))
            model.undo()
            scene("shortcuts", 6, title: advanced, en: "Help → Troubleshooting checks permissions. Technical details are collapsed; expand them only when needed.", my: "Help → ပြဿနာဖြေရှင်းရန် မှာ permission စစ်နိုင်ပါတယ်။ နည်းပညာအသေးစိတ်ကို ပိတ်ထားပြီး လိုအပ်မှ ချဲ့ကြည့်ပါ။", content: TroubleshootingSheet(model: model))
            scene("shortcuts", 7, title: advanced, en: "Need to stop quickly? Press Control + Option + Command + Escape, or Pause from the menu bar.", my: "အမြန်ရပ်ချင်ရင် Control + Option + Command + Escape နှိပ်ပါ။ Menu bar ကနေ ခေတ္တရပ်ထား လို့လည်း ရပါတယ်။", content: SettingsRoot(model: model))
        }
        if let data = try? JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys]) { try? data.write(to: directory.appendingPathComponent("manifest.json")) }
        window.orderOut(nil)
    }
}
private struct TutorialCard: View {
    let image: NSImage
    let title: String
    let caption: String
    let step: Int
    let language: AppLanguage
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("GlideMouse").font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.blue)
                    Text(title).font(.system(size: 28, weight: .bold))
                }
                Spacer()
                Text(language == .my ? "နမူနာ setting ဖြင့် လမ်းညွှန်" : "Guided demo · sample settings").font(.system(size: 16)).foregroundStyle(.secondary)
            }.frame(height: 82)
            Image(nsImage: image).resizable().scaledToFit().frame(width: 1280, height: 768).background(.white).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.12))).shadow(color: .black.opacity(0.08), radius: 12, y: 4)
            HStack(alignment: .top, spacing: 16) {
                Text(String(step)).font(.system(size: 24, weight: .bold)).foregroundStyle(.white).frame(width: 44, height: 44).background(Color.blue, in: RoundedRectangle(cornerRadius: 12))
                Text(caption).font(.system(size: language == .my ? 24 : 25, weight: .medium)).lineSpacing(5).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
            }.padding(18).frame(width: 1280, height: 158, alignment: .topLeading).background(Color.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
        }.padding(.horizontal, 80).padding(.vertical, 22).frame(width: 1440, height: 1080).background(Color(red: 0.95, green: 0.97, blue: 1)).foregroundStyle(.black)
    }
}

extension UIHarness {
    static func configureMappingListFixture(_ model: AppModel) {
        model.devices = [MouseDevice(id: "list-fixture", name: "Sample Mouse", transport: "Fixture", vendor: 0, product: 0, buttons: 5, stableIdentity: false, magicMouse: false)]
        model.accessibility = true; model.inputMonitoring = true
        model.configuration.globalDefaults.mappings = [Mapping(button: 4, action: .spaceRight), Mapping(button: 3, action: .spaceLeft), Mapping(trigger: .init(kind: .buttonHold, button: 3), action: .missionControl)] + MagicMouseCatalog.defaults
        model.configuration.profiles = [Profile(name: "Safari", bundleID: "com.apple.Safari")]
        model.configuration.engineEnabled = false; model.configuration.touchEnabled = false
        var preferences = UsabilityPreferences(); preferences.setupCompleted = true
        if let identity = model.calibrationIdentity { preferences.calibrations = [MouseCalibration(identity: identity, buttons: [.init(button: 2, position: .wheel), .init(button: 3, position: .lower), .init(button: 4, position: .upper)])] }
        model.configuration.usability = preferences
    }
    static func renderMappingList(to directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let model = AppModel(testing: true, rendering: true)
        configureMappingListFixture(model)
        NSApplication.shared.setActivationPolicy(.accessory)
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 1040, height: 760), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        for language in AppLanguage.allCases {
            model.configuration.language = language
            for width in [820, 1040, 1440] {
                for page in [SettingsPage.mappings, .magic, .general] {
                    let height = page == .mappings ? 760 : 920
                    let size = NSSize(width: width, height: height)
                    window.setContentSize(size)
                    let view = NSHostingView(rootView: SettingsRoot(model: model, initialPage: page).preferredColorScheme(.light))
                    view.sizingOptions = []; window.contentView = view; view.setFrameSize(size); window.orderFront(nil)
                    RunLoop.current.run(until: Date().addingTimeInterval(0.15)); view.layoutSubtreeIfNeeded(); window.display()
                    save(view, directory.appendingPathComponent("\(language.rawValue)-\(page == .magic ? "magic" : page == .general ? "settings" : "buttons")-\(width).png"))
                }
            }
        }
        model.configuration.language = .my; model.selectedProfileID = model.configuration.profiles.first?.id
        for appearance in [ColorScheme.light, .dark] {
            let size = NSSize(width: 1040, height: 760); window.setContentSize(size)
            let view = NSHostingView(rootView: SettingsRoot(model: model).preferredColorScheme(appearance))
            view.sizingOptions = []; window.contentView = view; view.setFrameSize(size); window.orderFront(nil)
            RunLoop.current.run(until: Date().addingTimeInterval(0.15)); view.layoutSubtreeIfNeeded(); window.display()
            save(view, directory.appendingPathComponent("my-app-\(appearance == .dark ? "dark" : "light").png"))
        }
        window.orderOut(nil)
    }
}
