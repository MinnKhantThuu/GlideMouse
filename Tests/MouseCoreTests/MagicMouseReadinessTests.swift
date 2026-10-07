import XCTest
@testable import MouseCore

final class MagicMouseReadinessTests: XCTestCase {
    private func point(_ id: Int, _ x: Double = 0.4, _ y: Double = 0.5) -> TouchPoint { .init(id: id, x: x, y: y) }
    func testLegacyTuningDecodesWithoutNewFields() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: ConfigurationCodec.encode(Configuration())) as? [String: Any])
        var tuning = try XCTUnwrap(json["tuning"] as? [String: Any])
        for key in ["touchHoldDelay", "swipeSpeed", "tapSlideSpeed", "dragScrollSpeed", "dragScrollReverse", "appSwitchDelay", "rightZoneFront"] { tuning.removeValue(forKey: key) }
        json["tuning"] = tuning
        let decoded = try ConfigurationCodec.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded.tuning, Tuning())
        XCTAssertEqual(try ConfigurationCodec.decode(ConfigurationCodec.encode(decoded)), decoded)
    }
    func testAllTapCountsForAllFingerCountsAndModifierCombinations() {
        for fingers in 1...3 { for raw in 0...15 {
            var engine = GestureEngine()
            for count in 1...3 {
                let time = 1 + Double(count) * 0.15
                let touches = (1...fingers).map { point($0, Double($0) * 0.18) }
                _ = engine.process(.init(timestamp: time, contacts: touches, modifiers: .init(rawValue: raw)))
                let result = engine.process(.init(timestamp: time + 0.04, contacts: [], modifiers: .init(rawValue: raw)))
                XCTAssertEqual(result.first?.trigger.clicks, count)
                XCTAssertEqual(result.first?.trigger.fingers, fingers)
                XCTAssertEqual(result.first?.trigger.modifiers.rawValue, raw)
            }
        } }
    }
    func testEverySupportedSwipeDirectionAndFingerCount() {
        for fingers in 1...3 { for direction in Direction.allCases where fingers > 1 || [.left, .right].contains(direction) {
            var engine = GestureEngine()
            let start = (1...fingers).map { point($0, 0.25 + Double($0) * 0.12, 0.5) }
            let end = start.map { TouchPoint(id: $0.id, x: $0.x + (direction == .left ? -0.2 : direction == .right ? 0.2 : 0), y: $0.y + (direction == .down ? -0.2 : direction == .up ? 0.2 : 0)) }
            _ = engine.process(.init(timestamp: 1, contacts: start))
            let result = engine.process(.init(timestamp: 1.1, contacts: end))
            XCTAssertEqual(result.first?.trigger.kind, .swipe)
            XCTAssertEqual(result.first?.trigger.direction, direction)
            XCTAssertEqual(result.first?.trigger.fingers, fingers)
            XCTAssertTrue(engine.process(.init(timestamp: 1.2, contacts: [])).isEmpty)
        } }
    }
    func testModifierClickFallbackAndExplicitOverride() {
        let all = Profile(mappings: Configuration.preset("magic"))
        let trigger = Trigger(kind: .tap, modifiers: [.command])
        XCTAssertEqual(ProfileResolver.resolveGesture(trigger: trigger, bundleID: nil, deviceID: nil, profiles: [all])?.mapping.action, .leftClick)
        let app = Profile(bundleID: "editor", mappings: [Mapping(trigger: trigger, action: .missionControl)])
        XCTAssertEqual(ProfileResolver.resolveGesture(trigger: trigger, bundleID: "editor", deviceID: nil, profiles: [all, app])?.mapping.action, .missionControl)
        var disabled = app; disabled.mappings[0].enabled = false
        XCTAssertFalse(ProfileResolver.resolveGesture(trigger: trigger, bundleID: "editor", deviceID: nil, profiles: [all, disabled])!.mapping.enabled)
        XCTAssertNil(ProfileResolver.resolveGesture(trigger: .init(kind: .swipe, fingers: 2, modifiers: [.command]), bundleID: nil, deviceID: nil, profiles: [all]))
    }
    func testPresetHasNoPhysicalButtonBindingsAndNoConflicts() throws {
        let preset = MagicMouseCatalog.defaults
        XCTAssertTrue(preset.allSatisfy { MagicMouseCatalog.touchKinds.contains($0.trigger.kind) })
        XCTAssertEqual(Set(preset.map { $0.trigger.canonical }).count, preset.count)
        XCTAssertEqual(Set(MagicMouseCatalog.triggers).count, MagicMouseCatalog.triggers.count)
        var config = Configuration(); config.globalDefaults.mappings = preset
        try ConfigurationValidator.validate(config)
        let existing = [Mapping(button: 3, action: .spaceLeft), Mapping(trigger: .init(kind: .buttonHold, button: 3), action: .missionControl)]
        XCTAssertEqual(Array(MappingEdits.merge(preset, into: existing).prefix(2)), existing)
    }
    func testDragStartsWithMovementAndRequiresMatchingTap() {
        var engine = GestureEngine()
        _ = engine.process(.init(timestamp: 1, contacts: [point(1)]))
        _ = engine.process(.init(timestamp: 1.05, contacts: []))
        _ = engine.process(.init(timestamp: 1.15, contacts: [point(2)]))
        let drag = engine.process(.init(timestamp: 1.2, contacts: [point(2, 0.45)]))
        XCTAssertEqual(drag.first?.trigger.kind, .touchHold)
        XCTAssertEqual(engine.holdContacts, [2])
        var wrong = GestureEngine()
        _ = wrong.process(.init(timestamp: 1, contacts: [point(1)], modifiers: [.command]))
        _ = wrong.process(.init(timestamp: 1.05, contacts: []))
        _ = wrong.process(.init(timestamp: 1.15, contacts: [point(2)]))
        XCTAssertTrue(wrong.process(.init(timestamp: 1.56, contacts: [point(2)])).isEmpty)
    }
    func testDragReleaseIgnoresRestingFingerAndHandlesEveryFault() {
        for fault in ["lift", "device", "stall", "time", "nan", "duplicate", "overflow"] {
            var session = TouchDragSession(); session.begin(owners: [1], device: "mouse", time: 1, resting: [9])
            var frame = TouchFrame(timestamp: 1.1, deviceID: "mouse", contacts: [point(1), point(9)])
            switch fault {
            case "lift": frame.contacts = [point(9)]
            case "device": frame.deviceID = "different"
            case "stall": frame.timestamp = 1.6
            case "time": frame.timestamp = 0.9
            case "duplicate": frame.contacts = [point(1), point(1)]
            case "overflow": frame.contacts = (1...17).map { point($0) }
            default: frame.contacts = [point(1, .nan)]
            }
            XCTAssertTrue(session.process(frame, tuning: Tuning()).release, fault)
            XCTAssertFalse(session.active)
            XCTAssertFalse(session.process(frame, tuning: Tuning()).release)
        }
    }
    func testDragScrollUsesIndependentFingerAndPhasesAndReversal() {
        for reverse in [false, true] {
            var session = TouchDragSession(); session.begin(owners: [1], device: "mouse", time: 1, resting: [9])
            var tuning = Tuning(); tuning.dragScrollReverse = reverse
            _ = session.process(.init(timestamp: 1.1, deviceID: "mouse", contacts: [point(1), point(9), point(2)]), tuning: tuning)
            let moved = session.process(.init(timestamp: 1.2, deviceID: "mouse", contacts: [point(1), point(9), point(2, 0.4, 0.6)]), tuning: tuning)
            XCTAssertFalse(moved.release); XCTAssertEqual(moved.scroll?.phase, 1)
            XCTAssertEqual(moved.scroll!.y, reverse ? -80 : 80, accuracy: 0.0001)
            let ended = session.process(.init(timestamp: 1.3, deviceID: "mouse", contacts: [point(1), point(9)]), tuning: tuning)
            XCTAssertEqual(ended.scroll?.phase, 4); XCTAssertTrue(session.active)
        }
    }
    func testRestingContactDoesNotQuarantineEveryFutureTapAfterScrolling() {
        var engine = GestureEngine()
        _ = engine.process(.init(timestamp: 1, contacts: [point(1)]))
        engine.cancelForNativeScroll()
        for time in [1.2, 1.4, 1.6, 1.8] { _ = engine.process(.init(timestamp: time, contacts: [point(1)])) }
        _ = engine.process(.init(timestamp: 1.9, contacts: [point(1), point(2, 0.5)]))
        XCTAssertEqual(engine.process(.init(timestamp: 2, contacts: [point(1)])).first?.trigger.fingers, 1)
    }
    func testSwipeSpeedAndFastBrushRejection() {
        var tuning = Tuning(); tuning.swipeSpeed = 2
        var engine = GestureEngine(tuning: tuning)
        _ = engine.process(.init(timestamp: 1, contacts: [point(1)]))
        XCTAssertTrue(engine.process(.init(timestamp: 1.3, contacts: [point(1, 0.6)])).isEmpty)
        XCTAssertTrue(engine.process(.init(timestamp: 1.35, contacts: [])).isEmpty)
        var brush = GestureEngine(); _ = brush.process(.init(timestamp: 2, contacts: [point(1)]))
        _ = brush.process(.init(timestamp: 2.001, contacts: [point(1, 0.42)]))
        XCTAssertTrue(brush.process(.init(timestamp: 2.08, contacts: [])).isEmpty)
    }
    func testRightZoneModifierFallbackPreservesClicksAndDisabledOverrides() {
        let preset = Profile(mappings: MagicMouseCatalog.defaults)
        for count in 1...3 {
            let trigger = Trigger(kind: .rightTap, clicks: count, modifiers: [.command, .shift])
            XCTAssertEqual(ProfileResolver.resolveGesture(trigger: trigger, bundleID: nil, deviceID: nil, profiles: [preset])?.mapping.action, .rightClick)
        }
        let leftOnly = Profile(mappings: [Mapping(trigger: .init(kind: .tap), action: .leftClick)])
        XCTAssertEqual(ProfileResolver.resolveGesture(trigger: .init(kind: .rightTap, modifiers: .command), bundleID: nil, deviceID: nil, profiles: [leftOnly])?.mapping.action, .leftClick)
    }
    func testHoldCannotStartOnAnAlreadyLiftedFinger() {
        var engine = GestureEngine()
        _ = engine.process(.init(timestamp: 1, contacts: [point(1)]))
        _ = engine.process(.init(timestamp: 1.05, contacts: []))
        _ = engine.process(.init(timestamp: 1.15, contacts: [point(2)]))
        XCTAssertTrue(engine.process(.init(timestamp: 1.56, contacts: [])).isEmpty)
        XCTAssertTrue(engine.holdContacts.isEmpty)
    }
    func testNativeScrollRejectsTapButKeepsMappedSwipeRecognition() {
        var engine = GestureEngine()
        engine.rejectTapForNativeScroll()
        _ = engine.process(.init(timestamp: 1, contacts: [point(1)]))
        XCTAssertTrue(engine.process(.init(timestamp: 1.05, contacts: [])).isEmpty)
        _ = engine.process(.init(timestamp: 2, contacts: [point(1), point(2, 0.6)]))
        engine.rejectTapForNativeScroll()
        XCTAssertEqual(engine.process(.init(timestamp: 2.1, contacts: [point(1, 0.6), point(2, 0.8)])).first?.trigger.kind, .swipe)
        XCTAssertTrue(engine.process(.init(timestamp: 2.15, contacts: [])).isEmpty)
    }
    func testRestingFingerCanSwipeWithoutLiftingWholeHand() {
        var engine = GestureEngine()
        for time in [1.0, 1.2, 1.4, 1.6, 1.8] { _ = engine.process(.init(timestamp: time, contacts: [point(1)])) }
        XCTAssertTrue(engine.process(.init(timestamp: 1.9, contacts: [point(1, 0.45)])).isEmpty)
        let output = engine.process(.init(timestamp: 2.0, contacts: [point(1, 0.62)]))
        XCTAssertEqual(output.first?.trigger.kind, .swipe)
        XCTAssertEqual(output.first?.trigger.direction, .right)
        XCTAssertTrue(engine.process(.init(timestamp: 2.1, contacts: [])).isEmpty)
    }
    func testDragFaultEndsScrollExactlyOnce() {
        var session = TouchDragSession(); session.begin(owners: [1], device: "mouse", time: 1)
        _ = session.process(.init(timestamp: 1.1, deviceID: "mouse", contacts: [point(1), point(2)]), tuning: Tuning())
        _ = session.process(.init(timestamp: 1.2, deviceID: "mouse", contacts: [point(1), point(2, 0.4, 0.6)]), tuning: Tuning())
        XCTAssertEqual(session.cancel()?.phase, 4)
        XCTAssertNil(session.cancel()); XCTAssertFalse(session.active)
    }
    func testCycleAppSessionExtendsDeadlineAndCancels() {
        var session = AppCycleSession()
        XCTAssertTrue(session.step(at: 1, delay: 0.8))
        XCTAssertFalse(session.step(at: 1.5, delay: 0.8))
        XCTAssertFalse(session.advance(1.9)); XCTAssertTrue(session.advance(2.31))
        XCTAssertFalse(session.advance(3))
        XCTAssertTrue(session.step(at: 4, delay: 0.8)); XCTAssertTrue(session.cancel()); XCTAssertFalse(session.cancel())
        XCTAssertFalse(session.advance(5))
    }
}
