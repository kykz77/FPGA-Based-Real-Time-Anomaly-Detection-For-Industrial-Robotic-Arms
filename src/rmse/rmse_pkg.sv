`ifndef RMSE_PKG_SV
`define RMSE_PKG_SV

package rmse_pkg;
    localparam int RMSE_NUM_FEATURES = 9;
    localparam int RMSE_WINDOW       = 200;
    localparam int RMSE_FIX_WIDTH    = 28;

    // threshold 548.0 in Q.8 (x256)
    localparam logic [RMSE_FIX_WIDTH-1:0] RMSE_ANOMALY_THRES = 28'd140288;

    // std_f / 12: 1/9 of the mean (squared) and /4 headroom, undone in float_to_fix
    localparam logic [RMSE_NUM_FEATURES-1:0][15:0] RMSE_SCALE_FACTOR = {
        16'h413f, // [8] magZ   31.471417 / 12 -> 2.62305
        16'h3e6e, // [7] magY   19.290360 / 12 -> 1.60742
        16'h37ca, // [6] magX   5.843041 / 12 -> 0.486816
        16'h4066, // [5] gyroZ  26.384387 / 12 -> 2.19922
        16'h3964, // [4] gyroY  8.086132 / 12 -> 0.673828
        16'h40ac, // [3] gyroX  28.020045 / 12 -> 2.33594
        16'h2502, // [2] accZ   0.234757 / 12 -> 0.0195618
        16'h341c, // [1] accY   3.083146 / 12 -> 0.256836
        16'h300b  // [0] accX   1.516385 / 12 -> 0.126343
    };
endpackage

`endif
