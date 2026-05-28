import SwiftUI

#Preview {
    ContentView()
}

struct ContentView: View {
    @StateObject private var engine = SimulationEngine()

    @State private var freqUnit = "nm"
    @State private var freq1: Double = 0
    @State private var freq2: Double = 0

    @State private var opticalLength: Double = 10
    @State private var moleFraction: Double = 0.1
    @State private var temperature: Double = 298
    @State private var pressure: Double = 1
    @State private var xUnit = "nm"
    @State private var yUnit = "Absorption"
    @State private var resolution: Double = 100
    @State private var holdOn = false

    @State private var hitranLabel = "No data loaded"
    @State private var pfLabel = ""

    @State private var conditions = ""
    @State private var history: [(x: [Double], y: [Double], label: String)] = []

    @State private var fullMinX: Double?
    @State private var fullMaxX: Double?
    @State private var zoomCenter: Double?
    @State private var zoomFactor: Double = 1

    private let fieldWidth: CGFloat = 90

    private var visibleMinX: Double? {
        guard let c = zoomCenter, let mn = fullMinX, let mx = fullMaxX else { return fullMinX }
        let halfRange = (mx - mn) / (2 * zoomFactor)
        return c - halfRange
    }
    private var visibleMaxX: Double? {
        guard let c = zoomCenter, let mn = fullMinX, let mx = fullMaxX else { return fullMaxX }
        let halfRange = (mx - mn) / (2 * zoomFactor)
        return c + halfRange
    }

    private var componentSeries: [(x: [Double], y: [Double], label: String)] {
        engine.moleculeIds.compactMap { mid -> (x: [Double], y: [Double], label: String)? in
            guard let ys = engine.componentYValues[mid], !ys.isEmpty else { return nil }
            let xs = engine.xValues
            guard xs.count == ys.count else { return nil }
            let formula = moleculeDatabase[mid]?.formula ?? "Mol\(mid)"
            return (x: xs, y: ys, label: formula)
        }
    }

