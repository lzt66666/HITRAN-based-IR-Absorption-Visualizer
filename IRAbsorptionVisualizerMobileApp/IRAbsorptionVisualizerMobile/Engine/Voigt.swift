import Foundation

private struct C {
    let re: Double
    let im: Double
    init(_ re: Double, _ im: Double = 0) { self.re = re; self.im = im }
}

private func +(l: C, r: C) -> C { C(l.re + r.re, l.im + r.im) }
private func -(l: C, r: C) -> C { C(l.re - r.re, l.im - r.im) }
private func *(l: C, r: C) -> C { C(l.re * r.re - l.im * r.im, l.re * r.im + l.im * r.re) }
private func *(l: Double, r: C) -> C { C(l * r.re, l * r.im) }
private func /(l: C, r: C) -> C {
    let d = r.re * r.re + r.im * r.im
    return C((l.re * r.re + l.im * r.im) / d, (l.im * r.re - l.re * r.im) / d)
}

private func voigtHumlicek(_ X: Double, _ Y: Double) -> Double {
    let Y = abs(Y) + .leastNonzeroMagnitude
    let T1 = C(Y, -X)
    let S = abs(X) + Y

    let W: C
    if S >= 15 {
        let U = T1 * T1
        let num = T1 * C(0.5641896)
        let den = C(0.5) + U
        W = num / den
    } else if S >= 5.5 {
        let U = T1 * T1
        let a = C(1.410474) + U * C(0.5641896)
        let b = C(0.75) + U * (C(3) + U)
        W = (T1 * a) / b
    } else if Y >= (0.195 * abs(X) - 0.176) {
        let T2 = T1 * T1
        let T3 = T2 * T1
        let T4 = T3 * T1
        let T5 = T4 * T1
        let num = C(16.4955) + T1 * C(20.20933) + T2 * C(11.96482)
                + T3 * C(3.778987) + T4 * C(0.5642236)
        let den = C(16.4955) + T1 * C(38.82363) + T2 * C(39.27121)
                + T3 * C(21.69274) + T4 * C(6.699398) + T5 * C(1)
        W = num / den
    } else {
        let U = T1 * T1
        let U2 = U * U
        let U3 = U2 * U
        let U4 = U2 * U2
        let U5 = U4 * U
        let U6 = U3 * U3
        let U7 = U6 * U
        let num = T1 * (C(36183.31)
            - U * C(3321.9905) + U2 * C(1540.787) - U3 * C(219.0313)
            + U4 * C(35.76683) - U5 * C(1.320522) + U6 * C(0.56419))
        let den = C(32066.6)
            - U * C(24322.84) + U2 * C(9022.228) - U3 * C(2186.181)
            + U4 * C(364.2191) - U5 * C(61.57037) + U6 * C(1.841439) - U7 * C(1)
        let F = num / den
        W = C(exp(U.re) * cos(U.im)) - F
    }
    return W.re
}

func voigtProfile(_ x: Double, _ y: Double) -> Double {
    voigtHumlicek(x, y)
}
