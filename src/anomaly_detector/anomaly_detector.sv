`default_nettype none

/* NOTE: This file was generated using AI */

module anomaly_detector
    import cnn_config_pkg::*;
    import normalise_pkg::*;
    import rmse_pkg::*;
# (
    parameter string SQRT_MEM_FILE  = "src/mem_files/sqrt_table.mem",
    parameter int    PRED_DEPTH     = 4
) (
    input  wire                                         clk,
    input  wire                                         res_n,
    input  wire                                         in_valid,
    input  wire  [DATA_WIDTH-1:0]                       in_data, 

    output logic                                        pred_valid,
    output logic [NUM_CLASSES-1:0] [DATA_WIDTH-1:0]     pred_data, //normalised

    output logic                                        out_valid,
    output logic                                        out_anomaly,
    output logic [RMSE_FIX_WIDTH-1:0]                   out_data 
);
    localparam WINDOW               = 45;
    localparam ROW_WIDTH            = $clog2(WINDOW + 1);
    localparam FEAT_WIDTH           = $clog2(NUM_FEATURES);
    localparam PTR_WIDTH            = $clog2(PRED_DEPTH);
    localparam NORM_INPUT_WIDTH     = 1;
    localparam RMSE_INPUT_WIDTH     = 1;
    
    logic [NORM_INPUT_WIDTH-1:0] [DATA_WIDTH-1:0]               norm_data;
    logic                                                       norm_valid;

    normalise # (
        .INPUT_WIDTH        (NORM_INPUT_WIDTH),
        .DATA_WIDTH         (DATA_WIDTH),
        .NUM_FEATURES       (NORM_NUM_FEATURES),
        .MEAN_NEG           (NORM_MEAN_NEG),
        .STD_DEV_R          (NORM_STD_R)
    ) normalise_I (
        .clk                (clk),
        .res_n              (res_n),
        .in_valid           (in_valid),
        .in_data            (in_data),
        .out_valid          (norm_valid),
        .out_data           (norm_data)
    );

    /* verilator lint_off UNUSEDSIGNAL */
    logic                                       conv1_valid, conv2_valid;
    logic [CONV_CHANNELS-1:0] [DATA_WIDTH-1:0]  conv1_data, conv2_data;
    /* verilator lint_on UNUSEDSIGNAL */

    cnn cnn_I (
        .clk                (clk),
        .res_n              (res_n),
        .in_valid           (norm_valid),
        .in_data            (norm_data),
        .out_valid          (pred_valid),
        .out_data           (pred_data),
        .out_conv1          (conv1_data),
        .out_conv1_valid    (conv1_valid),
        .out_conv2          (conv2_data),
        .out_conv2_valid    (conv2_valid)
    );

    logic [NUM_CLASSES-1:0] [DATA_WIDTH-1:0]    pred_mem [PRED_DEPTH];
    logic [PTR_WIDTH-1:0]                       wr_ptr, rd_ptr;
    logic [FEAT_WIDTH-1:0]                      feature;
    logic [ROW_WIDTH-1:0]                       rows_seen;
    logic                                       rmse_valid;
    logic                                       row_done;

    assign row_done     = norm_valid && (feature == FEAT_WIDTH'(NUM_FEATURES - 1));
    assign rmse_valid   = norm_valid && (rows_seen == ROW_WIDTH'(WINDOW));

    always_ff @(posedge clk)
    begin
        if (!res_n)
        begin
            feature     <= '0;
            rows_seen   <= '0;
            wr_ptr      <= '0;
            rd_ptr      <= '0;
        end
        else
        begin
            if (norm_valid)
                feature     <= row_done ? '0 : (feature + 1'b1);

            if (row_done && (rows_seen != ROW_WIDTH'(WINDOW)))
                rows_seen   <= rows_seen + 1'b1;

            if (pred_valid)
                wr_ptr      <= wr_ptr + 1'b1;

            if (rmse_valid && row_done)
                rd_ptr      <= rd_ptr + 1'b1;
        end

        if (pred_valid)
            pred_mem[wr_ptr]    <= pred_data;
    end

    // ------------------------------------------------------------------ rmse
    logic [RMSE_INPUT_WIDTH-1:0] [DATA_WIDTH-1:0]                rmse_pred;

    assign rmse_pred[0] = pred_mem[rd_ptr][feature];

    rmse # (
        .INPUT_WIDTH        (RMSE_INPUT_WIDTH),
        .DATA_WIDTH         (DATA_WIDTH),
        .WINDOW_WIDTH       (RMSE_WINDOW),
        .NUM_SUMS           (RMSE_NUM_FEATURES),
        .USE_FLOAT          (1),
        .FIX_WIDTH          (RMSE_FIX_WIDTH),
        .ANOMALY_THRES      (RMSE_ANOMALY_THRES),
        .SCALE_FACTOR       (RMSE_SCALE_FACTOR),
        .SQRT_MEM_FILE      (SQRT_MEM_FILE)
    ) rmse_I (
        .clk                (clk),
        .res_n              (res_n),
        .in_valid           (rmse_valid),
        .in_data            (norm_data),
        .in_pred            (rmse_pred),
        .out_valid          (out_valid),
        .out_anomaly        (out_anomaly),
        .out_data           (out_data)
    );
endmodule
