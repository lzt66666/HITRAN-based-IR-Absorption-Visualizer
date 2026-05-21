import Foundation

let hPlanck = 6.626_068_96e-34
let cLight = 299_792_458.0 * 100.0
let kBoltzmann = 1.380_650_5e-23
let T0 = 296.0

func abline(freq: Double, lineCenter: Double, lineStrength: Double,
            gammaAir: Double, gammaSelf: Double, elower: Double,
            nAir: Double, molarMass: Double, moleFraction: Double,
            qt0: Double, qt: Double, temperature: Double,
            pressure: Double, length: Double, deltaAir: Double) -> Double {
    let T = temperature
    let P = pressure
    let L = length
    let X = moleFraction
    let Xair = 1.0 - X

    let shiftedCenter = lineCenter + P * Xair * deltaAir * pow(296.0 / T, 0.96)

    let ST = lineStrength * (qt0 / qt)
        * exp(-hPlanck * cLight * elower / kBoltzmann * (1.0 / T - 1.0 / T0))
        * (1.0 - exp(-hPlanck * cLight * shiftedCenter / (kBoltzmann * T)))
        / (1.0 - exp(-hPlanck * cLight * shiftedCenter / (kBoltzmann * T0)))
    let STperAtm = ST
    let STperCm = STperAtm * 7.34e21 / T

    let gammaSelfT = gammaSelf * pow(T0 / T, 0.75)
    let gammaAirT = gammaAir * pow(T0 / T, nAir)
    let deltaVC = P * (X * 2.0 * gammaSelfT + Xair * 2.0 * gammaAirT)

    let deltaVD = shiftedCenter * 7.1623e-7 * sqrt(T / molarMass)

    let a = sqrt(log(2.0)) * deltaVC / deltaVD
    let w = 2.0 * sqrt(log(2.0)) * (freq - shiftedCenter) / deltaVD

    let phiV = 2.0 / deltaVD * sqrt(log(2.0) / Double.pi) * voigtProfile(w, a)

    let A = STperCm * P * X * L
    return A * phiV
}
