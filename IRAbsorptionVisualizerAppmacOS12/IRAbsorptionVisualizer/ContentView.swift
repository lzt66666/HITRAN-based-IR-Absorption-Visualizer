import SwiftUI

struct ContentView: View {
    @StateObject private var engine = SimulationEngine()

    @State private var moleculeName = "H2O"
    @State private var molarMass: Double = 44
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

    @State private var pfFileURL: URL?
    @State private var hitranFileURL: URL?
    @State private var hitranLabel = "No data loaded"
    @State private var pfLabel = "No data loaded, use in built data"
    @State private var molarMassEnabled = false

    @State private var selectedTab = "Step 1"
    @State private var conditions = ""
    @State private var history: [(x: [Double], y: [Double], label: String)] = []

    @State private var fullMinX: Double?
    @State private var fullMaxX: Double?
    @State private var zoomCenter: Double?
    @State private var zoomFactor: Double = 1

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
        let fmt: String
        if xUnit == "nm" {
            fmt = String(format: "%.1f – %.1f nm", mn, mx)
        } else {
            if mx - mn > 10 {
                fmt = String(format: "%.2f – %.2f cm⁻¹", mn, mx)
            } else {
                fmt = String(format: "%.4f – %.4f cm⁻¹", mn, mx)
            }
        }
        return fmt
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

        let T = temperature
        let H2Oc = moleFraction
        let P = pressure
        let L = opticalLength
        conditions = "\(String(format: "%.0f", T))K_\(String(format: "%.3f", H2Oc))c_\(String(format: "%.2f", P))atm_\(String(format: "%.0f", L))cm"

        guard let pf = engine.pf else {
            engine.qt0 = 1
            engine.qt = 1
            return
        }
        engine.qt0 = pf.value(at: 296)
        engine.qt = pf.value(at: round(T))

        let (nuStart, nuEnd) = resolveFrequencyRange()
        guard nuStart.isFinite, nuEnd.isFinite else { return }

        let mn: Double, mx: Double
        if xUnit == "nm" {
            mn = 1e7 / nuEnd
            mx = 1e7 / nuStart
        } else {
            mn = nuStart
            mx = nuEnd
        }
        guard mn.isFinite, mx.isFinite, mn < mx else { return }
        fullMinX = mn
        fullMaxX = mx
        resetZoom()

        let label = "\(String(format: "%.0f", T))K \(String(format: "%.4g", H2Oc))mol \(String(format: "%.2g", P))atm \(String(format: "%.0f", L))cm"
        if holdOn {
            if !engine.xValues.isEmpty {
                history.append((engine.xValues, engine.yValues, label))
            }
        } else {
            history = []
        }

        engine.runSimulation(
            freqRange: (nuStart, nuEnd),
            resolution: resolution,
            temperature: T,
            pressure: P,
            moleFraction: H2Oc,
            length: L,
            molarMass: molarMass,
            moleculeName: moleculeName
        )
    }

    private func resolveFrequencyRange() -> (start: Double, end: Double) {
        guard let firstNu = engine.lines.first?.nu,
              let lastNu = engine.lines.last?.nu else { return (0, 0) }
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
            let alert = NSAlert()
            alert.messageText = "Info"
            alert.informativeText = "No figure exist"
            alert.alertStyle = .warning
            alert.runModal()
            return
        }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.message = "Choose the Destination"
        guard panel.runModal() == .OK, let url = panel.url else {
            let alert = NSAlert()
            alert.messageText = "Info"
            alert.informativeText = "Please select the output folder."
            alert.alertStyle = .warning
            alert.runModal()
            return
        }
        var csv = "nu,alpha_nu\n"
        for i in 0..<min(engine.xValues.count, engine.yValues.count) {
            csv += "\(engine.xValues[i]),\(engine.yValues[i])\n"
        }
        let fileURL = url.appendingPathComponent("nv_alpha_nv_at_\(conditions).csv")
        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            let alert = NSAlert()
            alert.messageText = "Info"
            alert.informativeText = "File saved as nv_alpha_nv_at_\(conditions).csv.\nLocated at: \(url.path)"
            alert.alertStyle = .informational
            alert.runModal()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.runModal()
        }
    }

    private func showHelp() {
        let alert = NSAlert()
        alert.messageText = "Info"
        alert.informativeText = "Check README.pdf distributed with this APP"
        alert.alertStyle = .warning
        alert.runModal()
    }

    private var leftPanel: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Step 1").tag("Step 1")
                Text("Step 2").tag("Step 2")
            }
            .pickerStyle(.segmented)
            .padding(EdgeInsets(top: 8, leading: 8, bottom: 4, trailing: 8))

            if selectedTab == "Step 1" {
                Step1View(
                    engine: engine,
                    moleculeName: $moleculeName,
                    molarMass: $molarMass,
                    freqUnit: $freqUnit,
                    freq1: $freq1,
                    freq2: $freq2,
                    pfFileURL: $pfFileURL,
                    hitranFileURL: $hitranFileURL,
                    hitranLabel: $hitranLabel,
                    pfLabel: $pfLabel,
                    molarMassEnabled: $molarMassEnabled
                )
                .frame(maxHeight: .infinity, alignment: .top)
            } else {
                Step2View(
                    engine: engine,
                    opticalLength: $opticalLength,
                    moleFraction: $moleFraction,
                    temperature: $temperature,
                    pressure: $pressure,
                    xUnit: $xUnit,
                    yUnit: $yUnit,
                    resolution: $resolution,
                    holdOn: $holdOn,
                    onGenerate: generate
                )
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}

