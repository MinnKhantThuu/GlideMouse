import XCTest
@testable import MouseCore
final class GestureRegressionTests: XCTestCase {
    func testImmediateMultiTapUsesSingleMouseBinding() {
        let p = Profile(mappings: [.init(trigger: .init(kind: .tap),action: .leftClick)])
        XCTAssertEqual(ProfileResolver.resolveGesture(trigger: .init(kind: .tap,clicks: 2),bundleID: nil,deviceID: nil,profiles: [p])?.mapping.action,.leftClick)
    }
    func testDisabledZoneDoesNotFallBackToLeftClick() {
        let p = Profile(mappings: [.init(trigger: .init(kind: .tap),action: .leftClick),.init(trigger: .init(kind: .rightTap),action: .rightClick,enabled: false)])
        XCTAssertEqual(ProfileResolver.resolveGesture(trigger: .init(kind: .rightTap),bundleID: nil,deviceID: nil,profiles: [p])?.mapping.enabled,false)
    }
    func testNativeScrollBeforeContactQuarantinesUntilLift() {
        var e = GestureEngine(); e.cancelForNativeScroll()
        _ = e.process(.init(timestamp: 1,contacts: [.init(id: 1,x: 0.4,y: 0.5)]))
        XCTAssertTrue(e.process(.init(timestamp: 1.1,contacts: [])).isEmpty)
        _ = e.process(.init(timestamp: 2,contacts: [.init(id: 1,x: 0.4,y: 0.5)]))
        XCTAssertEqual(e.process(.init(timestamp: 2.1,contacts: [])).first?.trigger.kind,.tap)
    }
    func testFourFingerContactDoesNotTriggerThreeFingerAction() {
        var e = GestureEngine(); let start=(1...4).map { TouchPoint(id: $0,x: Double($0)*0.12,y: 0.4) }; let end=start.map { TouchPoint(id: $0.id,x: $0.x+0.2,y: $0.y) }
        _ = e.process(.init(timestamp: 1,contacts: start)); XCTAssertTrue(e.process(.init(timestamp: 1.1,contacts: end)).isEmpty); XCTAssertTrue(e.process(.init(timestamp: 1.2,contacts: [])).isEmpty)
    }
}
