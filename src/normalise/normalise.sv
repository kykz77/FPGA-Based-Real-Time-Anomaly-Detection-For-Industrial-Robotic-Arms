`default_nettype none

module normalise
# (
    parameter                                               INPUT_WIDTH     = 1,
    parameter                                               DATA_WIDTH      = 16,
    parameter                                               USE_FLOAT       = 1,
    parameter                                               NUM_FEATURES    = 9,
    parameter logic [NUM_FEATURES-1:0] [DATA_WIDTH-1:0]     MEAN_NEG        = '0, 
    parameter logic [NUM_FEATURES-1:0] [DATA_WIDTH-1:0]     STD_DEV_R       = '0 
) (
    input  wire                                         clk,
    input  wire                                         res_n,
    input  wire                                         in_valid,
    input  wire  [INPUT_WIDTH-1:0] [DATA_WIDTH-1:0]     in_data,
    output logic                                        out_valid,
    output logic [INPUT_WIDTH-1:0] [DATA_WIDTH-1:0]     out_data
);
    localparam NUM_DLY_STAGES   = 2;
    localparam COUNT_WIDTH      = $clog2(NUM_FEATURES);
    localparam COUNT_MAX        = COUNT_WIDTH'(NUM_FEATURES - 1);

    logic [INPUT_WIDTH-1:0] [DATA_WIDTH-1:0]        mean_norm_r;
    logic [INPUT_WIDTH-1:0] [DATA_WIDTH-1:0]        mean_norm_c;
    logic [INPUT_WIDTH-1:0] [DATA_WIDTH-1:0]        norm_r;
    logic [INPUT_WIDTH-1:0] [DATA_WIDTH-1:0]        norm_c;

    logic [COUNT_WIDTH-1:0]                         feature;  
    logic [COUNT_WIDTH-1:0]                         feature_r;  

    always_ff @(posedge clk)
    begin
        if (!res_n)
        begin
            feature     <= '0;
        end
        else if (in_valid)
        begin
            feature     <= (feature == COUNT_MAX) ? '0 : (feature + 1'b1);
        end
        
        feature_r       <= feature;
    end

    generate
        for (genvar i = 0; i < INPUT_WIDTH; ++i)
        begin : gen_norm
            adder # (
                .DATA_WIDTH     (DATA_WIDTH),
                .USE_FLOAT      (USE_FLOAT)
            ) adder_I (
                .in_data_a      (in_data[i]),
                .in_data_b      (MEAN_NEG[feature]),
                .out_data       (mean_norm_c[i])
            );

            multiplier # (
                .DATA_WIDTH     (DATA_WIDTH),
                .USE_FLOAT      (USE_FLOAT)
            ) multiplier_I (
                .in_data_a      (mean_norm_r[i]),
                .in_data_b      (STD_DEV_R[feature_r]),
                .out_data       (norm_c[i])
            );
        end
    endgenerate

    dly_stages # (
        .NUM_DLY_STAGES     (NUM_DLY_STAGES),
        .DATA_WIDTH         (1)
    ) dly_stages_I (
        .clk                (clk),
        .res_n              (res_n),
        .in_data            (in_valid),
        .out_data           (out_valid)
    );

    always_ff @(posedge clk)
    begin
        if (!res_n)
        begin
            mean_norm_r     <= '0;
            norm_r          <= '0;
        end
        else
        begin
            mean_norm_r     <= mean_norm_c;
            norm_r          <= norm_c; 
        end
    end

    assign out_data     = norm_r;
endmodule
