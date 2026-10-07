import XCTest
import NativeBridge
import Darwin
final class NativeCommandTests: XCTestCase {
    func testCommandExitStatusAndIsolatedGroup() {
        let pid = gm_command_spawn("/bin/zsh","exit 7","/tmp","/tmp")
        XCTAssertGreaterThan(pid,0)
        var status:Int32 = 0
        var done:Int32 = 0
        for _ in 0..<100 { done=gm_command_poll(pid,&status); if done != 0 { break }; usleep(10000) }
        XCTAssertEqual(done,1); XCTAssertEqual(status,7)
    }
    func testCancellationKillsDedicatedCommandGroup() {
        let pid = gm_command_spawn("/bin/zsh","sleep 30 & wait","/tmp","/tmp")
        XCTAssertGreaterThan(pid,0); XCTAssertEqual(getpgid(pid),pid)
        usleep(50000); gm_command_cancel(pid,true)
        var status:Int32 = 0; var done:Int32 = 0
        for _ in 0..<100 { done=gm_command_poll(pid,&status); if done != 0 { break }; usleep(10000) }
        XCTAssertEqual(done,1); XCTAssertGreaterThanOrEqual(status,128)
    }
    func testOnlySupportedExecutablesAreLaunched() { XCTAssertEqual(gm_command_spawn("/usr/bin/unknown","x","/tmp","/tmp"),-1) }
}
