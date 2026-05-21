import SwiftUI

// MARK: - CoreGraphics Chart View (macOS 12 compatible)

struct CoreGraphicsChartView: NSViewRepresentable {
    let series: [(points: [(x: Double, y: Double)], label: String)]
    let xLabel: String
    let yLabel: String
    let xDomain: ClosedRange<Double>?

    func makeNSView(context: Context) -> ChartNSView {
        ChartNSView()
    }

    func updateNSView(_ nsView: ChartNSView, context: Context) {
        nsView.series = series
        nsView.xLabel = xLabel
        nsView.yLabel = yLabel
        nsView.xDomain = xDomain
        nsView.scheduleRedraw()
    }
}

class ChartNSView: NSView {
    var series: [(points: [(x: Double, y: Double)], label: String)] = []
    var xLabel: String = ""
    var yLabel: String = ""
    var xDomain: ClosedRange<Double>?

    private var pendingRedraw = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    func scheduleRedraw() {
        guard !pendingRedraw else { return }
        pendingRedraw = true
        DispatchQueue.main.async { [weak self] in
            self?.pendingRedraw = false
            self?.needsDisplay = true
        }
    }

    private let colors: [NSColor] = [
        .systemBlue, .systemRed, .systemGreen, .systemOrange,
        .systemPurple, .cyan, .systemMint, .systemPink
    ]

    private let margin = NSEdgeInsets(top: 5, left: 28, bottom: 16, right: 4)
    private let legendHeight: CGFloat = 10

    override var isFlipped: Bool { true }

    private var plotRect: CGRect {
        let r = bounds.insetBy(dx: margin.left, dy: margin.top)
        return CGRect(x: margin.left, y: margin.top,
                      width: max(1, r.width - margin.right),
                      height: max(1, r.height - margin.bottom - legendHeight))
    }

    private var dataXRange: ClosedRange<Double> {
        if let d = xDomain { return d }
        var lo = Double.infinity, hi = -Double.infinity
        for s in series { for p in s.points { lo = min(lo, p.x); hi = max(hi, p.x) } }
        if lo.isInfinite { return 0...1 }
        let pad = max((hi - lo) * 0.02, 1e-10)
        return (lo - pad)...(hi + pad)
    }

    private var dataYRange: ClosedRange<Double> {
        var lo = Double.infinity, hi = -Double.infinity
        for s in series { for p in s.points { lo = min(lo, p.y); hi = max(hi, p.y) } }
        if lo.isInfinite { return 0...1 }
        let pad = max((hi - lo) * 0.05, 1e-10)
        if hi - lo < 1e-10 { return (lo - 0.5)...(hi + 0.5) }
        return (lo - pad)...(hi + pad)
    }

    private func toView(_ x: Double, _ y: Double) -> CGPoint {
        let rx = dataXRange, ry = dataYRange
        let px = plotRect.minX + (x - rx.lowerBound) / (rx.upperBound - rx.lowerBound) * plotRect.width
        let py = plotRect.minY + (1.0 - (y - ry.lowerBound) / (ry.upperBound - ry.lowerBound)) * plotRect.height
        return CGPoint(x: px, y: py)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlBackgroundColor.setFill()
        dirtyRect.fill()

        let pr = plotRect
        guard !series.isEmpty, !pr.isEmpty else { return }

        // --- plot background ---
        NSColor.white.setFill()
        NSBezierPath(rect: pr).fill()

        // --- axes (x at bottom, y on left) ---
        let xr = dataXRange, yr = dataYRange
        NSColor.lightGray.setStroke()
        let axisPath = NSBezierPath()
        axisPath.move(to: CGPoint(x: pr.minX, y: pr.maxY))  // bottom-left
        axisPath.line(to: CGPoint(x: pr.maxX, y: pr.maxY))  // bottom-right (x-axis)
        axisPath.move(to: CGPoint(x: pr.minX, y: pr.maxY))  // bottom-left
        axisPath.line(to: CGPoint(x: pr.minX, y: pr.minY))  // top-left (y-axis)
        axisPath.stroke()

        // --- tick marks & labels ---
        let tickAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        func formatTick(_ v: Double) -> String {
            if abs(v) >= 1000 { return String(format: "%.0f", v) }
            if abs(v) >= 10 { return String(format: "%.1f", v) }
            if abs(v) >= 1 { return String(format: "%.2f", v) }
            return String(format: "%.3f", v)
        }

        // x ticks (at bottom = pr.maxY)
        let nXTicks = 5
        for i in 0..<nXTicks {
            let t = xr.lowerBound + Double(i) / Double(nXTicks - 1) * (xr.upperBound - xr.lowerBound)
            let pt = toView(t, yr.lowerBound)
            let tick = NSBezierPath()
            tick.move(to: CGPoint(x: pt.x, y: pr.maxY))
            tick.line(to: CGPoint(x: pt.x, y: pr.maxY + 3))
            tick.stroke()
            let s = formatTick(t)
            (s as NSString).draw(at: CGPoint(x: pt.x - CGFloat(s.count) * 3, y: pr.maxY + 4),
                                withAttributes: tickAttrs)
        }

        // y ticks (on left = pr.minX)
        let nYTicks = 5
        for i in 0..<nYTicks {
            let t = yr.lowerBound + Double(i) / Double(nYTicks - 1) * (yr.upperBound - yr.lowerBound)
            let pt = toView(xr.lowerBound, t)
            let tick = NSBezierPath()
            tick.move(to: CGPoint(x: pr.minX, y: pt.y))
            tick.line(to: CGPoint(x: pr.minX - 3, y: pt.y))
            tick.stroke()
            let s = formatTick(t)
            (s as NSString).draw(at: CGPoint(x: pr.minX - CGFloat(s.count) * 5 - 4, y: pt.y - 4),
                                withAttributes: tickAttrs)
        }

        // --- axis labels ---
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: NSColor.labelColor
        ]
        // x label (below x-axis)
        (xLabel as NSString).draw(at: CGPoint(x: pr.midX - CGFloat(xLabel.count) * 3, y: pr.maxY + 13),
                                 withAttributes: labelAttrs)
        // y label (rotated, left of y-axis)
        if !yLabel.isEmpty {
            NSGraphicsContext.saveGraphicsState()
            let tf = NSAffineTransform()
            tf.translateX(by: pr.minX - 14, yBy: pr.midY + CGFloat(yLabel.count) * 2.5)
            tf.rotate(byRadians: -CGFloat.pi / 2)
            tf.concat()
            (yLabel as NSString).draw(at: .zero, withAttributes: labelAttrs)
            NSGraphicsContext.restoreGraphicsState()
        }

