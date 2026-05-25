import Foundation

/// A registered *Core package that Bundler knows about.
/// Persisted to disk; path points to the package's root (where Package.swift lives).
struct ModuleEntry: Identifiable, Codable, Hashable {
    var id: UUID = .init()
    var path: String           // absolute path to the *Core package
    var moduleID: String       // e.g. "ltd.anti.clonk" — read from ClonkModule.moduleID
    var displayName: String    // e.g. "Clonk"
    var symbolName: String     // SF Symbol
    var targetName: String     // SPM target name, e.g. "ClonkCore"
    var version: String = ""   // optional — shown in the module list

    var packageURL: URL { URL(fileURLWithPath: path) }
}
