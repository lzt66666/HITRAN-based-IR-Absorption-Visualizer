import Foundation

class SimulationEngine: ObservableObject {
    @Published var lines: [HitranLine] = []
    @Published var pf: PartitionFunction?
    @Published var qt0: Double = 1
    @Published var qt: Double = 1

    @Published var xValues: [Double] = []
    @Published var yValues: [Double] = []

    @Published var hitranState: Bool = false
    @Published var pfState: Bool = false
    @Published var isRunning: Bool = false
    @Published var useGPU: Bool = false
    @Published var gpuAvailable: Bool = false

    private var gpuEngine: GPUEngine?

    init() {
        gpuEngine = GPUEngine()
        gpuAvailable = gpuEngine != nil
        useGPU = gpuAvailable
    }

    func loadHitran(from url: URL) -> Bool {
        guard let content = try? String(contentsOf: url) else { return false }
        var parsed: [HitranLine] = []
        parsed.reserveCapacity(500_000)
        content.enumerateLines { line, _ in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("local_iso_id") else { return }
            let cols = trimmed.split(separator: ",", omittingEmptySubsequences: false)
            guard cols.count >= 11,
                  let nu = Double(cols[3]),
                  let sw = Double(cols[4]),
                  let ga = Double(cols[5]),
                  let gs = Double(cols[6]),
                  let el = Double(cols[7]),
                  let na = Double(cols[8]),
                  let da = Double(cols[9]) else { return }
            parsed.append(HitranLine(nu: nu, sw: sw, gammaAir: ga,
                                      gammaSelf: gs, elower: el,
                                      nAir: na, deltaAir: da))
        }
        guard !parsed.isEmpty else { return false }
        lines = parsed.sorted(by: { $0.nu < $1.nu })
        hitranState = true
        return true
    }

    func loadPartitionFunction(from url: URL) -> Bool {
        guard let pf = PartitionFunction.load(from: url) else { return false }
        self.pf = pf
        self.qt0 = pf.value(at: 296)
        pfState = true
        return true
    }

    func runSimulation(
        freqRange: (start: Double, end: Double),
        resolution: Double,
        temperature: Double,
        pressure: Double,
        moleFraction: Double,
        length: Double,
        molarMass: Double,
        moleculeName: String
    ) {
        guard !lines.isEmpty else { return }
        isRunning = true

        let nuRange = freqRange.end - freqRange.start
        let nuRangeZoom = nuRange * resolution
        let count = max(1, min(Int(nuRangeZoom), 10_000_000))
        let step = nuRange / Double(max(1, count - 1))

        let maxGamma = max(
            lines.map(\.gammaAir).max() ?? 0.1,
            lines.map(\.gammaSelf).max() ?? 0.1
        )
        let cutoff = max(5.0, 50.0 * pressure * maxGamma)

        let totalLines = lines.count

        if useGPU, let engine = gpuEngine {
            let params = GPUParams(
                temperature: Float(temperature),
                pressure: Float(pressure),
                moleFraction: Float(moleFraction),
                opticalLength: Float(length),
                molarMass: Float(molarMass),
                qt0: Float(qt0),
                qt: Float(qt),
                nuStart: Float(freqRange.start),
                step: Float(step),
                cutoff: Float(cutoff),
                pad: 0
            )

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                let result = engine.compute(
                    lines: self.lines, params: params,
                    totalLines: totalLines, count: count
                )
                let xs = (0..<count).map { freqRange.start + Double($0) * step }

                DispatchQueue.main.async {
                    if let ys = result {
                        self.xValues = xs
                        self.yValues = ys
                    } else {
                        self.runCPU(lut: VoigtLUT.shared, freqRange: freqRange,
                                    count: count, step: step, cutoff: cutoff,
                                    totalLines: totalLines, temperature: temperature,
                                    pressure: pressure, moleFraction: moleFraction,
                                    length: length, molarMass: molarMass)
                    }
                    self.isRunning = false
                }
            }
        } else {
            let lut = VoigtLUT.shared
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                self.runCPU(lut: lut, freqRange: freqRange, count: count,
                           step: step, cutoff: cutoff, totalLines: totalLines,
                           temperature: temperature, pressure: pressure,
                           moleFraction: moleFraction, length: length,
                           molarMass: molarMass)
            }
        }
    }

    private func runCPU(lut: VoigtLUT,
                        freqRange: (start: Double, end: Double),
                        count: Int, step: Double, cutoff: Double,
                        totalLines: Int,
                        temperature: Double, pressure: Double,
                        moleFraction: Double, length: Double,
                        molarMass: Double) {
        let T = temperature, P = pressure, X = moleFraction
        let L = length, M = molarMass
        let qt0 = self.qt0, qt = self.qt

        var xs = [Double](repeating: 0, count: count)
        var ys = [Double](repeating: 0, count: count)

        if count > 500 {
            DispatchQueue.concurrentPerform(iterations: count) { idx in
                let nu = freqRange.start + Double(idx) * step
                var low = 0, high = totalLines
                while low < high {
                    let mid = (low + high) / 2
                    if lines[mid].nu < nu - cutoff { low = mid + 1 }
                    else { high = mid }
                }
                let startIdx = low
                low = 0; high = totalLines
                while low < high {
                    let mid = (low + high) / 2
                    if lines[mid].nu <= nu + cutoff { low = mid + 1 }
                    else { high = mid }
                }
                let endIdx = low

                var alpha = 0.0
                for j in startIdx..<endIdx {
                    let line = lines[j]
                    alpha += abline(freq: nu, lineCenter: line.nu, lineStrength: line.sw,
                                    gammaAir: line.gammaAir, gammaSelf: line.gammaSelf,
                                    elower: line.elower, nAir: line.nAir,
                                    molarMass: M, moleFraction: X,
                                    qt0: qt0, qt: qt, temperature: T,
                                    pressure: P, length: L, deltaAir: line.deltaAir)
                }
                xs[idx] = nu
                ys[idx] = alpha
            }
        } else {
            for idx in 0..<count {
                let nu = freqRange.start + Double(idx) * step
                var low = 0, high = totalLines
                while low < high {
                    let mid = (low + high) / 2
                    if lines[mid].nu < nu - cutoff { low = mid + 1 }
                    else { high = mid }
                }
                let startIdx = low
                low = 0; high = totalLines
                while low < high {
                    let mid = (low + high) / 2
                    if lines[mid].nu <= nu + cutoff { low = mid + 1 }
                    else { high = mid }
                }
                let endIdx = low

                var alpha = 0.0
                for j in startIdx..<endIdx {
                    let line = lines[j]
                    alpha += abline(freq: nu, lineCenter: line.nu, lineStrength: line.sw,
                                    gammaAir: line.gammaAir, gammaSelf: line.gammaSelf,
                                    elower: line.elower, nAir: line.nAir,
                                    molarMass: M, moleFraction: X,
                                    qt0: qt0, qt: qt, temperature: T,
                                    pressure: P, length: L, deltaAir: line.deltaAir)
                }
                xs[idx] = nu
                ys[idx] = alpha
            }
        }

        DispatchQueue.main.async {
            self.xValues = xs
            self.yValues = ys
            self.isRunning = false
        }
    }
}
