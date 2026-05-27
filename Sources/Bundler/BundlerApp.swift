import SwiftUI
import iUX

struct BundlerApp: App {
    @State private var model = BundlerModel()

    var body: some Scene {
        Window("Bundler", id: "main") {
            ContentView(model: model)
        }
        .defaultSize(width: 900, height: 600)
        .windowResizability(.contentSize)
    }
}
