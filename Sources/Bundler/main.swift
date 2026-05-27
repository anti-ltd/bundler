// Entry point. CLI mode when arguments are present; GUI otherwise.
import Foundation

let cliArgs = Array(CommandLine.arguments.dropFirst())

if !cliArgs.isEmpty {
    Task { @MainActor in
        let code = await BundlerCLI.run(args: cliArgs)
        exit(code)
    }
    RunLoop.main.run()
} else {
    BundlerApp.main()
}
