## Building

Requires Vivado 2024.1. Target part: xczu3eg-sfvc784-2-e

```
git clone https://github.com/kykz77/FPGA-Based-Real-Time-Anomaly-Detection-For-Industrial-Robotic-Arms.git
cd FPGA-Based-Real-Time-Anomaly-Detection-For-Industrial-Robotic-Arms
mkdir vivado && cd vivado
vivado -mode batch -source ../scripts/create_project.tcl -tclargs --origin_dir ../scripts
```

Then open `vivado/anomaly_detection/anomaly_detection.xpr` and run synthesis/implementation.