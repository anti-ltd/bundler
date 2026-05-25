import SwiftUI
import iUX

enum BundlerSection: String, CaseIterable, Identifiable, SidebarItem {
    case modules = "Modules"
    case bundles = "Bundles"
    case tools   = "Tools"

    var id: Self { self }
    var title: String { rawValue }
    var icon: String {
        switch self {
        case .modules: "puzzlepiece.extension"
        case .bundles: "shippingbox"
        case .tools:   "wrench.and.screwdriver"
        }
    }
}

struct ContentView: View {
    let model: BundlerModel
    @State private var selection: BundlerSection? = .modules

    var body: some View {
        SidebarNavigator(
            title: "Bundler",
            items: BundlerSection.allCases,
            selection: $selection
        ) { section in
            switch section {
            case .modules: ModulesView(model: model)
            case .bundles: BundlesView(model: model)
            case .tools:   ToolsView(model: model)
            }
        }
    }
}
