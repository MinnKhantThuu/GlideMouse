import XCTest
@testable import MouseCore
final class ShortcutDisplayTests: XCTestCase {
    func testRecordedShortcutIsReadable() { XCTAssertEqual(ShortcutDisplay.label(keyCode:8,modifiers:[.command,.shift]),"⇧⌘C") }
    func testNavigationAndNoModifiers() {
        XCTAssertEqual(ShortcutDisplay.label(keyCode:124,modifiers:.control),"⌃→")
        XCTAssertEqual(ShortcutDisplay.label(keyCode:49,modifiers:[]),"Space")
        XCTAssertEqual(ShortcutDisplay.label(keyCode:127,modifiers:.option),"⌥Key 127")
    }
}