    var body: some View {
        HSplitView {
            leftPanel
                .frame(minWidth: 280, idealWidth: 280, maxWidth: 280)

            VStack(spacing: 0) {
                zoomToolbar
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)

                PlotView(
                    xValues: engine.xValues,
                    yValues: engine.yValues,
                    history: history,
                    componentSeries: componentSeries,
                    xUnit: xUnit,
                    yUnit: yUnit,
                    visibleMinX: visibleMinX,
                    visibleMaxX: visibleMaxX,
                    onPanBy: { delta in panBy(delta) },
                    onZoomBy: { factor, center in zoomBy(factor, around: center) }
                )
            }
            .frame(minWidth: 350)
        }
        .frame(minWidth: 750, minHeight: 470)
        .focusedSceneValue(\.saveAction, saveFigureData)
        .focusedSceneValue(\.helpAction, showHelp)
        .onReceive(engine.$xValues) { _ in resetZoom() }
    }

    // MARK: - Left Panel (merged Settings)

    private var leftPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                dataSourceSection
                Divider()
                if !engine.detectedMolecules.isEmpty { componentsSection; Divider() }
                frequencySection
                Divider()
                gasConditionsSection
                Divider()
                plotAxesSection
                Divider()
                resolutionSection
                Divider()
                generateSection
            }
            .padding(10)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Sections

    private var dataSourceSection: some View {
        Group {
            Text("DATA SOURCE").font(.caption).foregroundColor(.secondary)

            HStack(spacing: 4) {
                Button("Add HITRAN", action: importHitran)
                    .buttonStyle(.bordered)
                Button("Clear All", action: clearAll)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!engine.hitranState)
            }
            .frame(maxWidth: .infinity)

            if !engine.loadedFileNames.isEmpty {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(engine.loadedFileNames, id: \.self) { name in
                        Text(name)
                            .font(.caption2).foregroundColor(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button("Import PartFun data (optional)", action: importPartFun)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(maxWidth: .infinity)
            if !engine.userPFLabel.isEmpty {
                Text("PF: \(engine.userPFLabel)")
                    .font(.caption2).foregroundColor(.green)
                    .lineLimit(1).truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var componentsSection: some View {
        Group {
            Text("DETECTED COMPONENTS").font(.caption).foregroundColor(.secondary)
            ForEach(engine.detectedMolecules, id: \.molecId) { dm in
                HStack {
                    Text(dm.formula)
                        .font(.caption2).bold()
                        .frame(width: 50, alignment: .leading)
                    Text("\(dm.lineCount) lines")
                        .font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    Text(dm.pfStatus)
                        .font(.caption2)
                        .foregroundColor(dm.pfStatus == "built-in" || dm.pfStatus == "user PF" ? .green : .orange)
                }
                .padding(.vertical, 1)
            }
        }
    }

    private var frequencySection: some View {
        Group {
            Text("FREQUENCY RANGE").font(.caption).foregroundColor(.secondary)
            labeledField("Limit 1", $freq1)
            labeledField("Limit 2", $freq2)
            HStack {
                Text("Unit")
                Spacer()
                Picker("", selection: $freqUnit) {
                    Text("nm").tag("nm"); Text("cm⁻¹").tag("cm-1"); Text("µm").tag("µm")
                }
                .labelsHidden().frame(width: fieldWidth)
            }
            Text("(0,0) = full HITRAN range")
                .font(.caption2).foregroundColor(.red).frame(maxWidth: .infinity)
        }
    }

    private var gasConditionsSection: some View {
        Group {
            Text("GAS CONDITIONS").font(.caption).foregroundColor(.secondary)
            labeledField("Temperature /K", $temperature)
            labeledField("Pressure /atm", $pressure)
            labeledField("Gas mole fraction", $moleFraction)
            labeledField("Optical length /cm", $opticalLength)
        }
    }

    private var plotAxesSection: some View {
        Group {
            Text("PLOT AXES").font(.caption).foregroundColor(.secondary)
            HStack {
                Text("X axis"); Spacer()
                Picker("", selection: $xUnit) {
                    Text("nm").tag("nm"); Text("cm⁻¹").tag("cm-1")
                }
                .labelsHidden().frame(width: fieldWidth)
            }
            HStack {
                Text("Y axis"); Spacer()
                Picker("", selection: $yUnit) {
                    Text("alpha(ν)").tag("alpha(nu)"); Text("Absorption %").tag("Absorption")
                }
                .labelsHidden().frame(width: fieldWidth)
            }
        }
    }

    private var resolutionSection: some View {
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
    }

    private var generateSection: some View {
        VStack(spacing: 6) {
            HStack(spacing: 16) {
                Toggle(isOn: $holdOn) { Text("Hold on").font(.caption) }
                    .toggleStyle(.switch).controlSize(.small)
                Spacer()
            }
            Button("Generate", action: generate)
                .disabled(engine.isRunning || !engine.hitranState)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .keyboardShortcut(.defaultAction)
        }
    }

    private func labeledField(_ label: String, _ value: Binding<Double>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("", value: value, format: .number)
                .frame(width: fieldWidth)
        }
    }

    // MARK: - Actions

    private func importHitran() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Select HITRAN data file(s)"
        guard panel.runModal() == .OK else { return }
        var loaded = 0
        for url in panel.urls {
            if engine.appendHitran(from: url) { loaded += 1 }
        }
        if loaded > 0 {
            hitranLabel = "\(engine.loadedFileNames.count) file(s) loaded"
        }
    }

    private func clearAll() {
        engine.clearAllData()
        hitranLabel = "No data loaded"
    }

    private func importPartFun() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select partition function file"
        if panel.runModal() == .OK, let url = panel.url {
            if engine.loadUserPartitionFunction(from: url) {
                pfLabel = url.lastPathComponent
            } else {
                pfLabel = "Failed to parse"
            }
        }
    }

    // MARK: - Zoom Toolbar

    private var zoomToolbar: some View {
        HStack(spacing: 4) {
            Text("X:").font(.caption).foregroundColor(.secondary)

            Button { panBy(-0.1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.borderless).disabled(zoomFactor == 1)

            Button { panBy(0.1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.borderless).disabled(zoomFactor == 1)

            Divider().frame(height: 16)

            Button { zoomBy(1 / 1.5, around: nil) } label: { Image(systemName: "minus.magnifyingglass") }
                .buttonStyle(.borderless)

            Button { zoomBy(1.5, around: nil) } label: { Image(systemName: "plus.magnifyingglass") }
                .buttonStyle(.borderless)

            Button { resetZoom() } label: { Image(systemName: "arrow.counterclockwise") }
                .buttonStyle(.borderless).disabled(zoomFactor == 1)

            Spacer()

            Text(zoomLabel).font(.caption).monospacedDigit().foregroundColor(.secondary)
        }
    }

    private var zoomLabel: String {
        guard let mn = visibleMinX, let mx = visibleMaxX, mn.isFinite, mx.isFinite else { return "" }
        if xUnit == "nm" {
            return String(format: "%.1f – %.1f nm", mn, mx)
        } else {
            if mx - mn > 10 {
                return String(format: "%.2f – %.2f cm⁻¹", mn, mx)
            } else {
                return String(format: "%.4f – %.4f cm⁻¹", mn, mx)
            }
        }
    }

    // MARK: - Zoom / Pan

    private func resetZoom() {
        zoomCenter = nil
        zoomFactor = 1
    }

    private func zoomBy(_ factor: Double, around center: Double?) {
        guard let mn = fullMinX, let mx = fullMaxX, mn < mx else { return }
        let _center = center ?? zoomCenter ?? (mn + mx) / 2
        zoomFactor = max(1, min(zoomFactor * factor, 100))
        zoomCenter = _center
        clampVisible()
    }

    private func panBy(_ fraction: Double) {
        guard let mn = fullMinX, let mx = fullMaxX, let c = zoomCenter else { return }
        let range = (mx - mn) / zoomFactor
        zoomCenter = c + range * fraction
        clampVisible()
    }

    private func clampVisible() {
        guard let mn = fullMinX, let mx = fullMaxX, let c = zoomCenter else { return }
        let halfRange = (mx - mn) / (2 * zoomFactor)
        if c - halfRange < mn { zoomCenter = mn + halfRange }
        if c + halfRange > mx { zoomCenter = mx - halfRange }
    }

    // MARK: - Generate

    private func generate() {
        NSApp.keyWindow?.makeFirstResponder(nil)
        guard engine.hitranState else { return }

        let T = temperature, X = moleFraction, P = pressure, L = opticalLength
        conditions = "\(String(format: "%.0f", T))K_\(String(format: "%.3f", X))c_\(String(format: "%.2f", P))atm_\(String(format: "%.0f", L))cm"

        let (nuStart, nuEnd) = resolveFrequencyRange()
        guard nuStart.isFinite, nuEnd.isFinite else { return }

        let mn: Double, mx: Double
        if xUnit == "nm" { mn = 1e7 / nuEnd; mx = 1e7 / nuStart }
        else { mn = nuStart; mx = nuEnd }
        guard mn.isFinite, mx.isFinite, mn < mx else { return }
        fullMinX = mn; fullMaxX = mx
        resetZoom()

        let label = "\(String(format: "%.0f", T))K \(String(format: "%.4g", X))mol \(String(format: "%.2g", P))atm \(String(format: "%.0f", L))cm"
        if holdOn {
            if !engine.xValues.isEmpty { history.append((engine.xValues, engine.yValues, label)) }
        } else {
            history = []
        }

        engine.runSimulation(freqRange: (nuStart, nuEnd), resolution: resolution,
                             temperature: T, pressure: P, moleFraction: X, length: L)
    }

    private func resolveFrequencyRange() -> (start: Double, end: Double) {
        var firstNu = Double.infinity, lastNu = -Double.infinity
        for (_, lines) in engine.componentLines {
            if let f = lines.first?.nu { firstNu = min(firstNu, f) }
            if let l = lines.last?.nu { lastNu = max(lastNu, l) }
        }
        if firstNu.isInfinite || lastNu.isInfinite { return (0, 0) }
        if freq1 == 0 || freq2 == 0 { return (firstNu, lastNu) }
        let v1: Double, v2: Double
        switch freqUnit {
        case "nm": v1 = 1e7 / freq1; v2 = 1e7 / freq2
        case "µm": v1 = 1e7 / (freq1 * 1e3); v2 = 1e7 / (freq2 * 1e3)
        default: v1 = freq1; v2 = freq2
        }
        guard v1.isFinite, v2.isFinite else { return (firstNu, lastNu) }
        return v1 > v2 ? (v2, v1) : (v1, v2)
    }

    // MARK: - Menu Actions

    private func saveFigureData() {
        NSApp.activate(ignoringOtherApps: true)
        guard !engine.xValues.isEmpty else {
            let alert = NSAlert(); alert.messageText = "Info"
            alert.informativeText = "No figure exist"; alert.alertStyle = .warning
            alert.runModal(); return
        }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.message = "Choose the Destination"
        guard panel.runModal() == .OK, let url = panel.url else {
            let alert = NSAlert(); alert.messageText = "Info"
            alert.informativeText = "Please select the output folder."; alert.alertStyle = .warning
            alert.runModal(); return
        }
        var csv = "nu"
        for mid in engine.moleculeIds {
            let formula = moleculeDatabase[mid]?.formula ?? "Mol\(mid)"
            csv += ",alpha_nu_\(formula)"
        }
        csv += ",alpha_nu_total\n"
        for i in 0..<min(engine.xValues.count, engine.yValues.count) {
            csv += "\(engine.xValues[i])"
            for mid in engine.moleculeIds {
                let val = engine.componentYValues[mid]?[safe: i] ?? 0
                csv += ",\(val)"
            }
            csv += ",\(engine.yValues[i])\n"
        }
        let fileURL = url.appendingPathComponent("nv_alpha_nv_at_\(conditions).csv")
        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            let alert = NSAlert(); alert.messageText = "Info"
            alert.informativeText = "File saved as nv_alpha_nv_at_\(conditions).csv.\nLocated at: \(url.path)"
            alert.alertStyle = .informational; alert.runModal()
        } catch {
            let alert = NSAlert(); alert.messageText = "Error"
            alert.informativeText = error.localizedDescription; alert.alertStyle = .critical
            alert.runModal()
        }
    }

    private func showHelp() {
        let alert = NSAlert(); alert.messageText = "Info"
        alert.informativeText = "Check README.pdf distributed with this APP"
        alert.alertStyle = .warning; alert.runModal()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
