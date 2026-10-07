import XCTest
@testable import MouseCore
final class MouseInputCaptureTests: XCTestCase {
    func testClickAndHold() {
        var c = MouseInputCapture()
        XCTAssertNil(c.down(button:3,x:0,y:0,time:0,clicks:2,modifiers:.shift))
        let click = c.up(button:3,time:0.1)
        XCTAssertEqual(click?.kind,.button); XCTAssertEqual(click?.clicks,2); XCTAssertEqual(click?.modifiers,.shift)
        _ = c.down(button:4,x:0,y:0,time:1,clicks:1,modifiers:[])
        XCTAssertEqual(c.up(button:4,time:1.5)?.kind,.buttonHold)
    }
    func testDragDoesNotBecomeClickOnRelease() {
        var c = MouseInputCapture(); _ = c.down(button:3,x:0,y:0,time:0,clicks:1,modifiers:[])
        XCTAssertNil(c.move(x:10,y:0)); XCTAssertEqual(c.move(x:-40,y:0)?.direction,.left)
        XCTAssertNil(c.up(button:3,time:0.2))
    }
    func testWheelCapturesHeldButtonAndDirection() {
        var c = MouseInputCapture(); XCTAssertNil(c.wheel(x:0,y:1,modifiers:[]))
        _ = c.down(button:4,x:0,y:0,time:0,clicks:1,modifiers:[])
        let t = c.wheel(x:0,y:-1,modifiers:.option)
        XCTAssertEqual(t?.kind,.buttonWheel); XCTAssertEqual(t?.button,4); XCTAssertEqual(t?.direction,.down); XCTAssertEqual(t?.modifiers,.option)
        XCTAssertNil(c.up(button:4,time:0.3))
    }
    func testChordAndReset() {
        var c = MouseInputCapture(); _ = c.down(button:3,x:0,y:0,time:0,clicks:1,modifiers:[])
        let t = c.down(button:4,x:0,y:0,time:0.1,clicks:1,modifiers:[])
        XCTAssertEqual(t?.kind,.buttonChord); XCTAssertEqual(t?.button,3); XCTAssertEqual(t?.chordButton,4)
        XCTAssertNil(c.up(button:4,time:0.2)); c.reset(); XCTAssertNil(c.up(button:3,time:0.3))
    }
    func testPrimaryButtonsCanBeSelectedAndCaptured() {
        var c = MouseInputCapture(); XCTAssertNil(c.down(button:0,x:0,y:0,time:0,clicks:1,modifiers:[])); XCTAssertEqual(c.up(button:0,time:0.1)?.button,0)
        _ = c.down(button:1,x:0,y:0,time:1,clicks:2,modifiers:[])
        XCTAssertEqual(c.up(button:1,time:1.1)?.clicks,2)
        _ = c.down(button:0,x:0,y:0,time:2,clicks:1,modifiers:[])
        XCTAssertEqual(c.up(button:0,time:3)?.kind,.buttonHold)
    }
}
