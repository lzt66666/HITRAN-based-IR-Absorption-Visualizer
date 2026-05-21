import SwiftUI


struct Step2View: View {
    @ObservedObject var engine: SimulationEngine

    @Binding var opticalLength: Double
    @Binding var moleFraction: Double
    @Binding var temperature: Double
    @Binding var pressure: Double
    @Binding var xUnit: String
    @Binding var yUnit: String
    @Binding var resolution: Double
    @Binding var holdOn: Bool

    var onGenerate: () -> Void

    private let fieldWidth: CGFloat = 90

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Group {
                    Text("GAS CONDITIONS").font(.caption).foregroundColor(.secondary)
                    labeledField("Temperature /K", value: $temperature)
                    labeledField("Pressure /atm", value: $pressure)
                    labeledField("Gas mole fraction", value: $moleFraction)
                    labeledField("Optical length /cm", value: $opticalLength)
                }

                Divider()

                Group {
                    Text("PLOT AXES").font(.caption).foregroundColor(.secondary)
                    HStack {
                        Text("X axis")
                        Spacer()
                        Picker("", selection: $xUnit) {
                            Text("nm").tag("nm")
                            Text("cm⁻¹").tag("cm-1")
                        }
                        .labelsHidden()
                        .frame(width: fieldWidth)
                    }
                    HStack {
                        Text("Y axis")
                        Spacer()
                        Picker("", selection: $yUnit) {
                            Text("alpha(ν)").tag("alpha(nu)")
                            Text("Absorption %").tag("Absorption")
                        }
                        .labelsHidden()
                        .frame(width: fieldWidth)
                    }
                }

                Divider()

                Group {
                    Text("RESOLUTION").font(.caption).foregroundColor(.secondary)
                    VStack(spacing: 2) {
                        Slider(value: $resolution, in: 10...1000)
                        HStack {
                            Text("Rough").font(.caption2).foregroundColor(.secondary)
                            Spacer()
                            Text("Smooth").font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }

                Divider()

                VStack(spacing: 6) {
                    HStack(spacing: 16) {
                        Toggle(isOn: $holdOn) { Text("Hold on").font(.caption) }
                            .toggleStyle(.switch).controlSize(.small)
                        if engine.gpuAvailable {
                            Toggle(isOn: $engine.useGPU) { Text("GPU").font(.caption) }
                                .toggleStyle(.switch).controlSize(.small)
                        }
                        Spacer()
                    }
                    Button("Generate", action: onGenerate)
                        .disabled(engine.isRunning || !engine.hitranState)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(10)
        }
    }

    private func labeledField(_ label: String, value: Binding<Double>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("", value: value, format: .number)
                .frame(width: fieldWidth)
        }
    }
}
