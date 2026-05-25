import Foundation

/// Packages a signed .app into a compressed drag-to-install .dmg.
enum DMGEngine {
    static func run(appURL: URL, outputDir: URL, log: BuildEngine.Logger? = nil) async throws {
        let appName = appURL.deletingPathExtension().lastPathComponent
        let dmgURL  = outputDir.appending(path: "\(appName).dmg")
        let staging = FileManager.default.temporaryDirectory
            .appending(path: "bundler-dmg-\(UUID().uuidString.prefix(8))", directoryHint: .isDirectory)

        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }

        try FileManager.default.copyItem(at: appURL, to: staging.appending(path: appURL.lastPathComponent))
        try FileManager.default.createSymbolicLink(
            at: staging.appending(path: "Applications"),
            withDestinationURL: URL(fileURLWithPath: "/Applications")
        )

        try? FileManager.default.removeItem(at: dmgURL)

        let cmd = "hdiutil create -volname \"\(appName)\" -srcfolder \"\(staging.path)\" -ov -format UDZO \"\(dmgURL.path)\""
        if let log {
            try await BuildEngine.shell(cmd, log: log)
        } else {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", cmd]
            try process.run()
            process.waitUntilExit()
        }
    }
}
