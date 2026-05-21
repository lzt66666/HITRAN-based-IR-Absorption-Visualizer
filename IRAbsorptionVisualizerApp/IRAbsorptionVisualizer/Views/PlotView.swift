import SwiftUI
import Charts

struct PlotView: View {
    let xValues: [Double]
    let yValues: [Double]
    let history: [(x: [Double], y: [Double], label: String)]
    let xUnit: String
    let yUnit: String
    let visibleMinX: Double?
    let visibleMaxX: Double?
    var onPanBy: (Double) -> Void = { _ in }
    var onZoomBy: (Double, Double?) -> Void = { _, _ in }

    @State private var dragStart: Double?
    @State private var lastMag: CGFloat = 1

    private let displayThreshold = 4000

    private struct PlotPoint: Identifiable {
        let id = UUID()
        let x: Double
        let y: Double
        let series: String
    }

    /// Visible range in cm⁻¹ (computation space).
    private var cmRange: (start: Double, end: Double)? {
        guard let mn = visibleMinX, let mx = visibleMaxX, mn < mx else { return nil }
        if xUnit == "nm" {
            return (1e7 / mx, 1e7 / mn)
        }
        return (mn, mx)
    }

    /// Extract slice of `x`/`y` that falls within `cmRange`, then downsample.
    private func visibleSlice(x: [Double], y: [Double]) -> (x: [Double], y: [Double]) {
        guard let (lo, hi) = cmRange, !x.isEmpty else { return downsample(x, y) }
        var low = 0, high = x.count
        while low < high { let m = (low+high)/2; if x[m] < lo { low = m+1 } else { high = m } }
        let start = low
        low = 0; high = x.count
        while low < high { let m = (low+high)/2; if x[m] <= hi { low = m+1 } else { high = m } }
        let end = low
        guard start < end else { return ([], []) }
        return downsample(Array(x[start..<end]), Array(y[start..<end]))
    }

    private func downsample(_ x: [Double], _ y: [Double]) -> (x: [Double], y: [Double]) {
        guard x.count > displayThreshold else { return (x, y) }
        return downsampleLTTB(x: x, y: y, threshold: displayThreshold)
    }

    private var points: [PlotPoint] {
        var r: [PlotPoint] = []
        for h in history {
            let (dx, dy) = visibleSlice(x: h.x, y: h.y)
            for i in 0..<min(dx.count, dy.count) {
                let (px, py) = transform(x: dx[i], y: dy[i])
                if px.isFinite, py.isFinite {
                    r.append(PlotPoint(x: px, y: py, series: h.label))
                }
            }
        }
        let (cx, cy) = visibleSlice(x: xValues, y: yValues)
        for i in 0..<min(cx.count, cy.count) {
            let (px, py) = transform(x: cx[i], y: cy[i])
            if px.isFinite, py.isFinite {
                r.append(PlotPoint(x: px, y: py, series: "Current"))
            }
        }
        return r
    }

    private func transform(x: Double, y: Double) -> (Double, Double) {
        let dx = xUnit == "nm" ? 1e7 / x : x
        let dy = yUnit == "Absorption" ? max(0, (1.0 - exp(-y)) * 100.0) : max(0, y)
        return (dx, dy)
    }

    private var xLabel: String { xUnit == "nm" ? "Wavelength /nm" : "Wavenumber /cm⁻¹" }
    private var yLabel: String { yUnit == "Absorption" ? "Absorption /%" : "alpha(ν)" }

    @ViewBuilder
    private var chart: some View {
        Chart(points) { pt in
            LineMark(x: .value(xLabel, pt.x), y: .value(yLabel, pt.y))
                .foregroundStyle(by: .value("Series", pt.series))
                .lineStyle(StrokeStyle(lineWidth: 2))
        }
        .chartXAxisLabel(xLabel)
        .chartYAxisLabel(yLabel)
        .chartLegend(position: .topTrailing)
    }

    var body: some View {
        VStack(spacing: 2) {
            if points.isEmpty {
                Text("No data. Load HITRAN file and press Generate.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Group {
                    if let a = visibleMinX, let b = visibleMaxX, a < b {
                        chart.chartXScale(domain: a...b)
                    } else {
                        chart
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { v in
                            if dragStart == nil { dragStart = 0 }
                            let f = -v.translation.width / 300
                            let d = f - (dragStart ?? 0)
                            dragStart = f
                            onPanBy(d)
                        }
                        .onEnded { _ in dragStart = nil }
                )
                .gesture(
                    MagnificationGesture()
                        .onChanged { s in
                            let f = s / lastMag
                            lastMag = s
                            onZoomBy(Double(f), nil)
                        }
                        .onEnded { _ in lastMag = 1 }
                )

                let allLabels = Set(history.map(\.label) + (xValues.isEmpty ? [] : ["Current"]))
                if allLabels.count > 1 {
                    Divider()
                    legendStrip(Array(allLabels))
                }
            }
        }
        .padding(6)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func legendStrip(_ labels: [String]) -> some View {
        let colors: [Color] = [.blue, .red, .green, .orange, .purple, .cyan, .mint, .pink]
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(labels.enumerated()), id: \.element) { i, label in
                    HStack(spacing: 4) {
                        Circle().fill(colors[i % colors.count]).frame(width: 8, height: 8)
                        Text(label).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 20)
    }
}
