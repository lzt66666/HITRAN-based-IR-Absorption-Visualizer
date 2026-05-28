import Foundation

struct MoleculeInfo {
    let molecId: Int
    let formula: String
    let molarMass: Double
}

let moleculeDatabase: [Int: MoleculeInfo] = [
     1: MoleculeInfo(molecId:  1, formula: "H2O",    molarMass: 18.015),
     2: MoleculeInfo(molecId:  2, formula: "CO2",    molarMass: 44.010),
     3: MoleculeInfo(molecId:  3, formula: "O3",     molarMass: 48.000),
     4: MoleculeInfo(molecId:  4, formula: "N2O",    molarMass: 44.013),
     5: MoleculeInfo(molecId:  5, formula: "CO",     molarMass: 28.010),
     6: MoleculeInfo(molecId:  6, formula: "CH4",    molarMass: 16.043),
     7: MoleculeInfo(molecId:  7, formula: "O2",     molarMass: 32.000),
     8: MoleculeInfo(molecId:  8, formula: "NO",     molarMass: 30.006),
     9: MoleculeInfo(molecId:  9, formula: "SO2",    molarMass: 64.064),
    10: MoleculeInfo(molecId: 10, formula: "NO2",    molarMass: 46.006),
    11: MoleculeInfo(molecId: 11, formula: "NH3",    molarMass: 17.031),
    12: MoleculeInfo(molecId: 12, formula: "HNO3",   molarMass: 63.013),
    13: MoleculeInfo(molecId: 13, formula: "OH",     molarMass: 17.007),
    14: MoleculeInfo(molecId: 14, formula: "HF",     molarMass: 20.006),
    15: MoleculeInfo(molecId: 15, formula: "HCl",    molarMass: 36.461),
    16: MoleculeInfo(molecId: 16, formula: "HBr",    molarMass: 80.912),
    17: MoleculeInfo(molecId: 17, formula: "HI",     molarMass: 127.912),
    18: MoleculeInfo(molecId: 18, formula: "ClO",    molarMass: 51.452),
    19: MoleculeInfo(molecId: 19, formula: "OCS",    molarMass: 60.075),
    20: MoleculeInfo(molecId: 20, formula: "H2CO",   molarMass: 30.026),
    21: MoleculeInfo(molecId: 21, formula: "HOCl",   molarMass: 52.460),
    22: MoleculeInfo(molecId: 22, formula: "N2",     molarMass: 28.014),
    23: MoleculeInfo(molecId: 23, formula: "HCN",    molarMass: 27.025),
    24: MoleculeInfo(molecId: 24, formula: "CH3Cl",  molarMass: 50.488),
    25: MoleculeInfo(molecId: 25, formula: "H2O2",   molarMass: 34.015),
    26: MoleculeInfo(molecId: 26, formula: "C2H2",   molarMass: 26.038),
    27: MoleculeInfo(molecId: 27, formula: "C2H6",   molarMass: 30.070),
    28: MoleculeInfo(molecId: 28, formula: "PH3",    molarMass: 34.000),
    29: MoleculeInfo(molecId: 29, formula: "COF2",   molarMass: 66.007),
    30: MoleculeInfo(molecId: 30, formula: "SF6",    molarMass: 146.055),
    31: MoleculeInfo(molecId: 31, formula: "H2S",    molarMass: 34.081),
    32: MoleculeInfo(molecId: 32, formula: "HCOOH",  molarMass: 46.025),
    33: MoleculeInfo(molecId: 33, formula: "HO2",    molarMass: 33.007),
    34: MoleculeInfo(molecId: 34, formula: "O",      molarMass: 15.999),
    35: MoleculeInfo(molecId: 35, formula: "ClONO2", molarMass: 97.458),
    36: MoleculeInfo(molecId: 36, formula: "NO+",    molarMass: 30.006),
    37: MoleculeInfo(molecId: 37, formula: "HOBr",   molarMass: 96.911),
    38: MoleculeInfo(molecId: 38, formula: "C2H4",   molarMass: 28.054),
    39: MoleculeInfo(molecId: 39, formula: "CH3OH",  molarMass: 32.042),
    40: MoleculeInfo(molecId: 40, formula: "CH3Br",  molarMass: 94.939),
    41: MoleculeInfo(molecId: 41, formula: "CH3CN",  molarMass: 41.052),
    42: MoleculeInfo(molecId: 42, formula: "CF4",    molarMass: 88.004),
    43: MoleculeInfo(molecId: 43, formula: "C4H2",   molarMass: 50.060),
    44: MoleculeInfo(molecId: 44, formula: "HC3N",   molarMass: 51.048),
    45: MoleculeInfo(molecId: 45, formula: "H2",     molarMass:  2.016),
    46: MoleculeInfo(molecId: 46, formula: "CS",     molarMass: 44.076),
    47: MoleculeInfo(molecId: 47, formula: "SO3",    molarMass: 80.063),
    48: MoleculeInfo(molecId: 48, formula: "C2N2",   molarMass: 52.036),
    49: MoleculeInfo(molecId: 49, formula: "COCl2",  molarMass: 98.916),
    50: MoleculeInfo(molecId: 50, formula: "SO",     molarMass: 48.064),
    51: MoleculeInfo(molecId: 51, formula: "CH3F",   molarMass: 34.033),
    52: MoleculeInfo(molecId: 52, formula: "GeH4",   molarMass: 76.669),
    53: MoleculeInfo(molecId: 53, formula: "CS2",    molarMass: 76.139),
    54: MoleculeInfo(molecId: 54, formula: "CH3I",   molarMass: 141.940),
    55: MoleculeInfo(molecId: 55, formula: "NF3",    molarMass: 71.002),
    56: MoleculeInfo(molecId: 56, formula: "H3+",    molarMass:  3.024),
    57: MoleculeInfo(molecId: 57, formula: "CH3",    molarMass: 15.035),
    58: MoleculeInfo(molecId: 58, formula: "S2",     molarMass: 64.130),
    59: MoleculeInfo(molecId: 59, formula: "COFCl",  molarMass: 82.462),
    60: MoleculeInfo(molecId: 60, formula: "HONO",   molarMass: 47.013),
    61: MoleculeInfo(molecId: 61, formula: "ClNO2",  molarMass: 81.459),
]

struct DetectedMolecule {
    let molecId: Int
    let formula: String
    let lineCount: Int
    let pfStatus: String
}
