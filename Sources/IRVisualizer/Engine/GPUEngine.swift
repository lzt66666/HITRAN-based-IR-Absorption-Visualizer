import Foundation
import Metal

struct GPULine {
    let nu: Float
    let sw: Float
    let gammaAir: Float
    let gammaSelf: Float
    let elower: Float
    let nAir: Float
    let deltaAir: Float
}

struct GPUParams {
    let temperature: Float
    let pressure: Float
    let moleFraction: Float
    let opticalLength: Float
    let molarMass: Float
    let qt0: Float
    let qt: Float
    let nuStart: Float
    let step: Float
    let cutoff: Float
    let pad: Float
}

final class GPUEngine {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLComputePipelineState

    private let metalSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct GPULine {
        float nu;
        float sw;
        float gamma_air;
        float gamma_self;
        float elower;
        float n_air;
        float delta_air;
    };

    struct GPUParams {
        float temperature;
        float pressure;
        float mole_fraction;
        float optical_length;
        float molar_mass;
        float qt0;
        float qt;
        float nu_start;
        float step;
        float cutoff;
        float pad;
    };

    constant float h = 6.62606896e-34;
    constant float c = 29979245800.0;
    constant float k = 1.3806505e-23;
    constant float T0 = 296.0;
    constant float sqrt_ln2 = 0.8325546111576978;
    constant float M_PI = 3.141592653589793;

    float2 cadd(float2 a, float2 b) { return float2(a.x + b.x, a.y + b.y); }
    float2 csub(float2 a, float2 b) { return float2(a.x - b.x, a.y - b.y); }
    float2 cmul(float2 a, float2 b) { return float2(a.x*b.x - a.y*b.y, a.x*b.y + a.y*b.x); }
    float2 cdiv(float2 a, float2 b) {
        float d = b.x*b.x + b.y*b.y;
        return float2((a.x*b.x + a.y*b.y)/d, (a.y*b.x - a.x*b.y)/d);
    }

    float voigt_humlicek(float X, float Y) {
        if (Y < 1e-10) Y = 1e-10;
        float2 T1 = float2(Y, -X);
        float S = fabs(X) + Y;
        float2 W;

        if (S >= 15.0) {
            float2 U = cmul(T1, T1);
            W = cdiv(cmul(T1, float2(0.5641896, 0)), cadd(float2(0.5, 0), U));
        } else if (S >= 5.5) {
            float2 U = cmul(T1, T1);
            float2 a = cadd(float2(1.410474, 0), cmul(U, float2(0.5641896, 0)));
            float2 b = cadd(float2(0.75, 0), cmul(U, cadd(float2(3, 0), U)));
            W = cdiv(cmul(T1, a), b);
        } else if (Y >= (0.195 * fabs(X) - 0.176)) {
            float2 T2 = cmul(T1, T1);
            float2 T3 = cmul(T2, T1);
            float2 T4 = cmul(T3, T1);
            float2 T5 = cmul(T4, T1);
            float2 num = cadd(float2(16.4955, 0),
                cadd(cmul(T1, float2(20.20933, 0)),
                cadd(cmul(T2, float2(11.96482, 0)),
                cadd(cmul(T3, float2(3.778987, 0)),
                cmul(T4, float2(0.5642236, 0))))));
            float2 den = cadd(float2(16.4955, 0),
                cadd(cmul(T1, float2(38.82363, 0)),
                cadd(cmul(T2, float2(39.27121, 0)),
                cadd(cmul(T3, float2(21.69274, 0)),
                cadd(cmul(T4, float2(6.699398, 0)),
                cmul(T5, float2(1, 0)))))));
            W = cdiv(num, den);
        } else {
            float2 U = cmul(T1, T1);
            float2 U2 = cmul(U, U);
            float2 U3 = cmul(U2, U);
            float2 U4 = cmul(U2, U2);
            float2 U5 = cmul(U4, U);
            float2 U6 = cmul(U3, U3);
            float2 U7 = cmul(U6, U);
            float2 num = cmul(T1, cadd(float2(36183.31, 0),
                csub(cmul(U, float2(3321.9905, 0)),
                cadd(cmul(U2, float2(1540.787, 0)),
                csub(cmul(U3, float2(219.0313, 0)),
                cadd(cmul(U4, float2(35.76683, 0)),
                csub(cmul(U5, float2(1.320522, 0)),
                cmul(U6, float2(0.56419, 0)))))))));
            float2 den = cadd(float2(32066.6, 0),
                csub(cmul(U, float2(24322.84, 0)),
                cadd(cmul(U2, float2(9022.228, 0)),
                csub(cmul(U3, float2(2186.181, 0)),
                cadd(cmul(U4, float2(364.2191, 0)),
                csub(cmul(U5, float2(61.57037, 0)),
                cadd(cmul(U6, float2(1.841439, 0)),
                cmul(U7, float2(1, 0)))))))));
            float2 F = cdiv(num, den);
            float exp_re = exp(U.x);
            float exp_im = cos(U.y);
            W = csub(float2(exp_re * exp_im, 0), F);
        }
        return W.x;
    }

