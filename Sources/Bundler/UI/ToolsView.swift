import SwiftUI

/// Standalone tools: wrap any binary into a .app, or package any .app into a .dmg.
struct ToolsView: View {
    let model: BundlerModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                WrapBinaryCard(model: model)
                MakeDMGCard(model: model)
            }
            .padding(24)
        }
        .navigationTitle("Tools")
    }
}

// MARK: - Wrap Binary

private struct WrapBinaryCard: View {
    let model: BundlerModel
    @State private var binaryURL:  URL?
    @State private var iconURL:    URL?
    @State private var name       = ""
    @State private var bundleID   = ""
    @State private var outputDir  = URL(fileURLWithPath: NSHomeDirectory() + "/Desktop")
    @State private var isWorking  = false
    @State private var resultMsg  = ""

    var body: some View {
        GroupBox("Wrap Binary → .app") {
            Form {
                LabeledContent("Binary") {
                    HStack {
                        Text(binaryURL?.lastPathComponent ?? "Not selected").foregroundStyle(.secondary)
                        Spacer()
                        Button("Browse…") { pickBinary() }
                    }
                }
                LabeledContent("App Name")  { TextField("MyApp", text: $name) }
                LabeledContent("Bundle ID") { TextField("com.example.myapp", text: $bundleID) }
                LabeledContent("Icon (.icns)") {
                    HStack {
                        Text(iconURL?.lastPathComponent ?? "None (optional)").foregroundStyle(.secondary)
                        Spacer()
                        Button("Browse…") { pickIcon() }
                        if iconURL != nil {
                            Button("Clear") { iconURL = nil }.foregroundStyle(.red)
                        }
                    }
                }
                LabeledContent("Output") {
                    HStack {
                        Text(outputDir.path).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        Button("…") { pickOutputDir() }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                if isWorking { ProgressView().controlSize(.small) }
                if !resultMsg.isEmpty { Text(resultMsg).foregroundStyle(.secondary).font(.callout) }
                Spacer()
                Button("Wrap") {
                    guard let binary = binaryURL else { return }
                    isWorking = true
                    resultMsg = ""
                    Task {
                        await model.wrapBinary(
                            binaryURL: binary,
                            name: name.isEmpty ? binary.lastPathComponent : name,
                            bundleID: bundleID.isEmpty ? "com.example.\(binary.lastPathComponent.lowercased())" : bundleID,
                            iconURL: iconURL,
                            outputDir: outputDir
                        )
                        isWorking = false
                        resultMsg = "Done → \(outputDir.path)/\(name).app"
                    }
                }
                .disabled(binaryURL == nil || isWorking)
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 4)
        }
    }

    private func pickBinary() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.prompt = "Select Binary"
        if panel.runModal() == .OK { binaryURL = panel.url }
    }
    private func pickIcon() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "icns")!]
        panel.prompt = "Select Icon"
        if panel.runModal() == .OK { iconURL = panel.url }
    }
    private func pickOutputDir() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.prompt = "Select Output Folder"
        if panel.runModal() == .OK, let url = panel.url { outputDir = url }
    }
}

// MARK: - Make DMG

private struct MakeDMGCard: View {
    let model: BundlerModel
    @State private var appURL:    URL?
    @State private var outputDir = URL(fileURLWithPath: NSHomeDirectory() + "/Desktop")
    @State private var isWorking = false
    @State private var resultMsg = ""

    var body: some View {
        GroupBox(".app → DMG") {
            Form {
                LabeledContent(".app") {
                    HStack {
                        Text(appURL?.lastPathComponent ?? "Not selected").foregroundStyle(.secondary)
                        Spacer()
                        Button("Browse…") { pickApp() }
                    }
                }
                LabeledContent("Output") {
                    HStack {
                        Text(outputDir.path).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        Button("…") { pickOutputDir() }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                if isWorking { ProgressView().controlSize(.small) }
                if !resultMsg.isEmpty { Text(resultMsg).foregroundStyle(.secondary).font(.callout) }
                Spacer()
                Button("Build DMG") {
                    guard let app = appURL else { return }
                    isWorking = true
                    resultMsg = ""
                    Task {
                        try? await DMGEngine.run(appURL: app, outputDir: outputDir)
                        isWorking = false
                        let name = app.deletingPathExtension().lastPathComponent
                        resultMsg = "Done → \(outputDir.path)/\(name).dmg"
                    }
                }
                .disabled(appURL == nil || isWorking)
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 4)
        }
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.prompt = "Select .app"
        if panel.runModal() == .OK { appURL = panel.url }
    }
    private func pickOutputDir() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        if panel.runModal() == .OK, let url = panel.url { outputDir = url }
    }
}
