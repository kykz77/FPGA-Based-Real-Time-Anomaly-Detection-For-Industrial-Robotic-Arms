`default_nettype none

/* NOTE: This file was generated using AI */

// connect a layer's client interface to a bank's client interface
`define DP_CONNECT(LAYER_IF, BANK_IF)                       \
    assign BANK_IF.dp_req           = LAYER_IF.dp_req;      \
    assign BANK_IF.dp_window        = LAYER_IF.dp_window;   \
    assign BANK_IF.dp_kernel        = LAYER_IF.dp_kernel;   \
    assign LAYER_IF.dp_grant        = BANK_IF.dp_grant;     \
    assign LAYER_IF.dp_res_valid    = BANK_IF.dp_res_valid; \
    assign LAYER_IF.dp_res          = BANK_IF.dp_res;

// every interface is sized to the largest bank
`define DP_IF_PARAMS #(.SETTINGS(DP_IF_MAX))

module cnn
    import cnn_config_pkg::*;
    import conv_1_pkg::*;
    import conv_2_pkg::*;
    import dense_pkg::*;
# (
    parameter INPUT_WIDTH   = CONV1_INPUT_WIDTH,
    /* verilator lint_off VARHIDDEN */
    parameter DATA_WIDTH    = cnn_config_pkg::DATA_WIDTH,
    /* verilator lint_on VARHIDDEN */
    parameter OUTPUT_WIDTH  = NUM_CLASSES
) (
    input  wire                                         clk,
    input  wire                                         res_n,
    input  wire                                         in_valid,
    input  wire  [INPUT_WIDTH-1:0 ] [DATA_WIDTH-1:0]    in_data,
    output logic                                        out_valid,
    output logic [OUTPUT_WIDTH-1:0] [DATA_WIDTH-1:0]    out_data,
    output logic [CONV_CHANNELS-1:0] [DATA_WIDTH-1:0]   out_conv1,
    output logic [CONV_CHANNELS-1:0] [DATA_WIDTH-1:0]   out_conv2,
    output logic                                        out_conv1_valid,
    output logic                                        out_conv2_valid
);
    // ================================================================== interfaces
    // layer side
    dot_product_if `DP_IF_PARAMS conv1_dp_if [2] ();
    dot_product_if `DP_IF_PARAMS conv2_dp_if [2] ();
    dot_product_if `DP_IF_PARAMS dense_dp_if [5] ();

    // bank side, in priority order (index 0 = highest)
    dot_product_if `DP_IF_PARAMS bank_8x1_if  [1] ();   // CL1 top
    dot_product_if `DP_IF_PARAMS bank_2x19_if [2] ();   // CL1 bottom, dense 0
    dot_product_if `DP_IF_PARAMS bank_2x17_if [2] ();   // CL2 bottom, dense 1
    dot_product_if `DP_IF_PARAMS bank_9x8_if  [3] ();   // CL2 top, dense 4 (last), dense 2
    dot_product_if `DP_IF_PARAMS bank_1x8_if  [1] ();   // dense 3

    `DP_CONNECT(conv1_dp_if[0], bank_8x1_if[0])

    `DP_CONNECT(conv1_dp_if[1], bank_2x19_if[0])
    `DP_CONNECT(dense_dp_if[0], bank_2x19_if[1])

    `DP_CONNECT(conv2_dp_if[1], bank_2x17_if[0])
    `DP_CONNECT(dense_dp_if[1], bank_2x17_if[1])

    `DP_CONNECT(conv2_dp_if[0], bank_9x8_if[0])
    `DP_CONNECT(dense_dp_if[4], bank_9x8_if[1])
    `DP_CONNECT(dense_dp_if[2], bank_9x8_if[2])

    `DP_CONNECT(dense_dp_if[3], bank_1x8_if[0])

    // ================================================================== banks
    dot_product_bank # (.NUM_CLIENTS(1), .SETTINGS(BANK_8X1))  bank_8x1_I  (.clk(clk), .res_n(res_n), .dp_if(bank_8x1_if));
    dot_product_bank # (.NUM_CLIENTS(2), .SETTINGS(BANK_2X19)) bank_2x19_I (.clk(clk), .res_n(res_n), .dp_if(bank_2x19_if));
    dot_product_bank # (.NUM_CLIENTS(2), .SETTINGS(BANK_2X17)) bank_2x17_I (.clk(clk), .res_n(res_n), .dp_if(bank_2x17_if));
    dot_product_bank # (.NUM_CLIENTS(3), .SETTINGS(BANK_9X8))  bank_9x8_I  (.clk(clk), .res_n(res_n), .dp_if(bank_9x8_if));
    dot_product_bank # (.NUM_CLIENTS(1), .SETTINGS(BANK_1X8))  bank_1x8_I  (.clk(clk), .res_n(res_n), .dp_if(bank_1x8_if));

    // ================================================================== CL1 -> ReLU
    logic                                           conv1_valid;
    logic [CONV_CHANNELS-1:0] [DATA_WIDTH-1:0]      conv1_data;
    logic [CONV_CHANNELS-1:0] [DATA_WIDTH-1:0]      relu1_data;

    conv_layer # (
        .KERNEL_WIDTH       (CONV1_K_WIDTH),
        .KERNEL_HEIGHT      (CONV1_K_HEIGHT),
        .IMAGE_WIDTH        (CONV1_IMAGE_WIDTH),
        .INPUT_WIDTH        (INPUT_WIDTH),
        .NUM_CLIENTS        (2),
        .DATA_WIDTH         (DATA_WIDTH),
        .OUTPUT_WIDTH       (CONV_CHANNELS),
        .USE_FLOAT          (USE_FLOAT),
        .DP_SETTINGS        (CONV1_DP)
    ) conv1_I (
        .clk                (clk),
        .res_n              (res_n),
        .in_valid           (in_valid),
        .in_data            (in_data),
        .in_kernel          (CONV_1_KERNEL),
        .in_bias            (CONV_1_BIAS),
        .out_valid          (conv1_valid),
        .out_data           (conv1_data),
        .dp_if              (conv1_dp_if)
    );

    relu_layer # (
        .DATA_WIDTH         (DATA_WIDTH),
        .INPUT_WIDTH        (CONV_CHANNELS)
    ) relu1_I (
        .in_data            (conv1_data),
        .out_data           (relu1_data)
    );

    // ================================================================== CL2 -> ReLU
    logic                                           conv2_valid;
    logic [CONV_CHANNELS-1:0] [DATA_WIDTH-1:0]      conv2_data;
    logic [CONV_CHANNELS-1:0] [DATA_WIDTH-1:0]      relu2_data;

    conv_layer # (
        .KERNEL_WIDTH       (CONV2_K_WIDTH),
        .KERNEL_HEIGHT      (CONV2_K_HEIGHT),
        .IMAGE_WIDTH        (CONV2_IMAGE_WIDTH),
        .INPUT_WIDTH        (CONV2_INPUT_WIDTH),
        .NUM_CLIENTS        (2),
        .DATA_WIDTH         (DATA_WIDTH),
        .OUTPUT_WIDTH       (CONV_CHANNELS),
        .USE_FLOAT          (USE_FLOAT),
        .DP_SETTINGS        (CONV2_DP)
    ) conv2_I (
        .clk                (clk),
        .res_n              (res_n),
        .in_valid           (conv1_valid),
        .in_data            (relu1_data),
        .in_kernel          (CONV_2_KERNEL),
        .in_bias            (CONV_2_BIAS),
        .out_valid          (conv2_valid),
        .out_data           (conv2_data),
        .dp_if              (conv2_dp_if)
    );

    relu_layer # (
        .DATA_WIDTH         (DATA_WIDTH),
        .INPUT_WIDTH        (CONV_CHANNELS)
    ) relu2_I (
        .in_data            (conv2_data),
        .out_data           (relu2_data)
    );

    // ================================================================== max pooling
    logic                                                       pool_valid;
    logic                                                       pool_buffer_valid;
    logic [CONV_CHANNELS-1:0] [DATA_WIDTH-1:0]                  pool_data;
    logic [CONV_CHANNELS-1:0] [POOL_COUNT-2:0] [DATA_WIDTH-1:0] pool_buffer;

    max_pooling_layer # (
        .INPUT_WIDTH        (CONV_CHANNELS),
        .OUTPUT_WIDTH       (CONV_CHANNELS),
        .POOL_WIDTH         (POOL_WIDTH),
        .POOL_COUNT         (POOL_COUNT),
        .DATA_WIDTH         (DATA_WIDTH)
    ) max_pooling_I (
        .clk                (clk),
        .res_n              (res_n),
        .in_valid           (conv2_valid),
        .in_data            (relu2_data),
        .out_valid          (pool_valid),
        .out_buffer_valid   (pool_buffer_valid),
        .out_data           (pool_data),
        .out_buffer         (pool_buffer)
    );

    // ================================================================== dense
    dense_layer # (
        .INPUT_WIDTH        (CONV_CHANNELS),
        .BUFFER_WIDTH       (POOL_COUNT - 1),
        .OUTPUT_WIDTH       (OUTPUT_WIDTH),
        .DATA_WIDTH         (DATA_WIDTH),
        .NUM_CLIENTS        (5),
        .USE_FLOAT          (USE_FLOAT),
        .DP_SETTINGS        (DENSE_DP)
    ) dense_I (
        .clk                (clk),
        .res_n              (res_n),
        .in_valid           (pool_valid),
        .in_buffer_valid    (pool_buffer_valid),
        .in_data            (pool_data),
        .in_buffer          (pool_buffer),
        .in_bias            (DENSE_BIAS),
        .in_kernel          (DENSE_KERNEL),
        .out_valid          (out_valid),
        .out_data           (out_data),
        .dp_if              (dense_dp_if)
    );

    assign out_conv1       = conv1_data;
    assign out_conv1_valid = conv1_valid;
    assign out_conv2       = conv2_data;
    assign out_conv2_valid = conv2_valid;

endmodule

`undef DP_IF_PARAMS
`undef DP_CONNECT
