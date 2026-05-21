# IR Absorption Visualizer

## This macOS version is an AI optimized app based on my original MATLAB UI App version. 
## You can modify this project to a CUDA/Vulcan/OpenCl-based version to run on Windows/Linux. Or just use AblineQuickCheck.mlapp despite of its poor performance.

A SwiftUI + Metal GPU-accelerated molecular absorption spectrum simulator for macOS, based on the HITRAN database. Computes Voigt line-by-line absorption spectra with interactive zoom/pan and real-time display.

## Features

- **GPU accelerated** — Metal compute shader with Humlíček Voigt lineshape (identical to MATLAB `Voigtf.m`)
- **Interactive zoom/pan** — trackpad drag to pan, pinch to zoom, toolbar controls for precise navigation
- **LTTB downsampling** — Largest Triangle Three Buckets algorithm for smooth display of up to 10M data points
- **Hold-on overlay** — compare multiple spectra (different T, P, X, L) on the same plot
- **Export** — File → Save figure data as... (CSV), full-resolution raw data always preserved
- **Built-in partition functions** — H₂O, N₂O, NO, NH₃, NO₂ auto-loaded from bundled data
- **Frequency unit conversion** — nm / cm⁻¹ / µm input and display
- **macOS 13+** — native SwiftUI interface



## Quick Start

### Prerequisites

- macOS 26.5
- Xcode 26 (for building from source)
- Python 3 + Pillow (`pip3 install Pillow`) — required only for app icon generation in the build script

### Build & Run

Using Xcode to build and run.

### Other versions

A macOS 12 compatible version is included. (xxx_macOS12)
A mobile adapted version is included. (xxx_MobileApp, tested on iPhone 16 Pro)

## Usage

### Step 1 — Load Data

1. Click **Import HITRAN data** and select a HITRAN-format CSV file
2. Select the **molecule** from the dropdown (H₂O, N₂O, NO, NH₃, NO₂ have built-in partition functions)
3. Set the **frequency range** (leave as 0,0 for full range) and select the input unit
4. Optionally load a custom partition function with **My PartFun data**

### Step 2 — Compute

1. Set gas conditions: **Temperature (K)**, **Pressure (atm)**, **Gas mole fraction**, **Optical length (cm)**
2. Choose display units for X and Y axes
3. Adjust **Resolution** slider (Rough → Smooth)
4. Toggle **Hold on** to overlay multiple runs
5. Toggle **GPU** for hardware acceleration (default on)
6. Click **Generate**

### Navigation

- **Zoom toolbar** (above plot): ← → pan, − ＋ zoom, ⟲ reset
- **Trackpad**: drag to pan, pinch to zoom
- **Legend**: appears below plot when multiple traces are overlaid


### GPU Compute Pipeline

The Metal shader assigns **one GPU thread per frequency point**. Each thread:

1. Binary-searches the sorted HITRAN line list for its sliding window (cutoff determined by pressure broadening)
2. Iterates over lines in the window, computing the Voigt profile contribution using the Humlíček algorithm directly in the shader
3. Accumulates the total optical depth τ(ν) locally (no atomic operations needed)
4. Outputs alpha to a `MTLBuffer`

### Display Pipeline

1. Raw data: up to 10M frequency points stored in `SimulationEngine`
2. Visible slice filtered using binary search (in cm⁻¹ space, accounting for nm/cm⁻¹ conversion)
3. Downsampled to 4000 points via LTTB
4. Transformed to display units (nm / cm⁻¹, α(ν) / Absorption%)
5. Rendered via Swift Charts (macOS 13+) or Core Graphics (macOS 12)


## Data Format

HITRAN CSV files should have at minimum these columns (case-sensitive):

```
local_iso_id,global_iso_id,molec_id,nu,sw,gamma_air,gamma_self,elower,n_air,delta_air,nu-err,sw-err,gamma_air-err,gamma_self-err,n_air-err,delta_air-err
```

The column order must match the standard HITRAN CSV export format. You can create this template on HITRAN with your HITRAN account.

## References

- HITRAN database: https://hitran.org
- partition function: https://hitran.iao.ru/partfun/index/mol/001: Top line of downloaded files needs to be removed. You should have files start with T,K line (no sharp))
