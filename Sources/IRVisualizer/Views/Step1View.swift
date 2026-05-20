import SwiftUI

struct MoleculeInfo {
    let name: String
    let mass: Double
    let pfBundleName: String?
}

let moleculeOptions = [
    MoleculeInfo(name: "H2O", mass: 18, pfBundleName: "Partfun_H16OH"),
    MoleculeInfo(name: "N2O", mass: 44, pfBundleName: "Partfun_14N14N16O"),
    MoleculeInfo(name: "NO",  mass: 30, pfBundleName: "Partfun_14N16O"),
    MoleculeInfo(name: "NH3", mass: 17, pfBundleName: "Partfun_14NH3"),
    MoleculeInfo(name: "NO2", mass: 46, pfBundleName: "Partfun_16O14N16O"),
]

struct Step1View: View {
    @ObservedObject var engine: SimulationEngine
    @Binding var moleculeName: String
    @Binding var molarMass: Double
    @Binding var freqUnit: String
    @Binding var freq1: Double
    @Binding var freq2: Double
    @Binding var pfFileURL: URL?
    @Binding var hitranFileURL: URL?
    @Binding var hitranLabel: String
    @Binding var pfLabel: String
    @Binding var molarMassEnabled: Bool

    private let fieldWidth: CGFloat = 90

    private var currentMolecule: MoleculeInfo? {
        moleculeOptions.first { $0.name == moleculeName }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Group {
                    Text("DATA SOURCE").font(.caption).foregroundColor(.secondary)
                    Button("Import HITRAN data", action: importHitran)
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    Text(hitranLabel)
                        .font(.caption).foregroundColor(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                Divider()

                Group {
                    Text("MOLECULE").font(.caption).foregroundColor(.secondary)
                    HStack(spacing: 6) {
                        Picker("", selection: $moleculeName) {
                            ForEach(moleculeOptions, id: \.name) { info in
                                Text(info.name).tag(info.name)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 70)
                        .onChange(of: moleculeName) { _ in onMoleculeChanged() }

                        Button("My PartFun data", action: importPartFun)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    Text(pfLabel)
                        .font(.caption).foregroundColor(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .center)

                    HStack {
                        Text("Molar mass (g/mol)")
                        Spacer()
                        TextField("", value: $molarMass, format: .number)
                            .frame(width: fieldWidth)
                            .disabled(!molarMassEnabled)
                    }
                }

                Divider()

                Group {
                    Text("FREQUENCY RANGE").font(.caption).foregroundColor(.secondary)
                    HStack {
                        Text("Limit 1")
                        Spacer()
                        TextField("", value: $freq1, format: .number)
                            .frame(width: fieldWidth)
                    }
                    HStack {
                        Text("Limit 2")
                        Spacer()
                        TextField("", value: $freq2, format: .number)
                            .frame(width: fieldWidth)
                    }
                    HStack {
                        Text("Unit")
                        Spacer()
                        Picker("", selection: $freqUnit) {
                            Text("nm").tag("nm")
                            Text("cm⁻¹").tag("cm-1")
                            Text("µm").tag("µm")
                        }
                        .labelsHidden()
                        .frame(width: fieldWidth)
                    }
                    Text("(0,0) = full HITRAN range")
                        .font(.caption2).foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(10)
        }
        .onAppear { onMoleculeChanged() }
    }

    private func onMoleculeChanged() {
        guard let info = currentMolecule else { return }
        molarMass = info.mass
        pfFileURL = nil
        if let bundleName = info.pfBundleName,
           let url = Bundle.main.url(forResource: bundleName, withExtension: "txt") {
            if engine.loadPartitionFunction(from: url) {
                pfLabel = "Built-in: \(bundleName).txt"
                molarMassEnabled = false
                return
            }
        }
        pfLabel = "No built-in PF data"
        molarMassEnabled = false
    }

    private func importHitran() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select HITRAN data file"
        if panel.runModal() == .OK, let url = panel.url {
            if engine.loadHitran(from: url) {
                hitranFileURL = url
                hitranLabel = "Loaded: \(url.lastPathComponent)"
            } else {
                hitranLabel = "Failed to parse HITRAN file"
            }
        }
    }

    private func importPartFun() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select partition function file"
        if panel.runModal() == .OK, let url = panel.url {
            if engine.loadPartitionFunction(from: url) {
                pfFileURL = url
                pfLabel = "Loaded: \(url.lastPathComponent)"
                molarMassEnabled = true
            } else {
                pfLabel = "Failed to parse partition function"
            }
        }
    }
}
