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

enum FilePickerTarget {
    case hitran, partfun
}

struct SettingsView: View {
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

    @Binding var opticalLength: Double
    @Binding var moleFraction: Double
    @Binding var temperature: Double
    @Binding var pressure: Double
    @Binding var xUnit: String
    @Binding var yUnit: String
    @Binding var resolution: Double
    @Binding var holdOn: Bool

    var onGenerate: () -> Void

    @State private var showFilePicker = false
    @State private var filePickerTarget: FilePickerTarget = .hitran

    private var currentMolecule: MoleculeInfo? {
        moleculeOptions.first { $0.name == moleculeName }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // MARK: DATA SOURCE
                sectionHeader("DATA SOURCE")
                Button("Import HITRAN data") { filePickerTarget = .hitran; showFilePicker = true }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                Text(hitranLabel)
                    .font(.caption).foregroundColor(.secondary)
                    .lineLimit(1).truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .center)

                Divider()

                // MARK: MOLECULE
                sectionHeader("MOLECULE")
                HStack(spacing: 6) {
                    Picker("Molecule", selection: $moleculeName) {
                        ForEach(moleculeOptions, id: \.name) { info in
                            Text(info.name).tag(info.name)
                        }
                    }
                    .onChange(of: moleculeName) { _, _ in onMoleculeChanged() }

                    Button("My PartFun data") { filePickerTarget = .partfun; showFilePicker = true }
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
                        .keyboardType(.decimalPad)
                        .frame(width: 100).multilineTextAlignment(.trailing)
                        .disabled(!molarMassEnabled)
                }

                Divider()

                // MARK: FREQUENCY RANGE
                sectionHeader("FREQUENCY RANGE")
                labeledField("Limit 1", value: $freq1)
                labeledField("Limit 2", value: $freq2)
                HStack {
                    Text("Unit")
                    Spacer()
                    Picker("", selection: $freqUnit) {
                        Text("nm").tag("nm")
                        Text("cm⁻¹").tag("cm-1")
                        Text("µm").tag("µm")
                    }
                    .labelsHidden()
                    .frame(width: 100)
                }
                Text("(0,0) = full HITRAN range")
                    .font(.caption2).foregroundColor(.red)

                Divider()

                // MARK: GAS CONDITIONS
                sectionHeader("GAS CONDITIONS")
                labeledField("Temperature /K", value: $temperature)
                labeledField("Pressure /atm", value: $pressure)
                labeledField("Gas mole fraction", value: $moleFraction)
                labeledField("Optical length /cm", value: $opticalLength)

                Divider()

                // MARK: PLOT AXES
                sectionHeader("PLOT AXES")
                HStack {
                    Text("X axis")
                    Spacer()
                    Picker("", selection: $xUnit) {
                        Text("nm").tag("nm")
                        Text("cm⁻¹").tag("cm-1")
                    }
                    .labelsHidden()
                    .frame(width: 100)
                }
                HStack {
                    Text("Y axis")
                    Spacer()
                    Picker("", selection: $yUnit) {
                        Text("alpha(ν)").tag("alpha(nu)")
                        Text("Absorption %").tag("Absorption")
                    }
                    .labelsHidden()
                    .frame(width: 190)
                }

                Divider()

                // MARK: RESOLUTION
                sectionHeader("SMOOTHNESS")
                VStack(spacing: 2) {
                    Slider(value: $resolution, in: 10...1000)
                    HStack {
                        Text("Rough").font(.caption2).foregroundColor(.secondary)
                        Spacer()
                        Text("Smooth").font(.caption2).foregroundColor(.secondary)
                    }
                }

                Divider()

                // MARK: GENERATE
                HStack(spacing: 16) {
                    Toggle(isOn: $holdOn) { Text("Multiple drawings").font(.caption) }
                        .toggleStyle(.switch).controlSize(.small)
                    if engine.gpuAvailable {
                        Toggle(isOn: $engine.useGPU) { Text("GPU (recommend)").font(.caption) }
                            .toggleStyle(.switch).controlSize(.small)
                    }
                    Spacer()
                }

                Button("Generate", action: onGenerate)
                    .disabled(engine.isRunning || !engine.hitranState)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.plainText, .commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                if filePickerTarget == .hitran { hitranLabel = "Cannot access file" }
                else { pfLabel = "Cannot access file" }
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            switch filePickerTarget {
            case .hitran:
                if engine.loadHitran(from: url) {
                    hitranFileURL = url
                    hitranLabel = "Loaded: \(url.lastPathComponent)"
                } else {
                    hitranLabel = "Failed to parse HITRAN file"
                }
            case .partfun:
                if engine.loadPartitionFunction(from: url) {
                    pfFileURL = url
                    pfLabel = "Loaded: \(url.lastPathComponent)"
                    molarMassEnabled = true
                } else {
                    pfLabel = "Failed to parse partition function"
                }
            }
        }
        .onAppear { onMoleculeChanged() }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text).font(.caption).foregroundColor(.secondary)
    }

    private func labeledField(_ label: String, value: Binding<Double>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("", value: value, format: .number)
                .keyboardType(.decimalPad)
                .frame(width: 100).multilineTextAlignment(.trailing)
        }
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
}
