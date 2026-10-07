import XCTest
@testable import MouseCore

final class ClickLatencyTests: XCTestCase {
    func testClickWithHoldAndDragDoesNotWaitAfterRelease() {
        let click = Trigger(button: 3)
        let bindings = [click, Trigger(kind: .buttonHold, button: 3), Trigger(kind: .buttonDrag, button: 3, direction: .left)]
        var engine = ButtonEngine()
        XCTAssertTrue(engine.down(button: 3, x: 0, y: 0, time: 0, modifiers: [], bindings: bindings).suppress)
        XCTAssertEqual(engine.up(button: 3, time: 0.05, bindings: bindings).triggers, [click])
        XCTAssertFalse(engine.hasPendingWork)
    }
    func testClickWithWheelAndDragDoesNotWaitAfterRelease() {
        let click = Trigger(button: 4)
        let bindings = [click, Trigger(kind: .buttonWheel, button: 4), Trigger(kind: .buttonDrag, button: 4)]
        var engine = ButtonEngine()
        _ = engine.down(button: 4, x: 0, y: 0, time: 0, modifiers: [], bindings: bindings)
        XCTAssertEqual(engine.up(button: 4, time: 0.07, bindings: bindings).triggers, [click])
        XCTAssertFalse(engine.hasPendingWork)
    }
    func testHoldDoesNotAlsoFireClickOnRelease() {
        let hold = Trigger(kind: .buttonHold, button: 3)
        let bindings = [Trigger(button: 3), hold]
        var engine = ButtonEngine()
        _ = engine.down(button: 3, x: 0, y: 0, time: 0, modifiers: [], bindings: bindings)
        XCTAssertEqual(engine.advance(time: 0.41, bindings: bindings), [hold])
        XCTAssertTrue(engine.up(button: 3, time: 0.5, bindings: bindings).triggers.isEmpty)
    }
}
