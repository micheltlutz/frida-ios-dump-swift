import Foundation

/// Command-line options for frida-ios-dump (parity with Python script).
struct Options {
    var listApplications = false
    var outputIPA: String?
    var sshHost = "localhost"
    var sshPort: Int = 2222
    var sshUser = "root"
    var sshPassword = "alpine"
    var sshKeyFilename: String?
    var attachOnly = false
    var verbose = false
    var target: String?

    static let dumpWaitTimeout: TimeInterval = 600
    static let scpSocketTimeout: TimeInterval = 300

    /// Parse command-line arguments. Returns nil and prints error if invalid.
    static func parse(_ arguments: [String]) -> Options? {
        var opts = Options()
        var args = arguments.dropFirst() // skip program name

        while let arg = args.first {
            args = args.dropFirst()
            switch arg {
            case "-l", "--list":
                opts.listApplications = true
            case "-o", "--output":
                guard let val = args.first else {
                    print("Error: -o requires a value")
                    return nil
                }
                args = args.dropFirst()
                opts.outputIPA = val
            case "-H", "--host":
                guard let val = args.first else {
                    print("Error: -H requires a value")
                    return nil
                }
                args = args.dropFirst()
                opts.sshHost = val
            case "-p", "--port":
                guard let val = args.first, let port = Int(val), port >= 1, port <= 65535 else {
                    print("SSH port must be 1-65535. Use -P (capital P) for password, -p for port (e.g. -p 2222).")
                    return nil
                }
                args = args.dropFirst()
                opts.sshPort = port
            case "-u", "--user":
                guard let val = args.first else {
                    print("Error: -u requires a value")
                    return nil
                }
                args = args.dropFirst()
                opts.sshUser = val
            case "-P", "--password":
                guard let val = args.first else {
                    print("Error: -P requires a value (SSH password, capital -P)")
                    return nil
                }
                args = args.dropFirst()
                opts.sshPassword = val
            case "-K", "--key_filename":
                guard let val = args.first else {
                    print("Error: -K requires a value")
                    return nil
                }
                args = args.dropFirst()
                opts.sshKeyFilename = val
            case "-a", "--attach":
                opts.attachOnly = true
            case "-v", "--verbose":
                opts.verbose = true
            case "-h", "--help":
                print(helpText)
                return nil
            default:
                if arg.hasPrefix("-") {
                    print("Error: unrecognized argument: \(arg)")
                    return nil
                }
                opts.target = arg
            }
        }
        return opts
    }

    static func printHelp() {
        print(helpText)
    }

    private static var helpText: String {
        """
        usage: frida-ios-dump [-h] [-l] [-o OUTPUT_IPA] [-H SSH_HOST] [-p SSH_PORT] [-u SSH_USER]
                   [-P SSH_PASSWORD] [-K SSH_KEY_FILENAME] [-a] [-v] [target]

        Dump decrypted IPA from a jailbroken iOS device via Frida.

        -l, --list              List installed applications (PID, name, identifier)
        -o, --output NAME       Output IPA file name (default: app display name)
        -H, --host HOST         SSH host (default: localhost, use with iproxy)
        -p, --port PORT         SSH port (default: 2222). Use -P for password.
        -u, --user USER         SSH user (default: root)
        -P, --password PASS     SSH password (capital -P)
        -K, --key_filename PATH SSH private key file path
        -a, --attach            Attach to already running app only (no spawn)
        -v, --verbose           Print device script console.log on the host
        target                  Bundle identifier or display name of the target app
        """
    }
}
