`ifndef NORMALISE_PKG_SV
`define NORMALISE_PKG_SV

package normalise_pkg;
    localparam int NORM_NUM_FEATURES = 9;

    // normalise: (x + NORM_MEAN_NEG[f]) * NORM_STD_R[f] = (x - mean_f) / std_f
    localparam logic [NORM_NUM_FEATURES-1:0][15:0] NORM_MEAN_NEG = {
        16'h4104, // [8] magZ   2.507686 -> 2.50781
        16'hcce7, // [7] magY   -19.604400 -> -19.6094
        16'h502b, // [6] magX   33.357149 -> 33.3438
        16'ha1f2, // [5] gyroZ  -0.011609 -> -0.0116119
        16'hb954, // [4] gyroY  -0.666154 -> -0.666016
        16'hb584, // [3] gyroX  -0.344744 -> -0.344727
        16'hb7cd, // [2] accZ   -0.487440 -> -0.487549
        16'h3976, // [1] accY   0.682526 -> 0.682617
        16'hc89e  // [0] accX   -9.235880 -> -9.23438
    };

    localparam logic [NORM_NUM_FEATURES-1:0][15:0] NORM_STD_R = {
        16'h2811, // [8] magZ   1 / 31.471417 -> 0.0317688
        16'h2aa3, // [7] magY   1 / 19.290360 -> 0.0518494
        16'h317a, // [6] magX   1 / 5.843041 -> 0.171143
        16'h28da, // [5] gyroZ  1 / 26.384387 -> 0.0379028
        16'h2fea, // [4] gyroY  1 / 8.086132 -> 0.123657
        16'h2891, // [3] gyroX  1 / 28.020045 -> 0.035675
        16'h4442, // [2] accZ   1 / 0.234757 -> 4.25781
        16'h3531, // [1] accY   1 / 3.083146 -> 0.324463
        16'h3947  // [0] accX   1 / 1.516385 -> 0.659668
    };
endpackage

`endif
