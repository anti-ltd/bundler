import Foundation

/// Wraps any standalone binary into a .app bundle with an icon and Info.plist.
enum WrapEngine {
    static func run(
        binaryURL: URL,
        name: String,
        bundleID: String,
        iconURL: URL?,
        outputDir: URL
    ) async {
        do {
            let appURL = outputDir.appending(path: "\(name).app")
            let macOS     = appURL.appending(path: "Contents/MacOS")
            let resources = appURL.appending(path: "Contents/Resources")
            try FileManager.default.createDirectory(at: macOS,     withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)

            // Binary
            let binaryName = binaryURL.lastPathComponent
            try? FileManager.default.removeItem(at: macOS.appending(path: binaryName))
            try FileManager.default.copyItem(at: binaryURL, to: macOS.appending(path: binaryName))

            // Icon
            if let iconURL {
                let dest = resources.appending(path: "AppIcon.icns")
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.copyItem(at: iconURL, to: dest)
            }

            // Info.plist
            let plist = infoPlist(name: name, bundleID: bundleID, executable: binaryName, hasIcon: iconURL != nil)
            try plist.write(to: appURL.appending(path: "Contents/Info.plist"), atomically: true, encoding: .utf8)
        } catch {
            print("WrapEngine error: \(error)")
        }
    }

    private static func infoPlist(name: String, bundleID: String, executable: String, hasIcon: Bool) -> String {
        var lines = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleExecutable</key>
            <string>\(executable)</string>
            <key>CFBundleIdentifier</key>
            <string>\(bundleID)</string>
            <key>CFBundleName</key>
            <string>\(name)</string>
            <key>CFBundlePackageType</key>
            <string>APPL</string>
            <key>CFBundleShortVersionString</key>
            <string>1.0</string>
            <key>CFBundleVersion</key>
            <string>1</string>
            <key>LSMinimumSystemVersion</key>
            <string>26.0</string>
        """
        if hasIcon {
            lines += "\n    <key>CFBundleIconFile</key>\n    <string>AppIcon</string>"
        }
        lines += "\n</dict>\n</plist>"
        return lines
    }
}
