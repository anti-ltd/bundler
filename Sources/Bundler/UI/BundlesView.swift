import SwiftUI

struct BundlesView: View {
    let model: BundlerModel
    @State private var selected: BundleDefinition?
    @State private var showAdd = false

    var body: some View {
        HSplitView {
            // List
            List(model.bundles, selection: $selected) { def in
                BundleRow(definition: def, log: model.buildLogs[def.id])
            }
            .listStyle(.sidebar)
            .frame(minWidth: 220)
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                    Button {
                        if let sel = selected { model.removeBundle(id: sel.id) }
                    } label: {
                        Image(systemName: "minus")
                    }
                    .disabled(selected == nil)
                    Spacer()
                }
                .buttonStyle(.plain)
                .padding(8)
            }

            // Detail
            if let definition = selected {
                BundleDetail(definition: definition, model: model)
            } else {
                ContentUnavailableView("No bundle selected", systemImage: "shippingbox")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showAdd) {
            AddBundleSheet { def in model.addBundle(def) }
        }
        .navigationTitle("Bundles")
    }
}

private struct BundleRow: View {
    let definition: BundleDefinition
    let log: BuildLog?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(definition.name).fontWeight(.medium)
                Text("\(definition.moduleIDs.count) module\(definition.moduleIDs.count == 1 ? "" : "s")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let log {
                stateIcon(log.state)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func stateIcon(_ state: BuildLog.State) -> some View {
        switch state {
        case .idle:      EmptyView()
        case .running:   ProgressView().controlSize(.small)
        case .succeeded: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }
}

private struct BundleDetail: View {
    @State var definition: BundleDefinition
    let model: BundlerModel
    @State private var isBuilding = false

    var body: some View {
        VSplitView {
            // Config
            Form {
                Section("Product") {
                    LabeledContent("Name") {
                        TextField("Mac Novelty Bundle", text: $definition.name)
                            .textFieldStyle(.plain).multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Bundle ID") {
                        TextField("ltd.anti.novelty", text: $definition.bundleID)
                            .textFieldStyle(.plain).multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Executable") {
                        TextField("NoveltyBundle", text: $definition.executableName)
                            .textFieldStyle(.plain).multilineTextAlignment(.trailing)
                    }
                }
                Section("Modules") {
                    ForEach(model.modules) { module in
                        Toggle(module.displayName, isOn: toggleBinding(for: module.id))
                    }
                    if model.modules.isEmpty {
                        Text("No modules registered — add them in the Modules tab.")
                            .foregroundStyle(.secondary).font(.callout)
                    }
                }
                Section("Output") {
                    LabeledContent("Signing Identity") {
                        TextField("-", text: $definition.signingIdentity)
                            .textFieldStyle(.plain).multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Output Directory") {
                        HStack {
                            Text(definition.outputDirectory)
                                .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                            Button("…") { pickOutput() }
                        }
                    }
                    Toggle("Build DMG", isOn: $definition.buildDMG)
                }
            }
            .formStyle(.grouped)
            .onChange(of: definition) { model.updateBundle(definition) }

            // Build log + action
            BuildLogPane(log: model.buildLogs[definition.id]) {
                isBuilding = true
                Task {
                    await model.build(definition)
                    isBuilding = false
                }
            }
            .frame(minHeight: 160)
        }
    }

    private func toggleBinding(for moduleID: UUID) -> Binding<Bool> {
        Binding(
            get: { definition.moduleIDs.contains(moduleID) },
            set: { on in
                if on { definition.moduleIDs.append(moduleID) }
                else  { definition.moduleIDs.removeAll { $0 == moduleID } }
            }
        )
    }

    private func pickOutput() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.prompt = "Select Output Folder"
        if panel.runModal() == .OK, let url = panel.url {
            definition.outputDirectory = url.path
        }
    }
}

private struct BuildLogPane: View {
    let log: BuildLog?
    let onBuild: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Build Log").font(.headline).padding()
                Spacer()
                Button("Build") { onBuild() }
                    .buttonStyle(.borderedProminent)
                    .disabled(log?.state == .running)
                    .padding()
            }
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(log?.entries ?? []) { entry in
                            BuildLogLine(entry: entry).id(entry.id)
                        }
                    }
                    .padding(8)
                }
                .onChange(of: log?.entries.count) {
                    if let last = log?.entries.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
    }
}

private struct BuildLogLine: View {
    let entry: BuildLog.Entry
    var body: some View {
        Text(entry.text)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(color)
            .textSelection(.enabled)
    }
    private var color: Color {
        switch entry.kind {
        case .info:    .primary
        case .command: .blue
        case .output:  .secondary
        case .success: .green
        case .error:   .red
        }
    }
}

private struct AddBundleSheet: View {
    var onAdd: (BundleDefinition) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name       = ""
    @State private var bundleID   = ""
    @State private var executable = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Bundle").font(.headline)
            Form {
                LabeledContent("Name")       { TextField("Mac Novelty Bundle", text: $name) }
                LabeledContent("Bundle ID")  { TextField("ltd.anti.novelty",   text: $bundleID) }
                LabeledContent("Executable") { TextField("NoveltyBundle",       text: $executable) }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Create") {
                    onAdd(BundleDefinition(name: name, bundleID: bundleID, executableName: executable))
                    dismiss()
                }
                .disabled(name.isEmpty || bundleID.isEmpty || executable.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}
