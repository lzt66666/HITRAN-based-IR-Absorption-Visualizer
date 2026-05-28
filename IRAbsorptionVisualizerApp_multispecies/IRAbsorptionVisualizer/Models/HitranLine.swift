import Foundation

struct HitranLine: Codable {
    let molecId: Int
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

    static func loadAll(from data: Data) -> [Int: PartitionFunction] {
        var result: [Int: PartitionFunction] = [:]
        guard data.count >= 8 else { return [:] }
        var offset = 0

        let magic = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) }
        guard magic == 0x50465251 else { return [:] }
        offset += 4

        let numMolecules = Int(data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) })
        offset += 4

        for _ in 0..<numMolecules {
            guard offset + 8 <= data.count else { break }
            let mid = Int(data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: Int32.self) })
            offset += 4
            let n = Int(data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: Int32.self) })
            offset += 4
            guard n > 0 else { continue }

            let chunkSize = n * MemoryLayout<Float>.stride
            guard offset + chunkSize * 2 <= data.count else { break }

            let temps: [Double] = data.withUnsafeBytes { ptr in
                let base = ptr.baseAddress!.advanced(by: offset)
                return UnsafeBufferPointer(start: base.assumingMemoryBound(to: Float.self), count: n).map { Double($0) }
            }
            offset += chunkSize

            let vals: [Double] = data.withUnsafeBytes { ptr in
                let base = ptr.baseAddress!.advanced(by: offset)
                return UnsafeBufferPointer(start: base.assumingMemoryBound(to: Float.self), count: n).map { Double($0) }
            }
            offset += chunkSize

            result[mid] = PartitionFunction(temperatures: temps, values: vals)
        }
        return result
    }
}
