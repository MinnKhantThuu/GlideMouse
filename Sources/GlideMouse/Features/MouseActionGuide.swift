import SwiftUI
import WebKit

/// A local instructional page: no real mouse capture, injected input or network.
struct MouseActionGuide: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        MouseActionGuideContent(language: model.configuration.language.resourceIdentifier,
                               dark: colorScheme == .dark,
                               title: model.text("How mouse actions work"),
                               done: model.text("Done"), close: { dismiss() })
    }
}

/// This preview deliberately never constructs AppModel, InputRuntime or a device
/// registry. Animation QA must not register an event tap or probe touch hardware.
struct MouseActionGuidePreview: App {
    private let language: String = {
        guard let i = CommandLine.arguments.firstIndex(of: "--guide-language"),
              CommandLine.arguments.count > i + 1 else {
            return Bundle.main.object(forInfoDictionaryKey: "GMGuidePreviewLanguage") as? String ?? "en"
        }
        let value = CommandLine.arguments[i + 1]
        return value == "zh" ? "zh-Hans" : ["en", "my", "zh-Hans"].contains(value) ? value : "en"
    }()
    private func text(_ key: String) -> String {
        let bundle = AppResources.bundle.path(forResource: language, ofType: "lproj")
            .flatMap { Bundle(path: $0) } ?? AppResources.bundle
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
    var body: some Scene {
        WindowGroup("GlideMouse — Mouse guide") {
            MouseActionGuideContent(language: language, dark: nil,
                                   title: text("How mouse actions work"), done: text("Done"),
                                   close: { NSApplication.shared.terminate(nil) })
                .onAppear { NSApplication.shared.activate(ignoringOtherApps: true) }
        }.defaultSize(width: 1040, height: 730)
    }
}

private struct MouseActionGuideContent: View {
    var language: String
    var dark: Bool?
    var title: String
    var done: String
    var close: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Button(done, action: close).keyboardShortcut(.cancelAction)
            }.padding(18)
            Divider()
            OfflineMouseGuide(language: language, dark: dark ?? (colorScheme == .dark))
        }.frame(minWidth: 740, idealWidth: 900, minHeight: 570, idealHeight: 690)
    }
}

private struct OfflineMouseGuide: NSViewRepresentable {
    var language: String
    var dark: Bool
    func makeCoordinator() -> Coordinator { Coordinator(language: language, dark: dark) }
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // The guide has no account, cookies, network requests or persistent state.
        configuration.websiteDataStore = .nonPersistent()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        if let folder = AppResources.bundle.url(forResource: "MouseGuide", withExtension: nil) {
            context.coordinator.folder = folder
            view.loadFileURL(folder.appendingPathComponent("guide.html"), allowingReadAccessTo: folder)
        }
        return view
    }
    func updateNSView(_ view: WKWebView, context: Context) {
        context.coordinator.language = language
        context.coordinator.dark = dark
        if !view.isLoading { context.coordinator.apply(to: view) }
    }
    final class Coordinator: NSObject, WKNavigationDelegate {
        var language: String
        var dark: Bool
        var folder: URL?
        private var hasLoaded = false
        private var appliedLanguage: String?
        private var appliedDark: Bool?
        init(language: String, dark: Bool) { self.language = language; self.dark = dark }
        func apply(to view: WKWebView) {
            guard hasLoaded, language != appliedLanguage || dark != appliedDark else { return }
            guard let encoded = try? JSONSerialization.data(withJSONObject: [language, dark ? "dark" : "light"]),
                  let arguments = String(data: encoded, encoding: .utf8) else { return }
            appliedLanguage = language
            appliedDark = dark
            view.evaluateJavaScript("window.setGuidePreferences && window.setGuidePreferences(...\(arguments))", completionHandler: nil)
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            hasLoaded = true
            appliedLanguage = nil
            appliedDark = nil
            apply(to: webView)
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url, let folder,
                  url.isFileURL, url.standardizedFileURL.path.hasPrefix(folder.standardizedFileURL.path + "/") else {
                decisionHandler(.cancel); return
            }
            decisionHandler(.allow)
        }
    }
}
