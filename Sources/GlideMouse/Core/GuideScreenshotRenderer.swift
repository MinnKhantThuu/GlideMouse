import AppKit
import SwiftUI
import MouseCore

/// Documentation only: isolated settings, a fixed appearance, no input runtime.
@MainActor enum GuideScreenshotRenderer {
    static func render(to directory: URL) -> Bool {
        do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        catch { return false }
        NSApplication.shared.setActivationPolicy(.accessory)
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 1040, height: 760), styleMask: [.titled], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .aqua)
        var written: [String] = []
        func capture<V: View>(_ content: V, model: AppModel, name: String, width: CGFloat, height: CGFloat, recordedShortcut: Bool = false) -> Bool {
            let size = NSSize(width: width, height: height)
            let view = NSHostingView(rootView: content.preferredColorScheme(.light).environment(\.locale, Locale(identifier: model.configuration.language.resourceIdentifier)).background(Color.white))
            view.appearance = NSAppearance(named: .aqua)
            view.sizingOptions = []
            window.contentView = view; window.setContentSize(size); view.setFrameSize(size)
            window.orderFront(nil)
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            if recordedShortcut {
                func recorder(in view: NSView) -> ShortcutRecorder.RecorderView? {
                    if let recorder = view as? ShortcutRecorder.RecorderView { return recorder }
                    return view.subviews.compactMap { recorder(in: $0) }.first
                }
                // Feed the isolated view's binding callback; never post a key event.
                guard let field = recorder(in: view) else { return false }
                field.recorded?(40, .command)
                RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            }
            view.layoutSubtreeIfNeeded(); window.display()
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return false }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            guard let data = bitmap.representation(using: .png, properties: [:]) else { return false }
            let file = model.configuration.language.rawValue + "-" + name + ".png"
            do {
                try data.write(to: directory.appendingPathComponent(file))
                if let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 1]) {
                    try jpeg.write(to: directory.appendingPathComponent(model.configuration.language.rawValue + "-" + name + ".jpg"))
                }
                written.append(file); return true
            }
            catch { return false }
        }
        for language in AppLanguage.allCases {
            let model = AppModel(testing: true, rendering: true)
            UIHarness.configureMappingListFixture(model)
            model.configuration.language = language
            model.configuration.appearance = .light
            model.selectedButton = nil
            guard !model.hasInputRuntime else { return false }
            guard capture(SettingsRoot(model: model), model: model, name: "buttons", width: 1040, height: 760),
                  capture(AddInputSheet(model: model, touch: false, buttons: [0,1,2,3,4]), model: model, name: "add-button", width: 540, height: 660) else { return false }
            model.selectedButton = 3
            guard capture(AddInputSheet(model: model, touch: false, buttons: [0,1,2,3,4]), model: model, name: "press-type", width: 540, height: 660),
                  capture(ActionChooser(model: model, action: .constant(.spaceLeft), triggerKind: .button), model: model, name: "actions", width: 500, height: 560) else { return false }
            model.selectedProfileID = model.configuration.profiles.first?.id
            model.setListAction(.back, for: Trigger(button: 3))
            guard capture(SettingsRoot(model: model), model: model, name: "profiles", width: 1040, height: 760) else { return false }
            model.selectedProfileID = nil
            var options = ActionOptions(); options.keyCode = 40; options.modifiers = .command
            let shortcut = Mapping(trigger: Trigger(button: 3, clicks: 2), action: .shortcut, options: options)
            model.setListAction(.shortcut, for: shortcut.trigger, options: options)
            guard capture(ActionDetailsSheet(model: model, mapping: shortcut), model: model, name: "shortcut", width: 480, height: 240, recordedShortcut: true),
                  capture(SettingsRoot(model: model, initialPage: .scrolling), model: model, name: "scrolling", width: 1040, height: 760),
                  capture(SettingsRoot(model: model, initialPage: .general), model: model, name: "settings", width: 1040, height: 920) else { return false }
            guard !model.hasInputRuntime else { return false }
        }
        window.orderOut(nil)
        let report: [String: Any] = ["appearance": "light", "inputRuntimeCreated": false, "files": written]
        guard let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) else { return false }
        do { try data.write(to: directory.appendingPathComponent("manifest.json")); return true }
        catch { return false }
    }
}
