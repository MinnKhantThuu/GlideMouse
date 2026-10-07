import XCTest
@testable import MouseCore

final class PrimaryButtonTests: XCTestCase {
    func testUnmappedPrimaryButtonsPassThroughImmediately() {
        for button in 0...1 {
            var e = ButtonEngine()
            XCTAssertFalse(e.down(button: button, x: 0, y: 0, time: 0, modifiers: [], bindings: []).suppress)
            XCTAssertFalse(e.up(button: button, time: 0.1, bindings: []).suppress)
            XCTAssertFalse(e.hasPendingWork)
        }
    }
    func testDoubleMappingPreservesSingleClickAfterWaitAndConsumesDouble() {
        for button in 0...1 {
            let double = Trigger(kind: .button, button: button, clicks: 2)
            let single = Trigger(kind: .button, button: button)
            var e = ButtonEngine()
            XCTAssertTrue(e.down(button: button, x: 0, y: 0, time: 0, modifiers: [], bindings: [double]).suppress)
            XCTAssertTrue(e.up(button: button, time: 0.05, bindings: [double]).triggers.isEmpty)
            XCTAssertEqual(e.advance(time: 0.5, bindings: [double]), [single])
            _ = e.down(button: button, x: 0, y: 0, time: 1, modifiers: [], bindings: [double])
            _ = e.up(button: button, time: 1.05, bindings: [double])
            _ = e.down(button: button, x: 0, y: 0, time: 1.1, modifiers: [], bindings: [double])
            XCTAssertEqual(e.up(button: button, time: 1.15, bindings: [double]).triggers, [double])
            XCTAssertTrue(e.advance(time: 2, bindings: [double]).isEmpty)
        }
    }
    func testHoldDoesNotStealShortClickOrFireOnReleaseTwice() {
        for button in 0...1 {
            let hold = Trigger(kind: .buttonHold, button: button)
            var e = ButtonEngine()
            _ = e.down(button: button, x: 0, y: 0, time: 0, modifiers: [], bindings: [hold])
            XCTAssertEqual(e.up(button: button, time: 0.1, bindings: [hold]).triggers, [Trigger(button: button)])
            _ = e.down(button: button, x: 0, y: 0, time: 1, modifiers: [], bindings: [hold])
            XCTAssertEqual(e.advance(time: 2, bindings: [hold]), [hold])
            XCTAssertTrue(e.advance(time: 3, bindings: [hold]).isEmpty)
            XCTAssertTrue(e.up(button: button, time: 3.1, bindings: [hold]).triggers.isEmpty)
        }
    }
    func testPrimaryMovementRestoresNativeDragAndCancelsHoldAndPendingDouble() {
        for button in 0...1 {
            let bindings = [Trigger(kind: .buttonHold, button: button), Trigger(kind: .button, button: button, clicks: 2)]
            var e = ButtonEngine()
            _ = e.down(button: button, x: 0, y: 0, time: 0, modifiers: [], bindings: bindings)
            _ = e.up(button: button, time: 0.05, bindings: bindings)
            _ = e.down(button: button, x: 0, y: 0, time: 0.1, modifiers: [], bindings: bindings)
            XCTAssertTrue(e.move(x: 2, y: 0, bindings: bindings).nativeDrags.isEmpty)
            XCTAssertEqual(e.move(x: 3, y: 0, bindings: bindings).nativeDrags, [button])
            XCTAssertTrue(e.advance(time: 2, bindings: bindings).isEmpty)
            XCTAssertFalse(e.up(button: button, time: 2.1, bindings: bindings).suppress)
        }
    }
    func testPrimaryConfigurationAllowsOnlyDoubleAndHoldAndRoundTrips() throws {
        var c = Configuration()
        c.globalDefaults.mappings = (0...1).flatMap { b in [Mapping(trigger: Trigger(kind: .button, button: b, clicks: 2), action: .missionControl), Mapping(trigger: Trigger(kind: .buttonHold, button: b), action: .quickLook)] }
        XCTAssertEqual(try ConfigurationCodec.decode(ConfigurationCodec.encode(c)), c)
        for t in [Trigger(button: 0), Trigger(kind: .button, button: 1, clicks: 3), Trigger(kind: .buttonDrag, button: 0), Trigger(kind: .buttonWheel, button: 1), Trigger(kind: .buttonChord, button: 3, chordButton: 0)] {
            c.globalDefaults.mappings = [Mapping(trigger: t, action: .back)]
            XCTAssertThrowsError(try ConfigurationValidator.validate(c))
        }
    }
    func testModifierMismatchDoesNotConsumeNativePrimaryClick() {
        var e = ButtonEngine()
        XCTAssertFalse(e.down(button: 0, x: 0, y: 0, time: 0, modifiers: .shift, bindings: [Trigger(kind: .buttonHold, button: 0)]).suppress)
    }
}
