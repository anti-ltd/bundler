import Foundation

/// A complete bundle product definition — what goes in, what comes out.
struct BundleDefinition: Identifiable, Codable, Hashable {
    var id: UUID = .init()
    var name: String                    // e.g. "Mac Novelty Bundle"
    var bundleID: String                // e.g. "ltd.anti.novelty"
    var executableName: String          // binary name inside .app/Contents/MacOS/
    var moduleIDs: [UUID] = []          // ordered list of ModuleEntry.id
    var iconModuleID: UUID? = nil       // which module's icon renderer to use (nil = generate generic)
    var signingIdentity: String = "-"   // codesign identity, "-" for ad-hoc
    var outputDirectory: String = "~/Desktop"
    var buildDMG: Bool = true

    var slug: String {
        executableName.lowercased().replacingOccurrences(of: " ", with: "-")
    }
}
