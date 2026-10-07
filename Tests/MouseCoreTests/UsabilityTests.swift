import XCTest
@testable import MouseCore

final class UsabilityTests: XCTestCase {
    func testOldSettingsDecodeWithoutUsabilityAndKeepCustomValues() throws {
        var old = Configuration(); old.globalDefaults.mappings = [Mapping(button: 3, action: .spaceLeft), Mapping(trigger: .init(kind: .buttonHold, button: 3), action: .missionControl)]
        old.tuning.holdDelay = 0.73; old.scroll.speed = 2.4; old.profiles = [Profile(name: "Safari", bundleID: "com.apple.Safari", mappings: [Mapping(button: 4, action: .back)])]
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: ConfigurationCodec.encode(old)) as? [String: Any]); json.removeValue(forKey: "usability")
        let decoded = try ConfigurationCodec.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded, old); XCTAssertNil(decoded.usability)
    }
    func testCalibrationSurvivesExportAndDoesNotChangeMappings() throws {
        var c = Configuration(); c.globalDefaults.mappings = Configuration.preset("five")
        let original = c.globalDefaults.mappings
        var layout = MouseCalibration(identity: "BT4.0 Mouse")
        layout.assign(button: 3, position: .lower); layout.assign(button: 4, position: .upper)
        var ui = UsabilityPreferences(); ui.setupCompleted = true; ui.calibrations = [layout]; c.usability = ui
        let imported = try ConfigurationCodec.decode(ConfigurationCodec.encode(c))
        XCTAssertEqual(imported.usability, ui); XCTAssertEqual(imported.globalDefaults.mappings, original)
    }
    func testCalibrationPositionReassignmentAndInvalidButtons() throws {
        var layout = MouseCalibration(identity: "mouse"); layout.assign(button: 3, position: .lower); layout.assign(button: 4, position: .lower)
        XCTAssertEqual(layout.buttons, [CalibratedButton(button: 4, position: .lower)])
        layout.assign(button: 4, position: .upper); XCTAssertEqual(layout.buttons.count, 1)
        var c = Configuration(); var ui = UsabilityPreferences(); ui.calibrations = [MouseCalibration(identity: "mouse", buttons: [.init(button: 0, position: .wheel)])]; c.usability = ui
        XCTAssertThrowsError(try ConfigurationValidator.validate(c))
    }
    func testStarterMergesWithoutDroppingAdvancedBindings() {
        var original = (2...4).map { Mapping(button: $0, action: .middleClick) }
        original += [Mapping(trigger: .init(kind: .buttonDrag, button: 3), action: .spaceLeft), Mapping(trigger: .init(kind: .buttonWheel, button: 4), action: .zoomIn)]
        original[1].name = "Lower"; let clickID = original[1].id
        let additions = MappingEdits.starter("desktop", buttons: [.init(button: 3, position: .lower), .init(button: 4, position: .upper)])
        let result = MappingEdits.merge(additions, into: original)
        XCTAssertEqual(result.count, original.count + 1)
        XCTAssertEqual(result.first { $0.trigger == Trigger(button: 3) }?.id, clickID)
        XCTAssertEqual(result.first { $0.trigger == Trigger(button: 3) }?.name, "Lower")
        for mapping in original where mapping.trigger.kind != .button { XCTAssertTrue(result.contains(mapping)) }
        XCTAssertTrue(MappingEdits.starter("desktop", buttons: []).isEmpty)
    }
    func testScrollPresetKeepsSpeedDirectionModifiersAndOtherConfiguration() {
        var c = Configuration(); c.globalDefaults.mappings = Configuration.preset("five"); c.scroll.speed = 2.1; c.scroll.reverseVertical = true; c.scroll.optionZoom = true
        let original = c
        c.scroll = ScrollPreset.smooth.applying(to: c.scroll)
        XCTAssertEqual(c.scroll.speed, 2.1); XCTAssertTrue(c.scroll.reverseVertical); XCTAssertTrue(c.scroll.optionZoom)
        XCTAssertEqual(c.globalDefaults, original.globalDefaults); XCTAssertEqual(c.tuning, original.tuning)
        XCTAssertEqual(ScrollPreset.matching(c.scroll), .smooth)
        XCTAssertEqual(ScrollPreset.custom.applying(to: c.scroll), c.scroll)
    }
    func testResponsePresetPreservesTouchThresholds() {
        var tuning = Tuning(); tuning.tapDuration = 0.5; tuning.swipeDistance = 0.3
        let changed = ButtonFeelPreset.relaxed.applying(to: tuning)
        XCTAssertEqual(changed.tapDuration, tuning.tapDuration); XCTAssertEqual(changed.swipeDistance, tuning.swipeDistance)
        XCTAssertEqual(ButtonFeelPreset.matching(changed), .relaxed)
    }
    func testAppOverrideDoesNotChangeGlobalOrInheritedHold() {
        let global = Profile(name: "All apps", mappings: [Mapping(button: 3, action: .spaceLeft), Mapping(trigger: .init(kind: .buttonHold, button: 3), action: .missionControl)])
        let overrides = MappingEdits.merge([Mapping(button: 3, action: .back)], into: [])
        let app = Profile(name: "Safari", bundleID: "com.apple.Safari", mappings: overrides)
        XCTAssertEqual(ProfileResolver.resolve(trigger: .init(button: 3), bundleID: "com.apple.Safari", deviceID: nil, profiles: [global,app])?.mapping.action, .back)
        XCTAssertEqual(ProfileResolver.resolve(trigger: .init(kind: .buttonHold, button: 3), bundleID: "com.apple.Safari", deviceID: nil, profiles: [global,app])?.mapping.action, .missionControl)
        XCTAssertEqual(global.mappings[0].action, .spaceLeft)
    }
}
