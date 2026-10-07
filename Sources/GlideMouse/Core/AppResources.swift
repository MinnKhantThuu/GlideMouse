import Foundation
import AppKit

enum AppResources {
    /// One source for About, the window footer and exported diagnostics.
    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development" }
    static var developerName: String { Bundle.main.object(forInfoDictionaryKey: "GMDeveloperName") as? String ?? "Minn Khant Thu" }
    static var supportURL: URL? { developerURL(for: "GMSupportURL") }
    static var emailURL: URL? { developerURL(for: "GMEmailURL") }
    static var websiteURL: URL? { developerURL(for: "GMWebsiteURL") }
    private static func developerURL(for key: String) -> URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              let url = URL(string: value),
              (url.scheme == "https" && url.host != nil) || (url.scheme == "mailto" && !url.path.isEmpty) else { return nil }
        return url
    }
    @MainActor static let mouseIllustration: NSImage? = bundle.url(forResource: "MouseIllustration", withExtension: "png").flatMap { NSImage(contentsOf: $0) }
    static var bundle: Bundle {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle.main
        #endif
    }
}
