import XCTest
@testable import MouseCore
final class ProfileResolverTests: XCTestCase {
    func testPriorityAndDisabledOverride() {
        let profiles = [Profile(mappings: [Mapping(button: 2, action: .middleClick)]), Profile(deviceID: "mouse", mappings: [Mapping(button: 2, action: .back)]), Profile(bundleID: "browser", mappings: [Mapping(button: 2, action: .forward)]), Profile(bundleID: "browser", deviceID: "mouse", mappings: [Mapping(button: 2, action: .none, enabled: false)])]
        XCTAssertEqual(ProfileResolver.resolve(button: 2, bundleID: "browser", deviceID: "mouse", profiles: profiles)?.enabled, false)
        XCTAssertEqual(ProfileResolver.resolve(button: 2, bundleID: "browser", deviceID: nil, profiles: profiles)?.action, .forward)
        XCTAssertEqual(ProfileResolver.resolve(button: 2, bundleID: nil, deviceID: "mouse", profiles: profiles)?.action, .back)
        XCTAssertEqual(ProfileResolver.resolve(button: 2, bundleID: nil, deviceID: nil, profiles: profiles)?.action, .middleClick)
    }
    func testUnmappedInputAndInheritance() {
        let profiles = [Profile(mappings: [Mapping(button: 2, action: .middleClick)]), Profile(bundleID: "browser", mappings: [])]
        XCTAssertNil(ProfileResolver.resolve(button: 9, bundleID: "browser", deviceID: nil, profiles: profiles))
        XCTAssertEqual(ProfileResolver.resolve(button: 2, bundleID: "browser", deviceID: nil, profiles: profiles)?.action, .middleClick)
    }
    func testDisplayedBindingsRemainInButtonOrderAcrossRefreshes() {
        let expected = [Trigger(button: 3), Trigger(button: 3, clicks: 2), Trigger(kind: .buttonHold, button: 3), Trigger(button: 4)]
        let mappings = expected.map { Mapping(trigger: $0, action: .spaceLeft) }
        var observedOrders = Set<[Trigger]>()
        for refresh in 0..<100 {
            let rotation = refresh % mappings.count
            let rotated = Array(mappings[rotation...]) + Array(mappings[..<rotation])
            observedOrders.insert(ProfileResolver.displayTriggers(in: [Profile(mappings: rotated)]))
        }
        XCTAssertEqual(observedOrders.count, 1, "Refreshes must not reorder an unchanged list")
        XCTAssertEqual(observedOrders.first, expected, "Group each button's click/double/hold before the next button")
    }
    func testDisplayOrderCoversGestureFieldsAndIgnoresActionUpdates() {
        let variants = [Trigger(button: 3), Trigger(button: 3, modifiers: .command), Trigger(kind: .buttonDrag, button: 3, direction: .left), Trigger(kind: .buttonDrag, button: 3, direction: .right), Trigger(kind: .buttonChord, button: 3, chordButton: 4), Trigger(kind: .buttonChord, button: 3, chordButton: 5), Trigger(kind: .tap, fingers: 1), Trigger(kind: .tap, fingers: 2), Trigger(kind: .swipe, fingers: 2, direction: .left), Trigger(kind: .swipe, fingers: 2, direction: .right)]
        let global = Profile(mappings: variants.map { Mapping(trigger: $0, action: .back) })
        let baseline = ProfileResolver.displayTriggers(in: [global])
        var observedOrders = Set<[Trigger]>()
        for refresh in 0..<100 {
            // Same trigger in an app override, including a disabled action, keeps one row.
            let app = Profile(bundleID: "browser", mappings: [Mapping(trigger: variants[refresh % variants.count], action: refresh.isMultiple(of: 2) ? .forward : .none, enabled: refresh.isMultiple(of: 2))])
            observedOrders.insert(ProfileResolver.displayTriggers(in: [app, global]))
        }
        XCTAssertEqual(baseline, variants)
        XCTAssertEqual(observedOrders, [baseline])
    }

}
