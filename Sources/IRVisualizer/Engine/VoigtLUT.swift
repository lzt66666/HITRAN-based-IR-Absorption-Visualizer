import Foundation

final class VoigtLUT {
    static let shared = VoigtLUT()

    let nx = 4096
    let ny = 2048
    let xMin = 0.0
    let xMax = 15.0
    let yMin = 0.001
    let yMax = 20.0

    var grid: [Float]

    private init() {
        grid = [Float](repeating: 0, count: nx * ny)
        precompute()
    }

    private func precompute() {
        let logYMin = log(yMin)
        let logYMax = log(yMax)

        DispatchQueue.concurrentPerform(iterations: ny) { iy in
            let y = exp(logYMin + Double(iy) / Double(ny - 1) * (logYMax - logYMin))
            for ix in 0..<nx {
                let x = xMin + Double(ix) / Double(nx - 1) * (xMax - xMin)
                grid[iy * nx + ix] = Float(voigtProfile(x, y))
            }
        }
    }

    func lookup(x: Double, y: Double) -> Double {
        let ax = abs(x)
        let yy = max(y, yMin)

        if ax <= xMax && yy <= yMax {
            let gx = ax / xMax * Double(nx - 1)
            let gy = (log(yy) - log(yMin)) / (log(yMax) - log(yMin)) * Double(ny - 1)
            let ix = Int(gx)
            let iy = Int(gy)

            if ix >= 0, ix < nx - 1, iy >= 0, iy < ny - 1 {
                let fx = gx - Double(ix)
                let fy = gy - Double(iy)
                let v00 = Double(grid[iy * nx + ix])
                let v10 = Double(grid[iy * nx + ix + 1])
                let v01 = Double(grid[(iy + 1) * nx + ix])
                let v11 = Double(grid[(iy + 1) * nx + ix + 1])
                let top = v00 + (v10 - v00) * fx
                let bot = v01 + (v11 - v01) * fx
                return max(0, top + (bot - top) * fy)
            }
        }

        return lorentzianTail(ax, yy)
    }

    @inline(__always)
    private func lorentzianTail(_ x: Double, _ y: Double) -> Double {
        y / (Double.pi * (x * x + y * y))
    }
}
