import Foundation

/// Runs SCP to copy files from the device (via SSH) to the local Payload directory.
/// Uses Process to invoke `scp`; if password is set, uses `sshpass` when available.
enum SSHSCP {
    /// Copy a single file or directory from remote to localPath (directory).
    /// - Parameters:
    ///   - remotePath: Path on the device (e.g. /var/.../file.fid or /var/.../App.app)
    ///   - localDir: Local directory to copy into (e.g. /tmp/Payload/)
    ///   - recursive: If true, use scp -r for directories
    ///   - host: SSH host (e.g. localhost)
    ///   - port: SSH port (e.g. 2222)
    ///   - user: SSH user (e.g. root)
    ///   - password: If non-nil and sshpass is available, use it for auth
    ///   - keyFilename: If set, use -i keyFilename
    /// Timeout in seconds for a single SCP transfer (default 300). Use 0 to wait indefinitely.
    static var timeoutSeconds: TimeInterval = 300

    static func copy(
        remotePath: String,
        toLocalDir localDir: String,
        recursive: Bool,
        host: String,
        port: Int,
        user: String,
        password: String?,
        keyFilename: String?
    ) throws {
        // Run SCP; use shell when password is set so sshpass -e and path with spaces work.
        let executable: String
        let arguments: [String]
        var env: [String: String]?

        if let pass = password, !pass.isEmpty {
            guard let sshpassPath = findSSHPass() else {
                throw NSError(domain: "SSHSCP", code: -1, userInfo: [NSLocalizedDescriptionKey: "Password provided but sshpass not found. Install with: brew install sshpass. Or use -K with an SSH key and omit -P."])
            }
            let keyOpt = keyFilename.map { " -i '\($0.replacingOccurrences(of: "'", with: "'\"'\"'"))'" } ?? ""
            let recOpt = recursive ? " -r" : ""
            // sshpass -e reads password from SSHPASS env (no password on command line). Path with spaces in $REMOTE.
            let cmd = "exec '\(sshpassPath.replacingOccurrences(of: "'", with: "'\"'\"'"))' -e scp\(recOpt) -P \(port) -o StrictHostKeyChecking=no\(keyOpt) \"$USER@$HOST:$REMOTE\" \"$LOCAL\""
            executable = "/bin/sh"
            arguments = ["-c", cmd]
            env = [
                "SSHPASS": pass,
                "USER": user,
                "HOST": host,
                "REMOTE": remotePath,
                "LOCAL": "\(localDir)/",
            ]
        } else {
            let spec = "\(user)@\(host):\(remotePath)"
            var scpBase = ["-P", "\(port)", "-o", "StrictHostKeyChecking=no"]
            if let key = keyFilename { scpBase.append(contentsOf: ["-i", key]) }
            if recursive { scpBase.append("-r") }
            scpBase.append(contentsOf: [spec, "\(localDir)/"])
            executable = "/usr/bin/scp"
            arguments = scpBase
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let e = env { process.environment = ProcessInfo.processInfo.environment.merging(e) { _, new in new } }
        process.standardOutput = FileHandle.nullDevice
        let stderrPipe = Pipe()
        process.standardError = stderrPipe

        try process.run()

        if timeoutSeconds > 0 {
            let group = DispatchGroup()
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                process.waitUntilExit()
                group.leave()
            }
            let result = group.wait(timeout: .now() + timeoutSeconds)
            if result == .timedOut {
                process.terminate()
                let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let err = String(data: errData, encoding: .utf8) ?? ""
                throw NSError(domain: "SSHSCP", code: -1, userInfo: [NSLocalizedDescriptionKey: "scp timed out after \(Int(timeoutSeconds))s. Check SSH (iproxy), password (-P), and path with spaces. \(err)"])
            }
        } else {
            process.waitUntilExit()
        }

        if process.terminationStatus != 0 {
            let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let err = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "SSHSCP", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "scp failed: \(err)"])
        }
    }

    private static func findSSHPass() -> String? {
        ["/usr/local/bin/sshpass", "/opt/homebrew/bin/sshpass"].first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
