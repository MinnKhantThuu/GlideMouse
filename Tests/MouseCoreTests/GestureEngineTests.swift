import XCTest
@testable import MouseCore
final class GestureEngineTests: XCTestCase {
    func point(_ id: Int = 1, _ x: Double = 0.4, _ y: Double = 0.5) -> TouchPoint { .init(id: id, x: x, y: y) }
    func testTapAndRightZone() {
        var e = GestureEngine(); XCTAssertTrue(e.process(.init(timestamp: 1, contacts: [point()])).isEmpty)
        let tap = e.process(.init(timestamp: 1.1, contacts: [])); XCTAssertEqual(tap.first?.trigger.kind,.tap)
        _ = e.process(.init(timestamp: 2, contacts: [point(1,0.8)])); XCTAssertEqual(e.process(.init(timestamp: 2.1, contacts: [])).first?.trigger.kind,.rightTap)
    }
    func testTwoAndThreeFingerTaps() {
        for n in [2,3] {
            var e = GestureEngine(); _ = e.process(.init(timestamp: 1, contacts: (1...n).map { point($0,Double($0)*0.2) }))
            XCTAssertEqual(e.process(.init(timestamp: 1.1, contacts: [])).first?.trigger.fingers,n)
        }
    }
    func testDoubleTripleTapCountsAndModifiers() {
        var e = GestureEngine()
        for n in 1...3 { let t = Double(n)*0.15; _ = e.process(.init(timestamp: t, contacts: [point()], modifiers: [.command])); let g = e.process(.init(timestamp: t+0.05, contacts: [])); XCTAssertEqual(g.first?.trigger.clicks,n); XCTAssertEqual(g.first?.trigger.modifiers,[.command]) }
    }
    func testRestingFingerDoesNotBlockNewTap() {
        var e = GestureEngine(); _ = e.process(.init(timestamp: 1, contacts: [point(1)])); _ = e.process(.init(timestamp: 1.4, contacts: [point(1)])); _ = e.process(.init(timestamp: 1.8, contacts: [point(1)]))
        _ = e.process(.init(timestamp: 1.9, contacts: [point(1),point(2,0.5)])); let tap = e.process(.init(timestamp: 2, contacts: [point(1)]))
        XCTAssertEqual(tap.first?.trigger.fingers,1)
    }
    func testEdgesAndLongContactRejected() {
        var e = GestureEngine(); _ = e.process(.init(timestamp: 1, contacts: [point(1,0.01)])); XCTAssertTrue(e.process(.init(timestamp: 1.1, contacts: [])).isEmpty)
        _ = e.process(.init(timestamp: 2, contacts: [point()])); _ = e.process(.init(timestamp: 2.4, contacts: [point()])); XCTAssertTrue(e.process(.init(timestamp: 2.45, contacts: [])).isEmpty)
    }
    func testMovementCannotBecomeClick() {
        var e = GestureEngine(); _ = e.process(.init(timestamp: 1, contacts: [point()])); _ = e.process(.init(timestamp: 1.05, contacts: [point(1,0.45,0.58)])); XCTAssertTrue(e.process(.init(timestamp: 1.1, contacts: [])).isEmpty)
    }
    func testSwipeRecognizedOnce() {
        var e = GestureEngine(); _ = e.process(.init(timestamp: 1, contacts: [point(1,0.3),point(2,0.6)]))
        let swipe = e.process(.init(timestamp: 1.1, contacts: [point(1,0.5),point(2,0.8)])); XCTAssertEqual(swipe.first?.trigger.kind,.swipe); XCTAssertEqual(swipe.first?.trigger.direction,.right)
        XCTAssertTrue(e.process(.init(timestamp: 1.2, contacts: [])).isEmpty)
    }
    func testPinchRecognizedOnce() {
        var e = GestureEngine(); _ = e.process(.init(timestamp: 1, contacts: [point(1,0.2),point(2,0.8)])); let pinch = e.process(.init(timestamp: 1.1, contacts: [point(1,0.35),point(2,0.65)]))
        XCTAssertEqual(pinch.first?.trigger.kind,.pinchIn); XCTAssertTrue(e.process(.init(timestamp: 1.2, contacts: [])).isEmpty)
    }
    func testCancelAndDeviceChange() {
        var e = GestureEngine(); _ = e.process(.init(timestamp: 1, contacts: [point()])); e.cancel(); XCTAssertTrue(e.process(.init(timestamp: 1.1, contacts: [])).isEmpty)
        _ = e.process(.init(timestamp: 2,deviceID: "a",contacts: [point()])); XCTAssertTrue(e.process(.init(timestamp: 2.1,deviceID: "b",contacts: [])).isEmpty)
    }
    func testInvalidAndOutOfOrderFramesCancel() {
        var e = GestureEngine(); _ = e.process(.init(timestamp: 2, contacts: [point()])); XCTAssertTrue(e.process(.init(timestamp: 1, contacts: [])).isEmpty)
        XCTAssertTrue(e.process(.init(timestamp: 3, contacts: [.init(id: 1,x: .nan,y: 0.5)])).isEmpty)
    }
    func testWaitForMultiTapDispatch() {
        var d = MultiTapDispatcher(); let g = RecognizedGesture(trigger: .init(kind: .tap), deviceID: "a",timestamp: 1)
        XCTAssertTrue(d.submit(g,hasHigherTap: true,interval: 0.3).isEmpty); XCTAssertTrue(d.advance(1.2).isEmpty); XCTAssertEqual(d.advance(1.31).count,1)
        _ = d.submit(g,hasHigherTap: true,interval: 0.3); d.cancel(); XCTAssertTrue(d.advance(2).isEmpty)
    }
    func test500ScrollBrushTracesProduceNoClicks() {
        var e = GestureEngine()
        var clicks = 0
        for i in 0..<500 {
            let t=Double(i)+1
            _ = e.process(.init(timestamp: t,contacts: [point()]))
            _ = e.process(.init(timestamp: t+0.05,contacts: [point(1,0.4,0.65)]))
            e.cancelForNativeScroll()
            clicks += e.process(.init(timestamp: t+0.1,contacts: [])).filter { [.tap,.rightTap].contains($0.trigger.kind) }.count
        }
        XCTAssertEqual(clicks,0)
    }
    func testTapThenHoldRequiresEarlierTap() {
        var e = GestureEngine(); _ = e.process(.init(timestamp: 1,contacts: [point()])); _ = e.process(.init(timestamp: 1.1,contacts: [])); _ = e.process(.init(timestamp: 1.2,contacts: [point()])); let hold = e.process(.init(timestamp: 1.61,contacts: [point()]))
        XCTAssertEqual(hold.first?.trigger.kind,.touchHold)
    }
}
