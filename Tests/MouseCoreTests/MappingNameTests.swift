import XCTest
@testable import MouseCore
final class MappingNameTests: XCTestCase {
    func testOldMappingWithoutNameStillLoads() throws {
        var c = Configuration(); c.globalDefaults.mappings = [Mapping(button:3,action:.spaceLeft)]
        let restored = try ConfigurationCodec.decode(ConfigurationCodec.encode(c))
        XCTAssertNil(restored.globalDefaults.mappings[0].name)
        XCTAssertEqual(restored.globalDefaults.mappings[0].action,.spaceLeft)
    }
    func testNameSurvivesSaveAndImport() throws {
        var c = Configuration(); var m = Mapping(button:3,action:.missionControl); m.name = "ဘေးအောက် ဖိထား"; c.globalDefaults.mappings = [m]
        let imported = try ConfigurationCodec.preview(ConfigurationCodec.encode(c))
        XCTAssertEqual(imported.configuration.globalDefaults.mappings[0].name,m.name)
        XCTAssertEqual(imported.configuration.globalDefaults.mappings[0].trigger,m.trigger)
    }
    func testOversizedNameRejected() {
        var c = Configuration(); var m = Mapping(button:3,action:.spaceLeft); m.name = String(repeating:"x",count:151); c.globalDefaults.mappings=[m]
        XCTAssertThrowsError(try ConfigurationCodec.encode(c))
    }
}
