import Combine
import Foundation

class SimulationEngine: ObservableObject {
    @Published var componentLines: [Int: [HitranLine]] = [:]
    @Published var componentPFs: [Int: PartitionFunction] = [:]
    @Published var moleculeIds: [Int] = []
    @Published var detectedMolecules: [DetectedMolecule] = []
    @Published var loadedFileNames: [String] = []

    @Published var userPF: PartitionFunction?
    @Published var userPFLabel: String = ""

    @Published var xValues: [Double] = []
    @Published var yValues: [Double] = []
    @Published var componentYValues: [Int: [Double]] = [:]

    @Published var hitranState: Bool = false
    @Published var isRunning: Bool = false

    private var gpuEngine: GPUEngine?
    private static var cachedBinaryPF: [Int: PartitionFunction]?

    init() {
        gpuEngine = GPUEngine()
    }

    func appendHitran(from url: URL) -> Bool {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return false }

        var groupedLines = componentLines
        content.enumerateLines { line, _ in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("local_iso_id") else { return }
            let cols = trimmed.split(separator: ",", omittingEmptySubsequences: false)
            guard cols.count >= 11,
                  let mid = Int(cols[2]),
                  let nu = Double(cols[3]),
                  let sw = Double(cols[4]),
                  let ga = Double(cols[5]),
                  let gs = Double(cols[6]),
                  let el = Double(cols[7]),
                  let na = Double(cols[8]),
                  let da = Double(cols[9]) else { return }
            let hl = HitranLine(molecId: mid, nu: nu, sw: sw, gammaAir: ga,
                                gammaSelf: gs, elower: el, nAir: na, deltaAir: da)
            groupedLines[mid, default: []].append(hl)
        }

        guard !groupedLines.isEmpty else { return false }

        var sortedLines: [Int: [HitranLine]] = [:]
        for (mid, lines) in groupedLines {
            sortedLines[mid] = lines.sorted(by: { $0.nu < $1.nu })
        }
        componentLines = sortedLines
        moleculeIds = sortedLines.keys.sorted()
        loadedFileNames.append(url.lastPathComponent)
        refreshComponentInfo()
        hitranState = true
        return true
    }

    func clearAllData() {
        componentLines = [:]
        componentPFs = [:]
        moleculeIds = []
        detectedMolecules = []
        loadedFileNames = []
        userPF = nil
        userPFLabel = ""
        xValues = []
        yValues = []
        componentYValues = [:]
        hitranState = false
    }

    func loadUserPartitionFunction(from url: URL) -> Bool {
        guard let pf = PartitionFunction.load(from: url) else { return false }
        userPF = pf
        userPFLabel = url.lastPathComponent
        refreshComponentInfo()
        return true
    }

    private func refreshComponentInfo() {
        if SimulationEngine.cachedBinaryPF == nil {
            if let url = Bundle.main.url(forResource: "PartfunData", withExtension: "bin"),
               let data = try? Data(contentsOf: url) {
                SimulationEngine.cachedBinaryPF = PartitionFunction.loadAll(from: data)
            } else {
                SimulationEngine.cachedBinaryPF = [:]
            }
        }

        var pfs: [Int: PartitionFunction] = [:]
        var detected: [DetectedMolecule] = []

        if userPF != nil {
            for mid in moleculeIds {
                let lines = componentLines[mid] ?? []
                let formula = moleculeDatabase[mid]?.formula ?? "Mol\(mid)"
                detected.append(DetectedMolecule(
                    molecId: mid, formula: formula,
                    lineCount: lines.count, pfStatus: "user PF"
                ))
            }
        } else {
            for mid in moleculeIds {
                let lines = componentLines[mid] ?? []
                var pfStatus: String
                var formula = "Mol\(mid)"

                if let info = moleculeDatabase[mid] {
                    formula = info.formula
                    if let pf = SimulationEngine.cachedBinaryPF?[mid] {
                        pfs[mid] = pf
                        pfStatus = "built-in"
                    } else {
                        pfStatus = "no PF"
                    }
                } else {
                    pfStatus = "unknown"
                }

                detected.append(DetectedMolecule(
                    molecId: mid, formula: formula,
                    lineCount: lines.count, pfStatus: pfStatus
                ))
            }
        }

        componentPFs = pfs
        detectedMolecules = detected
    }

    func runSimulation(
        freqRange: (start: Double, end: Double),
        resolution: Double,
        temperature: Double,
        pressure: Double,
        moleFraction: Double,
        length: Double
    ) {
        guard !componentLines.isEmpty else { return }
        isRunning = true

        let nuRange = freqRange.end - freqRange.start
        let nuRangeZoom = nuRange * resolution
        let count = max(1, min(Int(nuRangeZoom), 10_000_000))
        let step = nuRange / Double(max(1, count - 1))

        var maxGamma = 0.1
        for (_, lines) in componentLines {
            for line in lines {
                if line.gammaAir > maxGamma { maxGamma = line.gammaAir }
                if line.gammaSelf > maxGamma { maxGamma = line.gammaSelf }
            }
        }
        let cutoff = max(5.0, 50.0 * pressure * maxGamma)

        let T = temperature, P = pressure, X = moleFraction, L = length
        let upfQt0 = userPF?.value(at: 296) ?? 1
        let upfQt = userPF?.value(at: round(T)) ?? 1

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, let engine = self.gpuEngine else {
                DispatchQueue.main.async { self?.isRunning = false }
                return
            }

            var totalY = [Double](repeating: 0, count: count)
            var perComponentY: [Int: [Double]] = [:]

            for mid in self.moleculeIds {
                guard let lines = self.componentLines[mid], !lines.isEmpty else { continue }

                let info = moleculeDatabase[mid]
                let M = info?.molarMass ?? 44.0

                let qt0: Double
                let qt: Double
                if userPF != nil {
                    qt0 = upfQt0
                    qt = upfQt
                } else {
                    qt0 = self.componentPFs[mid]?.value(at: 296) ?? 1
                    qt = self.componentPFs[mid]?.value(at: round(T)) ?? 1
                }

                let params = GPUParams(
                    temperature: Float(T), pressure: Float(P),
                    moleFraction: Float(X), opticalLength: Float(L),
                    molarMass: Float(M), qt0: Float(qt0), qt: Float(qt),
                    nuStart: Float(freqRange.start), step: Float(step),
                    cutoff: Float(cutoff), pad: 0
                )
                let compY = engine.compute(lines: lines, params: params,
                                           totalLines: lines.count, count: count) ?? []
                perComponentY[mid] = compY
                for i in 0..<count { totalY[i] += compY[i] }
            }

            let xs = (0..<count).map { freqRange.start + Double($0) * step }

            DispatchQueue.main.async {
                self.xValues = xs
                self.yValues = totalY
                self.componentYValues = perComponentY
                self.isRunning = false
            }
        }
    }
}
