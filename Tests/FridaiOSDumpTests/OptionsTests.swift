import XCTest
@testable import FridaiOSDump

final class OptionsTests: XCTestCase {

    func testParseEmptyArgsReturnsDefaultOptions() {
        let argv = ["frida-ios-dump"]
        let opts = Options.parse(argv)
        XCTAssertNotNil(opts)
        guard let o = opts else { return }
        XCTAssertFalse(o.listApplications)
        XCTAssertNil(o.outputIPA)
        XCTAssertEqual(o.sshHost, "localhost")
        XCTAssertEqual(o.sshPort, 2222)
        XCTAssertEqual(o.sshUser, "root")
        XCTAssertEqual(o.sshPassword, "alpine")
        XCTAssertNil(o.sshKeyFilename)
        XCTAssertFalse(o.attachOnly)
        XCTAssertFalse(o.verbose)
        XCTAssertNil(o.target)
    }

    func testParseListSetsListApplications() {
        let opts = Options.parse(["frida-ios-dump", "-l"])
        XCTAssertNotNil(opts)
        XCTAssertTrue(opts?.listApplications == true)
    }

    func testParseTargetSetsTarget() {
        let opts = Options.parse(["frida-ios-dump", "com.example.app"])
        XCTAssertNotNil(opts)
        XCTAssertEqual(opts?.target, "com.example.app")
    }

    func testParseAttachAndVerbose() {
        let opts = Options.parse(["frida-ios-dump", "-a", "-v", "com.example.app"])
        XCTAssertNotNil(opts)
        XCTAssertTrue(opts?.attachOnly == true)
        XCTAssertTrue(opts?.verbose == true)
        XCTAssertEqual(opts?.target, "com.example.app")
    }

    func testParseOutputName() {
        let opts = Options.parse(["frida-ios-dump", "-o", "MyApp", "com.example.app"])
        XCTAssertNotNil(opts)
        XCTAssertEqual(opts?.outputIPA, "MyApp")
        XCTAssertEqual(opts?.target, "com.example.app")
    }

    func testParseSSHOptions() {
        let opts = Options.parse([
            "frida-ios-dump", "-H", "192.168.1.1", "-p", "22", "-u", "mobile",
            "-P", "secret", "-K", "/path/to/key", "com.example.app"
        ])
        XCTAssertNotNil(opts)
        XCTAssertEqual(opts?.sshHost, "192.168.1.1")
        XCTAssertEqual(opts?.sshPort, 22)
        XCTAssertEqual(opts?.sshUser, "mobile")
        XCTAssertEqual(opts?.sshPassword, "secret")
        XCTAssertEqual(opts?.sshKeyFilename, "/path/to/key")
    }

    func testParseInvalidPortReturnsNil() {
        let opts = Options.parse(["frida-ios-dump", "-p", "99999", "com.example.app"])
        XCTAssertNil(opts)
    }

    func testParsePortZeroReturnsNil() {
        let opts = Options.parse(["frida-ios-dump", "-p", "0", "com.example.app"])
        XCTAssertNil(opts)
    }

    func testParseHelpReturnsNil() {
        let opts = Options.parse(["frida-ios-dump", "-h"])
        XCTAssertNil(opts)
    }

    func testParseUnrecognizedArgumentReturnsNil() {
        let opts = Options.parse(["frida-ios-dump", "-x", "com.example.app"])
        XCTAssertNil(opts)
    }

    func testParseMissingValueForOutputReturnsNil() {
        let opts = Options.parse(["frida-ios-dump", "-o"])
        XCTAssertNil(opts)
    }

    func testParseValidPortRange() {
        XCTAssertNotNil(Options.parse(["frida-ios-dump", "-p", "1", "com.example.app"]))
        XCTAssertNotNil(Options.parse(["frida-ios-dump", "-p", "65535", "com.example.app"]))
        XCTAssertNotNil(Options.parse(["frida-ios-dump", "-p", "2222", "com.example.app"]))
    }

    func testTimeoutsArePositive() {
        XCTAssertGreaterThan(Options.dumpWaitTimeout, 0)
        XCTAssertGreaterThan(Options.scpSocketTimeout, 0)
    }
}
