import Foundation
import Combine
import Sparkle

@MainActor final class UpdateController: ObservableObject {
    private var controller: SPUStandardUpdaterController?
    private var observation: AnyCancellable?
    @Published private(set) var canCheck = false
    @Published private(set) var automaticallyDownloads = false
    var configured: Bool { controller != nil }
    init(enabled: Bool = true) {
        guard enabled, let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              let url = URL(string: feed), url.scheme == "https", url.host != nil,
              let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              Data(base64Encoded: key)?.count == 32 else { return }
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
    }
    func start(automaticChecks: Bool) {
        guard let updater = controller?.updater else { return }
        updater.automaticallyChecksForUpdates = automaticChecks
        automaticallyDownloads = updater.automaticallyDownloadsUpdates
        observation = updater.publisher(for: \.canCheckForUpdates).receive(on: DispatchQueue.main).sink { [weak self] value in
            MainActor.assumeIsolated { self?.canCheck = value }
        }
        do { try updater.start() } catch { canCheck = false }
    }
    func setAutomaticChecks(_ enabled: Bool) { controller?.updater.automaticallyChecksForUpdates = enabled }
    func setAutomaticDownloads(_ enabled: Bool) {
        guard let updater = controller?.updater else { return }
        updater.automaticallyDownloadsUpdates = enabled
        automaticallyDownloads = updater.automaticallyDownloadsUpdates
    }
    func check() { if canCheck { controller?.checkForUpdates(nil) } }
}
