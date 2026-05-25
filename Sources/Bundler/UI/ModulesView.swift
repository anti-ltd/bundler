import SwiftUI

struct ModulesView: View {
    let model: BundlerModel
    @State private var selected: ModuleEntry?
    @State private var showAdd = false

    var body: some View {
        HSplitView {
            // List
            List(model.modules, selection: $selected) { entry in
                ModuleRow(entry: entry)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 220)
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                    Button {
                        if let sel = selected { model.removeModule(id: sel.id) }
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
            if let entry = selected {
                ModuleDetail(entry: entry, model: model)
            } else {
                ContentUnavailableView("No module selected", systemImage: "puzzlepiece.extension")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showAdd) {
            AddModuleSheet { entry in model.addModule(entry) }
        }
        .navigationTitle("Modules")
    }
}

private struct ModuleRow: View {
    let entry: ModuleEntry
    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName).fontWeight(.medium)
                Text(entry.targetName).font(.caption).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: entry.symbolName)
        }
        .padding(.vertical, 2)
    }
}

private struct ModuleDetail: View {
    @State var entry: ModuleEntry
    let model: BundlerModel

    var body: some View {
        Form {
            Section("Identity") {
                LabeledContent("Display Name") {
                    TextField("Display Name", text: $entry.displayName)
                        .textFieldStyle(.plain).multilineTextAlignment(.trailing)
                }
                LabeledContent("Module ID") {
                    TextField("ltd.example.app", text: $entry.moduleID)
                        .textFieldStyle(.plain).multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("SF Symbol") {
                    TextField("symbolname", text: $entry.symbolName)
                        .textFieldStyle(.plain).multilineTextAlignment(.trailing)
                }
                LabeledContent("SPM Target") {
                    TextField("CoreTarget", text: $entry.targetName)
                        .textFieldStyle(.plain).multilineTextAlignment(.trailing)
                }
            }
            Section("Location") {
                LabeledContent("Package Path") {
                    Text(entry.path).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
                Button("Change Path…") { pickPath() }
            }
        }
        .formStyle(.grouped)
        .onChange(of: entry) { model.updateModule(entry) }
    }

    private func pickPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.prompt = "Select Package"
        if panel.runModal() == .OK, let url = panel.url {
            entry.path = url.path
        }
    }
}

private struct AddModuleSheet: View {
    var onAdd: (ModuleEntry) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var path        = ""
    @State private var displayName = ""
    @State private var moduleID    = ""
    @State private var symbolName  = "puzzlepiece"
    @State private var targetName  = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Module").font(.headline)

            Form {
                LabeledContent("Package Path") {
                    HStack {
                        Text(path.isEmpty ? "Not set" : path)
                            .foregroundStyle(path.isEmpty ? .tertiary : .secondary)
                            .lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button("Browse…") { pickPath() }
                    }
                }
                LabeledContent("Display Name")  { TextField("Clonk", text: $displayName) }
                LabeledContent("Module ID")     { TextField("ltd.anti.clonk", text: $moduleID) }
                LabeledContent("SF Symbol")     { TextField("keyboard", text: $symbolName) }
                LabeledContent("SPM Target")    { TextField("ClonkCore", text: $targetName) }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add") {
                    let entry = ModuleEntry(
                        path: path,
                        moduleID: moduleID,
                        displayName: displayName,
                        symbolName: symbolName,
                        targetName: targetName
                    )
                    onAdd(entry)
                    dismiss()
                }
                .disabled(path.isEmpty || displayName.isEmpty || targetName.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 480)
    }

    private func pickPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.prompt = "Select Package"
        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
        }
    }
}
