import Foundation
import Observation

@MainActor
@Observable
final class BundlerModel {
    var modules: [ModuleEntry] = []
    var bundles: [BundleDefinition] = []
    var buildLogs: [UUID: BuildLog] = [:]  // keyed by BundleDefinition.id

    private let store = BundlerStore()

    init() {
        modules = store.loadModules()
        bundles = store.loadBundles()
    }

    // MARK: - Modules

    func addModule(_ entry: ModuleEntry) {
        modules.append(entry)
        store.saveModules(modules)
    }

    func removeModule(id: UUID) {
        modules.removeAll { $0.id == id }
        store.saveModules(modules)
    }

    func updateModule(_ entry: ModuleEntry) {
        if let idx = modules.firstIndex(where: { $0.id == entry.id }) {
            modules[idx] = entry
            store.saveModules(modules)
        }
    }

    // MARK: - Bundles

    func addBundle(_ definition: BundleDefinition) {
        bundles.append(definition)
        store.saveBundles(bundles)
    }

    func removeBundle(id: UUID) {
        bundles.removeAll { $0.id == id }
        buildLogs.removeValue(forKey: id)
        store.saveBundles(bundles)
    }

    func updateBundle(_ definition: BundleDefinition) {
        if let idx = bundles.firstIndex(where: { $0.id == definition.id }) {
            bundles[idx] = definition
            store.saveBundles(bundles)
        }
    }

    func modules(for bundle: BundleDefinition) -> [ModuleEntry] {
        bundle.moduleIDs.compactMap { id in modules.first { $0.id == id } }
    }

    // MARK: - Build

    func build(_ definition: BundleDefinition) async {
        var log = BuildLog(bundleID: definition.id)
        log.state = .running
        buildLogs[definition.id] = log

        let success = await BuildEngine.run(
            definition: definition,
            modules: modules(for: definition),
            onEntry: { [weak self] entry in
                Task { @MainActor in self?.buildLogs[definition.id]?.entries.append(entry) }
            }
        )
        buildLogs[definition.id]?.state = success ? .succeeded : .failed
    }

    // MARK: - Single-app wrap / DMG helpers (standalone tools)

    func wrapBinary(binaryURL: URL, name: String, bundleID: String, iconURL: URL?, outputDir: URL) async {
        await WrapEngine.run(
            binaryURL: binaryURL,
            name: name,
            bundleID: bundleID,
            iconURL: iconURL,
            outputDir: outputDir
        )
    }

    func buildDMG(appURL: URL, outputDir: URL) async {
        try? await DMGEngine.run(appURL: appURL, outputDir: outputDir)
    }
}
