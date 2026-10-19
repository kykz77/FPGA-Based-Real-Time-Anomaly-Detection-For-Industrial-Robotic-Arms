`ifndef CNN_CONFIG_PKG_SV
`define CNN_CONFIG_PKG_SV

package cnn_config_pkg;
    import dot_product_pkg::*;

    // ------------------------------------------------------------------ network (paper, Table 3)
    localparam DATA_WIDTH           = 16;       // float16
    localparam USE_FLOAT            = 1;

    localparam NUM_FEATURES         = 9;        // IMU features, streamed one float per cycle
    localparam CONV_CHANNELS        = 8;        // filters in CL1 and CL2
    localparam NUM_CLASSES          = 9;        // dense outputs (9 predictions)

    // CL1: 3 x 9 filters over rows of 9 features
    localparam CONV1_IMAGE_WIDTH    = NUM_FEATURES;
    localparam CONV1_K_WIDTH        = 9;
    localparam CONV1_K_HEIGHT       = 3;
    localparam CONV1_INPUT_WIDTH    = 1;        // one value per in_valid

    // CL2: 3 x 8 filters over rows of 8 channels (a whole row arrives per in_valid)
    localparam CONV2_IMAGE_WIDTH    = CONV_CHANNELS;
    localparam CONV2_K_WIDTH        = 8;
    localparam CONV2_K_HEIGHT       = 3;
    localparam CONV2_INPUT_WIDTH    = CONV_CHANNELS;

    // max pooling: 13 windows of 3 per channel -> dense input 8 x 13 = 104
    localparam POOL_WIDTH           = 3;
    localparam POOL_COUNT           = 13;

    // ------------------------------------------------------------------ banks
    // rows x values per row (incl. bias slot). Every dot_product_if is sized to the
    // largest bank so that one interface type works for every client.
    localparam DP_MAX_ROWS          = 9;
    localparam DP_MAX_ROW_WIDTH     = 19;

    localparam dot_product_pkg::dp_settings_t BANK_8X1  = '{BANK_WIDTH: 8, INPUT_WIDTH: 1,  DATA_WIDTH: DATA_WIDTH, USE_FLOAT: USE_FLOAT, default: 0};
    localparam dot_product_pkg::dp_settings_t BANK_2X19 = '{BANK_WIDTH: 2, INPUT_WIDTH: 19, DATA_WIDTH: DATA_WIDTH, USE_FLOAT: USE_FLOAT, default: 0};
    localparam dot_product_pkg::dp_settings_t BANK_2X17 = '{BANK_WIDTH: 2, INPUT_WIDTH: 17, DATA_WIDTH: DATA_WIDTH, USE_FLOAT: USE_FLOAT, default: 0};
    localparam dot_product_pkg::dp_settings_t BANK_9X8  = '{BANK_WIDTH: 9, INPUT_WIDTH: 8,  DATA_WIDTH: DATA_WIDTH, USE_FLOAT: USE_FLOAT, default: 0};
    localparam dot_product_pkg::dp_settings_t BANK_1X8  = '{BANK_WIDTH: 1, INPUT_WIDTH: 8,  DATA_WIDTH: DATA_WIDTH, USE_FLOAT: USE_FLOAT, default: 0};

    // size of every dot_product_if (largest bank)
    localparam dot_product_pkg::dp_settings_t DP_IF_MAX = '{BANK_WIDTH: DP_MAX_ROWS, INPUT_WIDTH: DP_MAX_ROW_WIDTH,
                                           DATA_WIDTH: DATA_WIDTH, USE_FLOAT: USE_FLOAT, default: 0};

    // ------------------------------------------------------------------ CL1 clients
    // kernel order per channel: [0..8] = newest row (feature order), [9..26] = 2 buffered rows
    localparam dot_product_pkg::dp_settings_arr_t CONV1_DP = '{
        // top: newest row, 8x1 bank, one feature per sweep, 9 sweeps
        0: '{BANK_WIDTH: 32'd8, INPUT_WIDTH: 32'd1,  CYCLES_PER_CHANNEL: 32'd9, PARALLEL: 32'd1, STREAM: 32'd1, USE_BIAS: 32'd0,
             OUTPUT_WIDTH: CONV_CHANNELS, DATA_WIDTH: DATA_WIDTH, USE_FLOAT: USE_FLOAT, default: 0},
        // bottom: 2 buffered rows, 2x19 bank, 2 channels per cycle -> 4 cycles, 18 values + bias
        1: '{BANK_WIDTH: 32'd2, INPUT_WIDTH: 32'd18, CYCLES_PER_CHANNEL: 32'd1, PARALLEL: 32'd1, STREAM: 32'd0, USE_BIAS: 32'd1,
             OUTPUT_WIDTH: CONV_CHANNELS, DATA_WIDTH: DATA_WIDTH, USE_FLOAT: USE_FLOAT, default: 0},
        default: '0
    };

    // ------------------------------------------------------------------ CL2 clients
    // kernel order per channel: [0..7] = newest row (8 channels), [8..23] = 2 buffered rows
    localparam dot_product_pkg::dp_settings_arr_t CONV2_DP = '{
        // top: newest row, 8 of the 9x8 bank's rows, all 8 channels in one cycle
        0: '{BANK_WIDTH: 32'd8, INPUT_WIDTH: 32'd8,  CYCLES_PER_CHANNEL: 32'd1, PARALLEL: 32'd1, STREAM: 32'd1, USE_BIAS: 32'd0,
             OUTPUT_WIDTH: CONV_CHANNELS, DATA_WIDTH: DATA_WIDTH, USE_FLOAT: USE_FLOAT, default: 0},
        // bottom: 2 buffered rows, 2x17 bank, 2 channels per cycle -> 4 cycles, 16 values + bias
        1: '{BANK_WIDTH: 32'd2, INPUT_WIDTH: 32'd16, CYCLES_PER_CHANNEL: 32'd1, PARALLEL: 32'd1, STREAM: 32'd0, USE_BIAS: 32'd1,
             OUTPUT_WIDTH: CONV_CHANNELS, DATA_WIDTH: DATA_WIDTH, USE_FLOAT: USE_FLOAT, default: 0},
        default: '0
    };

    // ------------------------------------------------------------------ dense clients
    // Order = summation order. Inputs are position-major (index = j*8 + c).
    // Per output channel: 9x8 regular 0..55, 1x8 56..63, 2x19 / 2x17 64..95, last 96..103.
    // Bias is added in the dense sum, so USE_BIAS = 0 everywhere.
    localparam dot_product_pkg::dp_settings_arr_t DENSE_DP = '{
        // 0: 2x19 bank, D0-D3, one channel per cycle, 2 rows x 16 = 32 values
        0: '{BANK_WIDTH: 2, INPUT_WIDTH: 16, CYCLES_PER_CHANNEL: 1, PARALLEL: 0,
             START: 0, OUTPUT_WIDTH: 4, KERNEL_START: 64,
             DATA_WIDTH: DATA_WIDTH, USE_FLOAT: USE_FLOAT, default: 0},
        // 1: 2x17 bank, D4-D8, one channel per cycle, 2 rows x 16 = 32 values
        1: '{BANK_WIDTH: 2, INPUT_WIDTH: 16, CYCLES_PER_CHANNEL: 1, PARALLEL: 0,
             START: 4, OUTPUT_WIDTH: 5, KERNEL_START: 64,
             DATA_WIDTH: DATA_WIDTH, USE_FLOAT: USE_FLOAT, default: 0},
        // 2: 9x8 bank, all channels in parallel, 7 sweeps of 8 = 56 values
        2: '{BANK_WIDTH: 9, INPUT_WIDTH: 8, CYCLES_PER_CHANNEL: 7, PARALLEL: 1,
             START: 0, OUTPUT_WIDTH: NUM_CLASSES, KERNEL_START: 0,
             DATA_WIDTH: DATA_WIDTH, USE_FLOAT: USE_FLOAT, default: 0},
        // 3: 1x8 bank, one channel per cycle (9 cycles), 8 values
        3: '{BANK_WIDTH: 1, INPUT_WIDTH: 8, CYCLES_PER_CHANNEL: 1, PARALLEL: 0,
             START: 0, OUTPUT_WIDTH: NUM_CLASSES, KERNEL_START: 56,
             DATA_WIDTH: DATA_WIDTH, USE_FLOAT: USE_FLOAT, default: 0},
        // 4: 9x8 bank, last sample: 8 values -> 96..103
        4: '{BANK_WIDTH: 9, INPUT_WIDTH: 8, CYCLES_PER_CHANNEL: 1, PARALLEL: 1,
             STREAM:1, START: 0, OUTPUT_WIDTH: NUM_CLASSES, KERNEL_START: 96,
             DATA_WIDTH: DATA_WIDTH, USE_FLOAT: USE_FLOAT, default: 0},
        default: '0
    };
endpackage
`endif
