import Foundation

struct HitranLine: Codable {
    let nu: Double
    let sw: Double
    let gammaAir: Double
    let gammaSelf: Double
    let elower: Double
    let nAir: Double
    let deltaAir: Double
}

struct PartitionFunction {
    let temperatures: [Double]
    let values: [Double]

    func value(at T: Double) -> Double {
        guard T >= 296 else { return values.first ?? 1 }
        var low = 0
        var high = temperatures.count - 1
        while low < high - 1 {
            let mid = (low + high) / 2
            if temperatures[mid] < T { low = mid }
            else { high = mid }
        }
        if high == low { return values[low] }
        let t1 = temperatures[low], t2 = temperatures[high]
        let v1 = values[low], v2 = values[high]
        return v1 + (v2 - v1) * (T - t1) / (t2 - t1)
    }

    static func load(from url: URL) -> PartitionFunction? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        var temps: [Double] = []
        var vals: [Double] = []
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("T,K") || trimmed.hasPrefix("T") { continue }
            let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            if parts.count >= 2,
               let t = Double(parts[0]),
               let v = Double(parts[1]) {
                temps.append(t)
                vals.append(v)
            }
        }
        guard !temps.isEmpty else { return nil }
        return PartitionFunction(temperatures: temps, values: vals)
    }
}

struct MoleculeConfig {
    let name: String
    let molarMass: Double
    let pfFilename: String?

    static let builtins: [String: MoleculeConfig] = [
        "H2O":  MoleculeConfig(name: "H2O",  molarMass: 18, pfFilename: nil),
        "C2H4": MoleculeConfig(name: "C2H4", molarMass: 28, pfFilename: nil),
        "CO2":  MoleculeConfig(name: "CO2",  molarMass: 44, pfFilename: nil),
        "N2O":  MoleculeConfig(name: "N2O",  molarMass: 44, pfFilename: nil),
        "C2H2": MoleculeConfig(name: "C2H2", molarMass: 26, pfFilename: nil),
    ]
}