    int binary_search_start(device const GPULine *lines, int n, float nu, float cutoff) {
        int lo = 0, hi = n;
        while (lo < hi) {
            int mid = (lo + hi) / 2;
            if (lines[mid].nu < nu - cutoff) lo = mid + 1;
            else hi = mid;
        }
        return lo;
    }

    int binary_search_end(device const GPULine *lines, int n, float nu, float cutoff) {
        int lo = 0, hi = n;
        while (lo < hi) {
            int mid = (lo + hi) / 2;
            if (lines[mid].nu <= nu + cutoff) lo = mid + 1;
            else hi = mid;
        }
        return lo;
    }

    kernel void compute_spectrum(
        device const GPULine *lines [[buffer(0)]],
        constant GPUParams &p [[buffer(1)]],
        device float *output_y [[buffer(2)]],
        constant int &total_lines [[buffer(3)]],
        uint idx [[thread_position_in_grid]]
    ) {
        float nu = p.nu_start + float(idx) * p.step;
        float cutoff = p.cutoff;
        float X = p.mole_fraction;
        float Xair = 1.0 - X;
        float T = p.temperature;
        float P = p.pressure;
        float L = p.optical_length;
        float M = p.molar_mass;
        float log_296_T = log(296.0 / T);

        int start = binary_search_start(lines, total_lines, nu, cutoff);
        int end = binary_search_end(lines, total_lines, nu, cutoff);

        float alpha = 0.0;
        for (int i = start; i < end; i++) {
            device const GPULine &line = lines[i];
            float v0 = line.nu + P * Xair * line.delta_air * exp(0.96 * log_296_T);
            float ST = line.sw * (p.qt0 / p.qt)
                * exp(-h * c * line.elower / k * (1.0 / T - 1.0 / T0))
                * (1.0 - exp(-h * c * v0 / (k * T)))
                / (1.0 - exp(-h * c * v0 / (k * T0)));
            float STperCm = ST * 7.34e21 / T;
            float gst = line.gamma_self * exp(0.75 * log_296_T);
            float gat = line.gamma_air * exp(line.n_air * log_296_T);
            float dvc = P * (X * 2.0 * gst + Xair * 2.0 * gat);
            float dvd = v0 * 7.1623e-7 * sqrt(T / M);
            float a = sqrt_ln2 * dvc / dvd;
            float w = 2.0 * sqrt_ln2 * (nu - v0) / dvd;
            float phiV = 2.0 / dvd * sqrt(log(2.0) / M_PI) * voigt_humlicek(w, a);
            alpha += STperCm * P * X * L * phiV;
        }
        output_y[idx] = alpha;
    }
    """

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else { return nil }
        self.device = device
        self.commandQueue = queue
        do {
            let library = try device.makeLibrary(source: metalSource, options: nil)
            guard let func_ = library.makeFunction(name: "compute_spectrum"),
                  let pipeline = try? device.makeComputePipelineState(function: func_) else { return nil }
            self.pipeline = pipeline
        } catch {
            print("Metal compile error: \(error)"); return nil
        }
    }

    func compute(lines: [HitranLine], params: GPUParams,
                 totalLines: Int, count: Int) -> [Double]? {
        let gpuLines = lines.map { GPULine(
            nu: Float($0.nu), sw: Float($0.sw),
            gammaAir: Float($0.gammaAir), gammaSelf: Float($0.gammaSelf),
            elower: Float($0.elower), nAir: Float($0.nAir),
            deltaAir: Float($0.deltaAir)
        )}

        guard let lineBuf = device.makeBuffer(bytes: gpuLines,
                length: totalLines * MemoryLayout<GPULine>.stride,
                options: .storageModeShared),
              let paramBuf = device.makeBuffer(bytes: [params],
                length: MemoryLayout<GPUParams>.stride,
                options: .storageModeShared),
              let outBuf = device.makeBuffer(
                length: count * MemoryLayout<Float>.stride,
                options: .storageModeShared),
              let numBuf = device.makeBuffer(bytes: [Int32(totalLines)],
                length: MemoryLayout<Int32>.stride,
                options: .storageModeShared) else { return nil }

        guard let cmdBuf = commandQueue.makeCommandBuffer(),
              let encoder = cmdBuf.makeComputeCommandEncoder() else { return nil }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(lineBuf, offset: 0, index: 0)
        encoder.setBuffer(paramBuf, offset: 0, index: 1)
        encoder.setBuffer(outBuf, offset: 0, index: 2)
        encoder.setBuffer(numBuf, offset: 0, index: 3)

        let w = pipeline.threadExecutionWidth
        let groupSize = MTLSize(width: w, height: 1, depth: 1)
        let gridSize = MTLSize(width: count, height: 1, depth: 1)
        encoder.dispatchThreads(gridSize, threadsPerThreadgroup: groupSize)
        encoder.endEncoding()
        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()

        let outPtr = outBuf.contents().bindMemory(to: Float.self, capacity: count)
        return (0..<count).map { Double(outPtr[$0]) }
    }
}
