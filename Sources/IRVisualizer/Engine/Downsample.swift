import Foundation

func downsampleLTTB(x: [Double], y: [Double], threshold: Int) -> (x: [Double], y: [Double]) {
    let n = x.count
    guard n > 2, threshold > 2, threshold < n else { return (x, y) }

    var rx = [Double](repeating: 0, count: threshold)
    var ry = [Double](repeating: 0, count: threshold)
    rx[0] = x[0]; ry[0] = y[0]
    rx[threshold - 1] = x[n - 1]; ry[threshold - 1] = y[n - 1]

    let bucketSize = Double(n - 2) / Double(threshold - 1)
    var a: Int = 0
    var avgX: Double = 0
    var avgY: Double = 0

    var nextA: Int = 0

    for i in 1..<threshold - 1 {
        let rangeStart = Int(Double(i - 1) * bucketSize) + 1
        let rangeEnd = min(Int(Double(i) * bucketSize) + 1, n - 1)

        if i == 1 {
            nextA = rangeStart
        }

        let avgRangeStart = Int(Double(i) * bucketSize) + 1
        let avgRangeEnd = min(Int(Double(i + 1) * bucketSize) + 1, n - 1)

        if avgRangeEnd > avgRangeStart {
            var sumX: Double = 0, sumY: Double = 0
            for j in avgRangeStart..<avgRangeEnd {
                sumX += x[j]
                sumY += y[j]
            }
            let count = Double(avgRangeEnd - avgRangeStart)
            avgX = sumX / count
            avgY = sumY / count
        } else {
            avgX = x[avgRangeStart]
            avgY = y[avgRangeStart]
        }

        var maxArea: Double = -1
        var maxAreaIdx: Int = nextA

        for j in rangeStart..<rangeEnd {
            let area = abs(
                (x[a] - avgX) * (y[j] - avgY) -
                (x[a] - x[j]) * (avgY - y[a])
            )
            if area > maxArea {
                maxArea = area
                maxAreaIdx = j
            }
        }

        rx[i] = x[maxAreaIdx]
        ry[i] = y[maxAreaIdx]
        a = maxAreaIdx

        if i < threshold - 2 {
            nextA = Int(Double(i + 1) * bucketSize) + 1
        }
    }

    return (rx, ry)
}
