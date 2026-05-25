import Foundation

struct BundlerStore {
    private let base: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appending(path: "anti-ltd/bundler", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private var modulesURL: URL { base.appending(path: "modules.json") }
    private var bundlesURL: URL { base.appending(path: "bundles.json") }

    func loadModules() -> [ModuleEntry] { load(from: modulesURL) }
    func loadBundles() -> [BundleDefinition] { load(from: bundlesURL) }

    func saveModules(_ items: [ModuleEntry]) { save(items, to: modulesURL) }
    func saveBundles(_ items: [BundleDefinition]) { save(items, to: bundlesURL) }

    private func load<T: Decodable>(from url: URL) -> [T] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([T].self, from: data)) ?? []
    }

    private func save<T: Encodable>(_ value: T, to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url)
    }
}