        // --- data lines ---
        for (idx, s) in series.enumerated() {
            guard s.points.count > 1 else { continue }
            let color = colors[idx % colors.count]
            color.setStroke()

            let path = NSBezierPath()
            path.lineWidth = 2
            let first = toView(s.points[0].x, s.points[0].y)
            path.move(to: first)

            for i in 1..<s.points.count {
                let p = toView(s.points[i].x, s.points[i].y)
                path.line(to: p)
            }
            path.stroke()
        }

        // --- legend (if multiple series, inside plot top-right) ---
        if series.count > 1 {
            let legAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            var legX = pr.maxX - 6
            for (idx, s) in series.enumerated().reversed() {
                let color = colors[idx % colors.count]
                color.setFill()
                let text = s.label as NSString
                let tw = text.size(withAttributes: legAttrs).width
                legX -= (tw + 14)
                NSBezierPath(ovalIn: CGRect(x: legX, y: pr.minY + 3, width: 6, height: 6)).fill()
                text.draw(at: CGPoint(x: legX + 8, y: pr.minY + 1), withAttributes: legAttrs)
            }
        }
    }
}

// MARK: - PlotView

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

    private struct PlotPoint {
        let x: Double
        let y: Double
        let series: String
    }

    private var cmRange: (start: Double, end: Double)? {
        guard let mn = visibleMinX, let mx = visibleMaxX, mn < mx else { return nil }
        if xUnit == "nm" { return (1e7 / mx, 1e7 / mn) }
        return (mn, mx)
    }

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

    private var seriesData: [(points: [(x: Double, y: Double)], label: String)] {
        var result: [(points: [(x: Double, y: Double)], label: String)] = []
        for h in history {
            let (dx, dy) = visibleSlice(x: h.x, y: h.y)
            var pts: [(Double, Double)] = []
            for i in 0..<min(dx.count, dy.count) {
                let (px, py) = transform(x: dx[i], y: dy[i])
                if px.isFinite, py.isFinite { pts.append((px, py)) }
            }
            result.append((pts, h.label))
        }
        let (cx, cy) = visibleSlice(x: xValues, y: yValues)
        var cur: [(Double, Double)] = []
        for i in 0..<min(cx.count, cy.count) {
            let (px, py) = transform(x: cx[i], y: cy[i])
            if px.isFinite, py.isFinite { cur.append((px, py)) }
        }
        result.append((cur, "Current"))
        return result
    }

    private func transform(x: Double, y: Double) -> (Double, Double) {
        let dx = xUnit == "nm" ? 1e7 / x : x
        let dy = yUnit == "Absorption" ? max(0, (1.0 - exp(-y)) * 100.0) : max(0, y)
        return (dx, dy)
    }

    private var xLabel: String { xUnit == "nm" ? "Wavelength /nm" : "Wavenumber /cm⁻¹" }
    private var yLabel: String { yUnit == "Absorption" ? "Absorption /%" : "alpha(ν)" }

    var body: some View {
        VStack(spacing: 2) {
            if seriesData.isEmpty || seriesData.allSatisfy({ $0.points.isEmpty }) {
                Text("No data. Load HITRAN file and press Generate.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                CoreGraphicsChartView(
                    series: seriesData,
                    xLabel: xLabel,
                    yLabel: yLabel,
                    xDomain: {
                        if let a = visibleMinX, let b = visibleMaxX, a < b { return a...b }
                        return nil
                    }()
                )
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
            }
        }
        .padding(6)
        .background(Color(NSColor.controlBackgroundColor))
    }
}
