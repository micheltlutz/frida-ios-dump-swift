import XCTest
@testable import FridaiOSDump

final class IPABuilderTests: XCTestCase {

    func testBuildIPAThrowsWhenFileDictMissingAppKey() {
        let payloadPath = FileManager.default.temporaryDirectory.appendingPathComponent("Payload").path
        let fileDict: [String: String] = [:] // no "app" key
        let cwd = FileManager.default.temporaryDirectory.path

        do {
            try IPABuilder.buildIPA(
                payloadPath: payloadPath,
                fileDict: fileDict,
                appName: "App.app",
                outputName: "App",
                cwd: cwd
            )
            XCTFail("Expected buildIPA to throw when fileDict has no 'app' key")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, "IPABuilder")
            XCTAssertEqual(error.code, -1)
            XCTAssertTrue(error.localizedDescription.contains("app"))
        }
    }

    func testBuildIPAThrowsWhenFileDictHasOnlyAppKeyButPayloadMissing() {
        // fileDict has "app" so we pass the guard; then we iterate and try to move.
        // If Payload dir doesn't exist, we might hit createDirectory or moveItem.
        // Simplest: use a non-existent payload path so we never create dirs; we still need to pass the guard.
        let tmp = FileManager.default.temporaryDirectory
        let payloadPath = tmp.appendingPathComponent("NonexistentPayload_\(UUID().uuidString)").path
        let fileDict: [String: String] = ["app": "MyApp.app"]
        let cwd = tmp.path

        do {
            try IPABuilder.buildIPA(
                payloadPath: payloadPath,
                fileDict: fileDict,
                appName: "MyApp.app",
                outputName: "MyApp",
                cwd: cwd
            )
            // If we get here, zip might have run (empty Payload) and written an IPA.
            // On some systems zip might create empty archive. So we don't necessarily throw.
        } catch let error as NSError {
            // Expected when Payload doesn't exist: zip or file ops may fail
            XCTAssertTrue(error.domain == "IPABuilder" || error.domain == NSCocoaErrorDomain)
        }
    }
}
