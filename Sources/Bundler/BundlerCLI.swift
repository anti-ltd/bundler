import Foundation
import Synchronization

// CLI surface for Bundler — invoked when the binary is launched with arguments.
// Designed to be machine-readable (--json) so other tools can drive builds
// without knowing Bundler's internals.
//
//   bundler list [--json]
//   bundler build <bundle-id|slug|name> [--json]
//   bundler dmg   <app-path>
//   bundler wrap  <binary-path> --name <n> --bundle-id <id> [--icon <path>] [--out <dir>]

@MainActor
enum BundlerCLI {

    static func run(args: [String]) async -> Int32 {
        guard let cmd = args.first else { printUsage(); return 1 }

        let rest        = Array(args.dropFirst())
        let flags       = parseFlags(rest)
        let positional  = rest.filter { !$0.hasPrefix("--") }
        let isJSON      = flags["json"] != nil

        switch cmd {
        case "list":            return listCmd(json: isJSON)
        case "build":
            guard let id = positional.first else {
                err("Usage: bundler build <bundle-id|slug|name> [--json]"); return 1
            }
            return await buildCmd(id: id, json: isJSON)
        case "dmg":
            guard let path = positional.first else {
                err("Usage: bundler dmg <app-path>"); return 1
            }
            return await dmgCmd(appPath: path)
        case "wrap":
            guard let binary = positional.first,
                  let name = flags["name"], let bundleID = flags["bundle-id"] else {
                err("Usage: bundler wrap <binary> --name <n> --bundle-id <id> [--icon <path>] [--out <dir>]")
                return 1
            }
            return await wrapCmd(binaryPath: binary, name: name, bundleID: bundleID,
                                  iconPath: flags["icon"], outDir: flags["out"])
        default:
            printUsage(); return 1
        }
    }

    // MARK: - list

    private static func listCmd(json: Bool) -> Int32 {
        let store   = BundlerStore()
        let modules = store.loadModules()
        let bundles = store.loadBundles()

        if json {
            struct Out: Encodable {
                struct Mod: Encodable {
                    let id: String; let displayName: String
                    let targetName: String; let path: String; let version: String
                }
                struct Bun: Encodable {
                    let id: String; let name: String; let bundleID: String
                    let slug: String; let moduleIDs: [String]; let outputDirectory: String
                    let buildDMG: Bool
                }
                let modules: [Mod]; let bundles: [Bun]
            }
            let out = Out(
                modules: modules.map { .init(id: $0.id.uuidString, displayName: $0.displayName,
                                              targetName: $0.targetName, path: $0.path, version: $0.version) },
                bundles: bundles.map { .init(id: $0.id.uuidString, name: $0.name,
                                              bundleID: $0.bundleID, slug: $0.slug,
                                              moduleIDs: $0.moduleIDs.map(\.uuidString),
                                              outputDirectory: $0.outputDirectory, buildDMG: $0.buildDMG) }
            )
            let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? enc.encode(out), let str = String(data: data, encoding: .utf8) {
                print(str)
            }
        } else {
            print("Modules (\(modules.count)):")
            for m in modules {
                let ver = m.version.isEmpty ? "" : " v\(m.version)"
                print("  \(m.displayName.padding(toLength: 22, withPad: " ", startingAt: 0))\(m.targetName)\(ver)")
                print("  \("".padding(toLength: 22, withPad: " ", startingAt: 0))\(m.path)")
            }
            print("\nBundles (\(bundles.count)):")
            for b in bundles {
                let names = b.moduleIDs
                    .compactMap { id in modules.first { $0.id == id }?.displayName }
                    .joined(separator: ", ")
                print("  \(b.id.uuidString)  \(b.name.padding(toLength: 28, withPad: " ", startingAt: 0))[\(names)]")
                print("  \("".padding(toLength: 38, withPad: " ", startingAt: 0))→ \(b.outputDirectory)")
            }
        }
        return 0
    }

    // MARK: - build

    private static func buildCmd(id: String, json: Bool) async -> Int32 {
        let store   = BundlerStore()
        let modules = store.loadModules()
        let bundles = store.loadBundles()

        guard let definition = bundles.first(where: {
            $0.id.uuidString == id || $0.slug == id || $0.name == id
        }) else {
            err("No bundle found with id/slug/name: \(id)")
            return 1
        }

        let bundleModules = definition.moduleIDs.compactMap { mid in modules.first { $0.id == mid } }

        struct JSONEntry: Encodable, Sendable { let kind: String; let text: String }
        let entriesBox = Mutex<[JSONEntry]>([])

        let success = await BuildEngine.run(
            definition: definition,
            modules: bundleModules,
            onEntry: { entry in
                let prefix: String = switch entry.kind {
                case .success: "✓ "; case .error: "✗ "; case .command: "$ "; default: "  "
                }
                if !json { print(prefix + entry.text); fflush(stdout) }
                entriesBox.withLock { $0.append(.init(kind: "\(entry.kind)", text: entry.text)) }
            }
        )

        if json {
            let jsonEntries = entriesBox.withLock { $0 }
            struct Out: Encodable { let ok: Bool; let entries: [JSONEntry] }
            let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted]
            if let data = try? enc.encode(Out(ok: success, entries: jsonEntries)),
               let str = String(data: data, encoding: .utf8) { print(str) }
        } else {
            print(success ? "✓ Build succeeded." : "✗ Build failed.")
        }
        return success ? 0 : 1
    }

    // MARK: - dmg

    private static func dmgCmd(appPath: String) async -> Int32 {
        let appURL = URL(fileURLWithPath: (appPath as NSString).expandingTildeInPath)
        let outDir = appURL.deletingLastPathComponent()
        do {
            try await DMGEngine.run(appURL: appURL, outputDir: outDir)
            print("✓ \(outDir.appending(path: appURL.deletingPathExtension().lastPathComponent + ".dmg").path)")
            return 0
        } catch {
            err(error.localizedDescription); return 1
        }
    }

    // MARK: - wrap

    private static func wrapCmd(
        binaryPath: String, name: String, bundleID: String,
        iconPath: String?, outDir: String?
    ) async -> Int32 {
        let binaryURL = URL(fileURLWithPath: (binaryPath as NSString).expandingTildeInPath)
        let iconURL   = iconPath.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
        let outputDir = URL(fileURLWithPath: ((outDir ?? ".") as NSString).expandingTildeInPath)
        await WrapEngine.run(binaryURL: binaryURL, name: name, bundleID: bundleID,
                              iconURL: iconURL, outputDir: outputDir)
        print("✓ \(outputDir.appending(path: "\(name).app").path)")
        return 0
    }

    // MARK: - Helpers

    private static func parseFlags(_ args: [String]) -> [String: String] {
        var flags: [String: String] = [:]
        var i = args.startIndex
        while i < args.endIndex {
            let arg = args[i]
            if arg.hasPrefix("--") {
                let key = String(arg.dropFirst(2))
                let next = args.index(after: i)
                if next < args.endIndex && !args[next].hasPrefix("--") {
                    flags[key] = args[next]
                    i = args.index(after: next)
                } else {
                    flags[key] = ""
                    i = args.index(after: i)
                }
            } else {
                i = args.index(after: i)
            }
        }
        return flags
    }

    private static func err(_ message: String) {
        fputs("\(message)\n", stderr)
    }

    private static func printUsage() {
        print("""
        bundler — app bundle builder

          bundler list   [--json]
          bundler build  <bundle-id|slug|name>  [--json]
          bundler dmg    <app-path>
          bundler wrap   <binary> --name <n> --bundle-id <id>  [--icon <path>]  [--out <dir>]
        """)
    }
}
