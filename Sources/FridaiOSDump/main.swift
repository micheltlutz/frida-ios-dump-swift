import Foundation
import Frida

let args = Array(CommandLine.arguments)
if args.count <= 1 || args.contains("-h") || args.contains("--help") {
    Options.printHelp()
    exit(0)
}
guard let options = Options.parse(args) else {
    exit(1)
}

Task {
    do {
        try await DumpRunner.run(options: options)
        exit(0)
    } catch {
        print("Error: \(error)")
        if let fridaError = error as? Frida.Error {
            switch fridaError {
            case .transport, .timedOut:
                print("Tip: With Frida 17 only attach (-a) works. Open the app on the device and try: frida-ios-dump -a \(options.target ?? "<bundle_id>")")
            default:
                break
            }
        } else if "\(error)".lowercased().contains("timeout") || "\(error)".lowercased().contains("transport") || "\(error)".lowercased().contains("connection is closed") {
            print("Tip: With Frida 17 only attach (-a) works. Open the app on the device and try: frida-ios-dump -a \(options.target ?? "<bundle_id>")")
        }
        exit(1)
    }
}
dispatchMain()
