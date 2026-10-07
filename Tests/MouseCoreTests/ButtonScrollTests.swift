import XCTest
@testable import MouseCore
final class ButtonScrollTests: XCTestCase {
    func testUnmappedPassthroughAndMappedBalancedPair() {
        var e = ButtonEngine(); let bs = [Trigger(button: 3)]
        XCTAssertFalse(e.down(button: 0,x: 0,y: 0,time: 1,modifiers: [],bindings: bs).suppress)
        XCTAssertFalse(e.down(button: 4,x: 0,y: 0,time: 1,modifiers: [],bindings: bs).suppress)
        XCTAssertTrue(e.down(button: 3,x: 0,y: 0,time: 1,modifiers: [],bindings: bs).suppress)
        let r = e.up(button: 3,time: 1.1,bindings: bs); XCTAssertTrue(r.suppress); XCTAssertEqual(r.triggers,bs)
        XCTAssertTrue(e.heldButtons.isEmpty)
    }
    func testDoublePressWaitPolicy() {
        var e = ButtonEngine(); let bs=[Trigger(button: 3),Trigger(button: 3,clicks: 2)]
        _ = e.down(button: 3,x: 0,y: 0,time: 1,modifiers: [],bindings: bs); XCTAssertTrue(e.up(button: 3,time: 1.1,bindings: bs).triggers.isEmpty)
        _ = e.down(button: 3,x: 0,y: 0,time: 1.2,modifiers: [],bindings: bs); XCTAssertEqual(e.up(button: 3,time: 1.25,bindings: bs).triggers.first?.clicks,2)
        XCTAssertTrue(e.advance(time: 2,bindings: bs).isEmpty)
    }
    func testHoldDoesNotAlsoClick() {
        var e=ButtonEngine(); let bs=[Trigger(button: 3),Trigger(kind: .buttonHold,button: 3)]
        _ = e.down(button: 3,x: 0,y: 0,time: 1,modifiers: [],bindings: bs); XCTAssertEqual(e.advance(time: 1.5,bindings: bs).first?.kind,.buttonHold)
        XCTAssertTrue(e.up(button: 3,time: 1.6,bindings: bs).triggers.isEmpty)
    }
    func testChordConsumesBothButtons() {
        var e=ButtonEngine(); let chord=Trigger(kind: .buttonChord,button: 3,chordButton: 4); let bs=[chord]
        _ = e.down(button: 3,x: 0,y: 0,time: 1,modifiers: [],bindings: bs)
        XCTAssertEqual(e.down(button: 4,x: 0,y: 0,time: 1.1,modifiers: [],bindings: bs).triggers,[chord])
        XCTAssertTrue(e.up(button: 3,time: 1.2,bindings: bs).triggers.isEmpty); XCTAssertTrue(e.up(button: 4,time: 1.3,bindings: bs).triggers.isEmpty)
    }
    func testDragAndWheelSuppressClick() {
        var e=ButtonEngine(); let drag=Trigger(kind: .buttonDrag,button: 3,direction: .right); let wheel=Trigger(kind: .buttonWheel,button: 3,direction: .up); let bs=[Trigger(button: 3),drag,wheel]
        _ = e.down(button: 3,x: 0,y: 0,time: 1,modifiers: [],bindings: bs); XCTAssertEqual(e.move(x: 40,y: 2,bindings: bs).triggers,[drag]); XCTAssertTrue(e.up(button: 3,time: 1.3,bindings: bs).triggers.isEmpty)
        _ = e.down(button: 3,x: 0,y: 0,time: 2,modifiers: [],bindings: bs); XCTAssertTrue(e.wheel(x: 0,y: 1,modifiers: [],bindings: bs).suppress); XCTAssertTrue(e.up(button: 3,time: 2.3,bindings: bs).triggers.isEmpty)
    }
    func test100DragCancelCyclesNeverRetainPress() {
        var e=ButtonEngine(); let bs=[Trigger(kind: .buttonDrag,button: 3,direction: .right)]
        for i in 0..<100 { _ = e.down(button: 3,x: 0,y: 0,time: Double(i),modifiers: [],bindings: bs); _ = e.move(x: 50,y: 0,bindings: bs); e.cancel(); XCTAssertTrue(e.heldButtons.isEmpty); XCTAssertFalse(e.up(button: 3,time: Double(i)+0.5,bindings: bs).suppress) }
    }
    func testNativeContinuousScrollPreserved() {
        var e=ScrollEngine(); var s=ScrollSettings(); s.enabled=true
        XCTAssertNil(e.receive(x: 0,y: 1,timestamp: 1,continuous: true,modifiers: [],settings: s)); XCTAssertFalse(e.isActive)
    }
    func testOffTransformsImmediately() {
        var e=ScrollEngine(); var s=ScrollSettings(); s.enabled=true; s.smoothness = .off; s.acceleration=0; s.reverseVertical=true
        XCTAssertEqual(e.receive(x: 0,y: 1,timestamp: 1,continuous: false,modifiers: [],settings: s)?.y,-12); XCTAssertFalse(e.isActive)
    }
    func testShiftHorizontalAndPrecision() {
        var e=ScrollEngine(); var s=ScrollSettings(); s.enabled=true; s.smoothness = .off; s.acceleration=0
        let d=e.receive(x: 0,y: 1,timestamp: 1,continuous: false,modifiers: [.shift,.control],settings: s)
        XCTAssertEqual(d?.y,0); XCTAssertEqual(d?.x ?? 0,2.4,accuracy: 0.001)
    }
    func testSmoothedDisplacementAndEndPhase() {
        var e=ScrollEngine(); var s=ScrollSettings(); s.enabled=true; s.acceleration=0
        _ = e.receive(x: 0,y: 2,timestamp: 1,continuous: false,modifiers: [],settings: s)
        var total=0.0, phases:[Int]=[], momentumPhases:[Int]=[]
        for i in 1...300 { if let d=e.tick(1+Double(i)/120) { total += d.y; phases.append(d.phase); momentumPhases.append(d.momentumPhase) } }
        XCTAssertEqual(total,24,accuracy: 0.03); XCTAssertEqual(phases.first,1); XCTAssertTrue(phases.contains(4)); XCTAssertTrue(momentumPhases.contains(1)); XCTAssertEqual(momentumPhases.last,3); XCTAssertFalse(e.isActive)
    }
    func testCancelPhaseAndDirectionChange() {
        var e=ScrollEngine(); var s=ScrollSettings(); s.enabled=true; s.acceleration=0
        _ = e.receive(x: 0,y: 1,timestamp: 1,continuous: false,modifiers: [],settings: s)
        _ = e.receive(x: 0,y: -1,timestamp: 1.01,continuous: false,modifiers: [],settings: s)
        XCTAssertLessThan(e.tick(1.02)?.y ?? 0,0); XCTAssertEqual(e.cancel()?.phase,8); XCTAssertNil(e.tick(1.03))
    }
}
