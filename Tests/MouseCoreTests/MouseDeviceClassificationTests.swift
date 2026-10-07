import XCTest
@testable import MouseCore

final class MouseDeviceClassificationTests: XCTestCase {
    func testCompositeKeyboardAndTrackpadAreExcluded() {
        XCTAssertFalse(MouseDeviceClassification.isMouse(name: "AULA-F75 5.0 KB ", keyboardCollection: false, touchpadCollection: false))
        XCTAssertFalse(MouseDeviceClassification.isMouse(name: "Apple Internal Keyboard / Trackpad", keyboardCollection: true, touchpadCollection: true))
        XCTAssertFalse(MouseDeviceClassification.isMouse(name: "MX Keys", keyboardCollection: true, touchpadCollection: false))
        XCTAssertFalse(MouseDeviceClassification.isMouse(name: "Unknown", keyboardCollection: false, touchpadCollection: true))
    }
    func testActualMiceRemainVisible() {
        XCTAssertTrue(MouseDeviceClassification.isMouse(name: "BT4.0 Mouse", keyboardCollection: false, touchpadCollection: false))
        XCTAssertTrue(MouseDeviceClassification.isMouse(name: "Magic Mouse", keyboardCollection: false, touchpadCollection: false))
        XCTAssertTrue(MouseDeviceClassification.isMouse(name: "Gaming Mouse", keyboardCollection: true, touchpadCollection: false))
        XCTAssertTrue(MouseDeviceClassification.isMouse(name: "USB Optical Pointer", keyboardCollection: false, touchpadCollection: false))
    }
}
