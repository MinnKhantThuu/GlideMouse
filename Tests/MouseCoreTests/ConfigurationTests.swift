import XCTest
@testable import MouseCore
final class ConfigurationTests: XCTestCase {
    func testLanguageSurvivesSaveLoadAndImport() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ConfigurationStore(url: directory.appendingPathComponent("settings.json"))
        for language in AppLanguage.allCases {
            var configuration = Configuration()
            configuration.language = language
            configuration.globalDefaults.mappings = [Mapping(button: 3, action: .spaceLeft)]
            try store.save(configuration)
            XCTAssertEqual(try store.load(), configuration)
            let encoded = try ConfigurationCodec.encode(configuration)
            XCTAssertEqual(try ConfigurationCodec.preview(encoded).configuration.language, language)
        }
        XCTAssertEqual(AppLanguage.zh.rawValue, "zh")
        XCTAssertEqual(AppLanguage.zh.resourceIdentifier, "zh-Hans")
        XCTAssertEqual(AppLanguage.en.resourceIdentifier, "en")
        XCTAssertEqual(AppLanguage.my.resourceIdentifier, "my")
    }
    func testRoundTrip() throws {
        var c = Configuration(); c.globalDefaults.mappings = Configuration.preset("five"); c.scroll.enabled = true
        c.profiles = [Profile(name: "Browser", bundleID: "com.apple.Safari", mappings: [Mapping(trigger: .init(kind: .swipe, fingers: 2), action: .back)])]
        XCTAssertEqual(try ConfigurationCodec.decode(ConfigurationCodec.encode(c)), c)
    }
    func testFutureVersionRejected() {
        XCTAssertThrowsError(try ConfigurationCodec.decode(Data("{\"schemaVersion\":999}".utf8)))
    }
    func testLegacyMigration() throws {
        let data = Data("{\"schemaVersion\":1,\"profiles\":[{\"mappings\":[{\"button\":3,\"action\":\"back\",\"enabled\":true}]}]}".utf8)
        let c = try ConfigurationCodec.decode(data); XCTAssertEqual(c.schemaVersion, 2); XCTAssertEqual(c.globalDefaults.mappings[0].action, .back); XCTAssertFalse(c.engineEnabled)
    }
    func testImportedCommandsRequireReviewAndEnginePaused() throws {
        var c = Configuration(); c.engineEnabled = true; c.touchEnabled = true; c.automaticUpdates = true
        var options = ActionOptions(); options.target = "echo test"; options.shellEnabled = true
        c.globalDefaults.mappings = [Mapping(trigger: .init(), action: .shell, options: options)]
        let preview = try ConfigurationCodec.preview(ConfigurationCodec.encode(c))
        XCTAssertEqual(preview.disabledCommands, 1); XCTAssertFalse(preview.configuration.engineEnabled); XCTAssertFalse(preview.configuration.touchEnabled); XCTAssertFalse(preview.configuration.automaticUpdates)
        XCTAssertFalse(preview.configuration.globalDefaults.mappings[0].enabled); XCTAssertFalse(preview.configuration.globalDefaults.mappings[0].options.shellEnabled)
    }
    func testInvalidThresholdAndProtectedButtons() {
        var c = Configuration(); c.tuning.tapDuration = -1; XCTAssertThrowsError(try ConfigurationValidator.validate(c))
        c = Configuration(); c.globalDefaults.mappings = [Mapping(button: 0, action: .none)]; XCTAssertThrowsError(try ConfigurationValidator.validate(c))
    }
    func testDuplicateAndCanonicalConflict() {
        var c = Configuration(); let a = Trigger(kind: .button, button: 3, fingers: 1); let b = Trigger(kind: .button, button: 3, fingers: 3)
        c.globalDefaults.mappings = [Mapping(trigger: a, action: .back),Mapping(trigger: b, action: .forward)]
        XCTAssertThrowsError(try ConfigurationValidator.validate(c))
    }
    func testDuplicateSelectorsRejected() {
        var c = Configuration(); c.profiles = [Profile(bundleID: "app"),Profile(bundleID: "app")]; XCTAssertThrowsError(try ConfigurationValidator.validate(c))
    }
    func testInvalidURLAndCommandBounds() {
        var c = Configuration(); var o = ActionOptions(); o.target = "file:///etc/passwd"; c.globalDefaults.mappings = [.init(trigger: .init(), action: .openURL, options: o)]
        XCTAssertThrowsError(try ConfigurationValidator.validate(c)); o.target = "https://example.com"; c.globalDefaults.mappings[0].options = o; XCTAssertNoThrow(try ConfigurationValidator.validate(c))
        c.globalDefaults.mappings[0].options.timeout = 500; XCTAssertThrowsError(try ConfigurationValidator.validate(c))
    }
    func testAtomicSaveAndBackupRecovery() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); defer { try? FileManager.default.removeItem(at: dir) }
        let store = ConfigurationStore(url: dir.appendingPathComponent("settings.json"))
        var c = Configuration(); try store.save(c); c.scroll.speed = 2; try store.save(c)
        try Data("broken".utf8).write(to: store.url)
        let recovered = try store.load(); XCTAssertEqual(recovered.scroll.speed, 1); XCTAssertTrue(store.recoveredBackup)
    }
    func testBrokenSettingsPreserved() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = ConfigurationStore(url: dir.appendingPathComponent("settings.json")); let data = Data("invalid".utf8); try data.write(to: store.url)
        XCTAssertThrowsError(try store.load()); XCTAssertEqual(try Data(contentsOf: store.url), data)
    }
    func testMergeConflictAndDistinctRules() throws {
        var c = Configuration(); c.profiles = [Profile(name: "A",bundleID: "a")]
        var imported = Configuration(); imported.profiles = [Profile(name: "B",bundleID: "b")]
        XCTAssertEqual(try ConfigurationCodec.merge(current: c, imported: imported).profiles.count, 2)
        imported.profiles = [Profile(name: "Conflict",bundleID: "a")]; XCTAssertThrowsError(try ConfigurationCodec.merge(current: c, imported: imported))
    }
    func testUnknownActionRejected() throws {
        var c = Configuration(); c.globalDefaults.mappings = Configuration.preset("three")
        let data = try ConfigurationCodec.encode(c); let bad = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "middleClick", with: "unknownAction")
        XCTAssertThrowsError(try ConfigurationCodec.decode(Data(bad.utf8)))
    }
    func testPausedSpecificProfileStopsGlobalFallback() {
        let global = Profile(name: "global", mappings: [.init(button: 3, action: .back)])
        let app = Profile(name: "paused",bundleID: "a", paused: true)
        let result = ProfileResolver.resolve(trigger: .init(button: 3), bundleID: "a", deviceID: nil, profiles: [global,app])
        XCTAssertEqual(result?.source,"paused"); XCTAssertEqual(result?.paused,true); XCTAssertEqual(result?.mapping.enabled,false)
    }
    func testAnonymousInputDoesNotUseDeviceProfile() {
        let p = Profile(deviceID: "some-mouse",mappings: [.init(button: 3, action: .back)])
        XCTAssertNil(ProfileResolver.resolve(button: 3, bundleID: nil, deviceID: nil, profiles: [p]))
    }
}
