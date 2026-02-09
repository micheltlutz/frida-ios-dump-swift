import Foundation

/// Builds the final .ipa from the Payload directory and file mapping (dump basename -> path inside .app).
enum IPABuilder {
    /// Reorganize Payload: move each item (except "app") into Payload/<appName>/<relativePath>
    /// so the layout matches a valid .app; then zip to <displayName>.ipa in cwd.
    /// - Parameters:
    ///   - payloadPath: Directory containing Payload (e.g. /tmp/Payload)
    ///   - fileDict: Maps basename of downloaded dir/file -> path relative to .app (e.g. "Foo" -> "Frameworks/Foo.framework")
    ///   - appName: Basename of the .app folder (e.g. "MyApp.app")
    ///   - outputName: Name of the IPA file without extension (e.g. "MyApp")
    ///   - cwd: Directory to write the .ipa file in (e.g. current working directory)
    static func buildIPA(
        payloadPath: String,
        fileDict: [String: String],
        appName: String,
        outputName: String,
        cwd: String
    ) throws {
        let payloadURL = URL(fileURLWithPath: payloadPath)
        guard let appRelative = fileDict["app"] else {
            throw NSError(domain: "IPABuilder", code: -1, userInfo: [NSLocalizedDescriptionKey: "fileDict must contain 'app' key"])
        }
        let appDir = payloadURL.appendingPathComponent(appRelative)

        for (key, value) in fileDict where key != "app" {
            let fromDir = payloadURL.appendingPathComponent(key)
            let toDir = appDir.appendingPathComponent(value)
            if FileManager.default.fileExists(atPath: fromDir.path) {
                try FileManager.default.createDirectory(at: toDir.deletingLastPathComponent(), withIntermediateDirectories: true)
                if FileManager.default.fileExists(atPath: toDir.path) {
                    try FileManager.default.removeItem(at: toDir)
                }
                try FileManager.default.moveItem(at: fromDir, to: toDir)
            }
        }

        let ipaFilename = outputName.hasSuffix(".ipa") ? outputName : "\(outputName).ipa"
        let ipaURL = URL(fileURLWithPath: cwd).appendingPathComponent(ipaFilename)
        let payloadParent = payloadURL.deletingLastPathComponent()
        let payloadDirName = payloadURL.lastPathComponent

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-qr", ipaURL.path, payloadDirName]
        process.currentDirectoryURL = payloadParent
        process.standardOutput = FileHandle.nullDevice
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let pipe = process.standardError as! Pipe
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let err = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "IPABuilder", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "zip failed: \(err)"])
        }

        try? FileManager.default.removeItem(at: payloadURL)
        print("Generated \"\(ipaFilename)\"")
    }
}
