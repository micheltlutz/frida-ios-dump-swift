import Foundation
import Frida

/// Orchestrates device discovery, app spawn/attach, dump script loading, SCP, and IPA generation.
enum DumpRunner {
    static func run(options: Options) async throws {
        let verbose = options.verbose
        if verbose { print("[verbose] Creating device manager...") }
        let manager = DeviceManager()
        if verbose { print("[verbose] Waiting for USB device...") }
        let device = try await waitForUSBDevice(manager: manager)
        if verbose { print("[verbose] Found device: \(device.name) (\(device.id))") }

        if options.listApplications {
            if verbose { print("[verbose] Enumerating applications...") }
            try await listApplications(device: device)
            return
        }

        guard let target = options.target else {
            print("Error: target (bundle id or app name) required. Use -l to list applications.")
            throw NSError(domain: "DumpRunner", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing target"])
        }

        if verbose { print("[verbose] Enumerating applications to resolve '\(target)'...") }
        let applications = try await device.enumerateApplications()
        guard let app = applications.first(where: { $0.identifier == target || $0.name == target }) else {
            print("App not found: \(target)")
            throw NSError(domain: "DumpRunner", code: -1, userInfo: [NSLocalizedDescriptionKey: "App not found"])
        }
        if verbose { print("[verbose] Found app: \(app.name) (\(app.identifier)), pid: \(app.pid.map { "\($0)" } ?? "none")") }

        if options.attachOnly, app.pid == nil {
            print("App not running. Open the app on the device and run again (e.g. frida-ios-dump -a <bundle_id>).")
            throw NSError(domain: "DumpRunner", code: -1, userInfo: [NSLocalizedDescriptionKey: "App not running"])
        }

        print("Start the target app \(target)")
        let pid: UInt
        if let p = app.pid {
            pid = p
            if verbose { print("[verbose] Attaching to existing process PID \(pid)...") }
        } else {
            if verbose { print("[verbose] Spawning app (this may timeout on some devices)...") }
            pid = try await device.spawn(app.identifier)
            if verbose { print("[verbose] Spawned PID \(pid), waiting 0.2s before attach...") }
            try await Task.sleep(nanoseconds: 200_000_000)
        }

        if verbose { print("[verbose] Attaching session to PID \(pid)...") }
        let session = try await device.attach(to: pid)
        if app.pid == nil {
            if verbose { print("[verbose] Resuming process...") }
            try await device.resume(pid)
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        let displayName = app.name
        let outputName = (options.outputIPA ?? displayName).replacingOccurrences(of: ".ipa", with: "")
        let tempDir = FileManager.default.temporaryDirectory.path
        print("Dumping \(displayName) to \(tempDir)")

        SSHSCP.timeoutSeconds = Options.scpSocketTimeout
        let payloadPath = FileManager.default.temporaryDirectory.appendingPathComponent("Payload").path
        if FileManager.default.fileExists(atPath: payloadPath) {
            try FileManager.default.removeItem(atPath: payloadPath)
        }
        try FileManager.default.createDirectory(atPath: payloadPath, withIntermediateDirectories: true)

        if verbose { print("[verbose] Loading dump.js from bundle/exec dir/CWD...") }
        let scriptSource = try loadDumpJS()
        if verbose { print("[verbose] Creating script (\(scriptSource.count) bytes)...") }
        let script = try await session.createScript(scriptSource)
        let state = DumpState()
        let messageTask = Task {
            for await event in script.events {
                if case .message(let message, _) = event {
                    await state.handleMessage(
                        message: message,
                        options: options,
                        payloadPath: payloadPath
                    )
                }
            }
        }

        if verbose { print("[verbose] Loading script into session (this may timeout if app is not in foreground)...") }
        try await script.load()
        if verbose { print("[verbose] Script loaded, posting 'dump'...") }
        script.post("dump")

        let finished = await state.waitForDone(timeout: Options.dumpWaitTimeout)
        messageTask.cancel()

        if !finished {
            print("Timeout (\(Int(Options.dumpWaitTimeout))s) waiting for dump/SCP. Check: app in foreground, SSH (iproxy 2222 22), frida-server.")
            try? await session.detach()
            throw NSError(domain: "DumpRunner", code: -1, userInfo: [NSLocalizedDescriptionKey: "Dump timeout"])
        }

        let fileDict = await state.fileDict
        guard let appDirName = fileDict["app"] else {
            try? await session.detach()
            throw NSError(domain: "DumpRunner", code: -1, userInfo: [NSLocalizedDescriptionKey: "No app path received"])
        }

        try IPABuilder.buildIPA(
            payloadPath: payloadPath,
            fileDict: fileDict,
            appName: appDirName,
            outputName: outputName,
            cwd: FileManager.default.currentDirectoryPath
        )

        try? await session.detach()
    }

    // MARK: - Helpers

    private static func waitForUSBDevice(manager: DeviceManager) async throws -> Device {
        for await snapshot in await manager.snapshots() {
            if let usb = snapshot.first(where: { $0.kind == .usb }) {
                return usb
            }
            print("Waiting for USB device...")
        }
        fatalError("Unreachable")
    }

    private static func listApplications(device: Device) async throws {
        let applications = try await device.enumerateApplications()
        let sorted = applications.sorted { a, b in
            let aRunning = a.pid != nil
            let bRunning = b.pid != nil
            if aRunning != bRunning { return aRunning }
            return a.name < b.name
        }
        let pidW = max(3, sorted.map { $0.pid.map { "\($0)" } ?? "-" }.map(\.count).max() ?? 3)
        let nameW = sorted.map(\.name.count).max() ?? 4
        let idW = sorted.map(\.identifier.count).max() ?? 11
        print(String(repeating: " ", count: pidW) + "  " + "Name".padding(toLength: nameW, withPad: " ", startingAt: 0) + "  " + "Identifier".padding(toLength: idW, withPad: " ", startingAt: 0))
        print(String(repeating: "-", count: pidW) + "  " + String(repeating: "-", count: nameW) + "  " + String(repeating: "-", count: idW))
        for app in sorted {
            let pidStr = app.pid.map { "\($0)" } ?? "-"
            print(pidStr.padding(toLength: pidW, withPad: " ", startingAt: 0) + "  " + app.name.padding(toLength: nameW, withPad: " ", startingAt: 0) + "  " + app.identifier.padding(toLength: idW, withPad: " ", startingAt: 0))
        }
    }

    /// Load dump.js from Bundle.module (SPM resource) or next to executable / CWD.
    private static func loadDumpJS() throws -> String {
        if let url = Bundle.module.url(forResource: "dump", withExtension: "js"),
           let s = try? String(contentsOf: url, encoding: .utf8) {
            return s
        }
        let execURL = URL(fileURLWithPath: CommandLine.arguments[0])
        let execDir = execURL.deletingLastPathComponent()
        let candidate = execDir.appendingPathComponent("dump.js")
        if let s = try? String(contentsOf: candidate, encoding: .utf8) {
            return s
        }
        let cwd = FileManager.default.currentDirectoryPath
        let cwdURL = URL(fileURLWithPath: cwd).appendingPathComponent("dump.js")
        if let s = try? String(contentsOf: cwdURL, encoding: .utf8) {
            return s
        }
        throw NSError(domain: "DumpRunner", code: -1, userInfo: [NSLocalizedDescriptionKey: "dump.js not found (Bundle, executable dir, or CWD)"])
    }
}

// MARK: - Dump state (message handling, file dict, done signal)

private actor DumpState {
    var fileDict: [String: String] = [:]
    private(set) var doneReceived = false

    /// Handle a message from the device script. Payload may be wrapped as { type: "send", payload: ... }
    /// or delivered as the payload dict directly. See ADR 0001 for message format (dump/path, app, done).
    func handleMessage(message: Any, options: Options, payloadPath: String) {
        var payload: [String: Any]?
        if let dict = message as? [String: Any] {
            if let p = dict["payload"] as? [String: Any] {
                payload = p
            } else if dict["type"] as? String == "log" {
                if options.verbose, let s = dict["payload"] as? String {
                    print("[device] \(s)")
                }
                return
            } else if dict["type"] as? String == "error" {
                // Always print script errors so user sees why dump stopped (e.g. TypeError in dump.js).
                let desc = (dict["description"] as? String) ?? "\(dict)"
                let stack = dict["stack"] as? String ?? ""
                print("[device] error: \(desc)")
                if !stack.isEmpty { print(stack) }
                return
            } else if options.verbose, dict["payload"] == nil {
                print("[verbose] raw message: \(dict)")
            } else {
                payload = dict
            }
        }
        if let payload = payload {
            if let logPayload = payload["payload"] as? String {
                if options.verbose { print("[device] \(logPayload)") }
                return
            }
            if let dumpPath = payload["dump"] as? String, !dumpPath.isEmpty {
                let originPath = payload["path"] as? String ?? ""
                if options.verbose { print("[verbose] SCP get: \(dumpPath)") }
                do {
                    try SSHSCP.copy(
                        remotePath: dumpPath,
                        toLocalDir: payloadPath,
                        recursive: false,
                        host: options.sshHost,
                        port: options.sshPort,
                        user: options.sshUser,
                        password: options.sshPassword,
                        keyFilename: options.sshKeyFilename
                    )
                } catch {
                    print("SCP error: \(error)")
                }
                if options.verbose { print("[verbose] SCP done: \((dumpPath as NSString).lastPathComponent)") }
                let basename = (dumpPath as NSString).lastPathComponent
                if let range = originPath.range(of: ".app/") {
                    let rel = String(originPath[range.upperBound...])
                    fileDict[basename] = rel
                }
                return
            }
            if let appPath = payload["app"] as? String {
                if options.verbose { print("[verbose] SCP get app (recursive): \(appPath)") }
                do {
                    try SSHSCP.copy(
                        remotePath: appPath,
                        toLocalDir: payloadPath,
                        recursive: true,
                        host: options.sshHost,
                        port: options.sshPort,
                        user: options.sshUser,
                        password: options.sshPassword,
                        keyFilename: options.sshKeyFilename
                    )
                } catch {
                    print("SCP error: \(error)")
                }
                if options.verbose { print("[verbose] SCP app done") }
                fileDict["app"] = (appPath as NSString).lastPathComponent
                return
            }
            if payload["done"] != nil {
                if options.verbose { print("[verbose] received done") }
                doneReceived = true
            }
        }
    }

    /// Poll until done is received or timeout. Returns true if done was received.
    func waitForDone(timeout: TimeInterval) async -> Bool {
        let step: TimeInterval = 0.2
        var elapsed: TimeInterval = 0
        while elapsed < timeout {
            if doneReceived { return true }
            try? await Task.sleep(nanoseconds: UInt64(step * 1_000_000_000))
            elapsed += step
        }
        return doneReceived
    }
}
