`default_nettype none

module rmse
    import binary_op_pkg::*;
    import float_pkg::*;
# (
    parameter                           INPUT_WIDTH     = 1,
    parameter                           DATA_WIDTH      = 16,
    parameter                           WINDOW_WIDTH    = 265,
    parameter                           NUM_SUMS        = 9,
    parameter                           USE_FLOAT       = 1,
    parameter                           FIX_WIDTH       = 28,
    parameter string                    SQRT_MEM_FILE   = "",
    parameter logic [FIX_WIDTH-1:0]     ANOMALY_THRES   = 28'd196966,
    parameter logic [NUM_SUMS-1:0][DATA_WIDTH-1:0] SCALE_FACTOR = '0
) (
    input  wire                                         clk,
    input  wire                                         res_n,
    input  wire                                         in_valid,
    input  wire  [INPUT_WIDTH-1:0] [DATA_WIDTH-1:0]     in_data,
    input  wire  [INPUT_WIDTH-1:0] [DATA_WIDTH-1:0]     in_pred,
    output logic                                        out_valid,
    output logic                                        out_anomaly,
    output logic [FIX_WIDTH-1:0]                        out_data
);
    localparam NUM_DLY_STAGES   = 2;
    localparam COUNT_WIDTH      = $clog2(NUM_SUMS);
    localparam COUNT_MAX        = COUNT_WIDTH'(NUM_SUMS - 1);

    logic [INPUT_WIDTH-1:0] [DATA_WIDTH-1:0]        pred_neg;

    logic [INPUT_WIDTH-1:0] [DATA_WIDTH-1:0]        residual_c;
    logic [INPUT_WIDTH-1:0] [DATA_WIDTH-1:0]        residual_r;

    logic [INPUT_WIDTH-1:0] [DATA_WIDTH-1:0]        scale_c;

    /* verilator lint_off UNUSEDSIGNAL */
    logic [INPUT_WIDTH-1:0] [DATA_WIDTH-1:0]        scale_r;
    /* verilator lint_on UNUSEDSIGNAL */

    logic [INPUT_WIDTH-1:0] [DATA_WIDTH-1:0]        square_c;
    logic [INPUT_WIDTH-1:0] [DATA_WIDTH-1:0]        square_r;

    logic [DATA_WIDTH-1:0 ]                         sum_c;
    logic [DATA_WIDTH-1:0 ]                         sum_r;
    logic                                           sum_valid;
    logic                                           total_valid;
    logic                                           total_valid_dly;

    logic [DATA_WIDTH-1:0 ]                         sqrt_r;
    logic                                           sqrt_valid;

    logic [COUNT_WIDTH-1:0]                         count_r;
    logic [COUNT_WIDTH-1:0]                         count_c;

    generate
        for (genvar i = 0; i < INPUT_WIDTH; ++i)
        begin : gen_rmse
            adder # (
                .DATA_WIDTH     (DATA_WIDTH),
                .USE_FLOAT      (USE_FLOAT)
            ) residual_adder_I (
                .in_data_a      (in_data[i]),
                .in_data_b      (pred_neg[i]),
                .out_data       (residual_c[i])
            );

            multiplier # (
                .DATA_WIDTH     (DATA_WIDTH),
                .USE_FLOAT      (USE_FLOAT)
            ) scale_multiplier_I (
                .in_data_a      (residual_r[i]),
                .in_data_b      (SCALE_FACTOR[count_c]),
                .out_data       (scale_c[i])
            );

            multiplier # (
                .DATA_WIDTH     (DATA_WIDTH),
                .USE_FLOAT      (USE_FLOAT)
            ) square_multiplier_I (
                .in_data_a      (scale_c[i]),
                .in_data_b      (scale_c[i]),
                .out_data       (square_c[i])
            );
        
            assign pred_neg[i]     = {~in_pred[i][DATA_WIDTH-1], in_pred[i][DATA_WIDTH-2:0]};
        end
    endgenerate

    always_ff @(posedge clk)
    begin
        if (!res_n)
        begin
            count_r       <= '0;
        end
        else if (sum_valid)
        begin
            count_r       <= (count_r == COUNT_MAX) ? '0 : (count_r + 'd1);
        end
    end

    assign count_c      = (sum_valid) ? ((count_r == COUNT_MAX) ? '0 : (count_r + 'd1)) : count_r;
    assign total_valid  = (count_r == COUNT_MAX) && sum_valid;

    dly_stages # (
        .NUM_DLY_STAGES     (1),
        .DATA_WIDTH         (1)
    ) total_valid_dly_stages_I (
        .clk                (clk),
        .res_n              (res_n),
        .in_data            (total_valid),
        .out_data           (total_valid_dly)
    );

    dly_stages # (
        .NUM_DLY_STAGES     (NUM_DLY_STAGES),
        .DATA_WIDTH         (1)
    ) in_valid_dly_stages_I (
        .clk                (clk),
        .res_n              (res_n),
        .in_data            (in_valid),
        .out_data           (sum_valid)
    );

    adder # (
        .DATA_WIDTH (DATA_WIDTH),
        .USE_FLOAT  (USE_FLOAT)
    ) acc_adder_I (
        .in_data_a  (square_r[0]),
        .in_data_b  ((count_r == '0) ? '0 : sum_r),
        .out_data   (sum_c)
    );

    sqrt # (
        .DATA_WIDTH     (DATA_WIDTH),
        .USE_FLOAT      (USE_FLOAT),
        .MEM_FILE_PATH  (SQRT_MEM_FILE)
    ) sqrt_I (
        .clk            (clk),
        .res_n          (res_n),
        .in_valid       (total_valid_dly),
        .in_data        (sum_r),
        .out_valid      (sqrt_valid),
        .out_data       (sqrt_r)
    );

    logic [FIX_WIDTH-1:0]   sqrt_fix;

    generate
        if (USE_FLOAT == 1)
        begin : gen_float_to_fix
            float_to_fix # (
                .FIX_WIDTH  (FIX_WIDTH)
            ) float_to_fix_I (
                .in_data    (sqrt_r),
                .out_data   (sqrt_fix)
            );
        end
        else
        begin : gen_fix
            assign sqrt_fix     = FIX_WIDTH'(sqrt_r);
        end
    endgenerate

    rolling_sum # (
        .WINDOW_WIDTH   (WINDOW_WIDTH),
        .DATA_WIDTH     (FIX_WIDTH),
        .USE_FLOAT      (0)
    ) rolling_sum_I (
        .clk            (clk),
        .res_n          (res_n),
        .in_valid       (sqrt_valid),
        .in_data        (sqrt_fix),
        .out_valid      (out_valid),
        .out_data       (out_data)
    );

    always_ff @(posedge clk)
    begin
        if (!res_n)
        begin
            residual_r      <= '0;
            scale_r         <= '0;
            square_r        <= '0;
        end
        else
        begin
            residual_r      <= residual_c;
            scale_r         <= scale_c;
            square_r        <= square_c;
        end
    end

    always_ff @(posedge clk)
    begin
        if (!res_n)
        begin
            sum_r       <= '0;
        end
        else if (sum_valid)
        begin
            sum_r       <= sum_c;
        end
    end

    assign out_anomaly  = out_valid && (out_data > ANOMALY_THRES);
endmodule
