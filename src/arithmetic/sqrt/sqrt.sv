`default_nettype none

module sqrt
# (
    parameter           DATA_WIDTH      = 16,
    parameter           USE_FLOAT       = 1,
    parameter string    MEM_FILE_PATH   = ""
) (
    input  wire                     clk,
    input  wire                     res_n,
    input  wire                     in_valid,
    input  wire  [DATA_WIDTH-1:0]   in_data,
    output logic                    out_valid,
    output logic [DATA_WIDTH-1:0]   out_data
);
    generate
        if (USE_FLOAT)
        begin : gen_float_sqrt
            float_sqrt # (
                .MEM_FILE_PATH  (MEM_FILE_PATH)
            ) float_sqrt_I (
                .clk            (clk),
                .res_n          (res_n),
                .in_valid       (in_valid),
                .in_data        (in_data),
                .out_valid      (out_valid),
                .out_data       (out_data)
            );
        end
        else
        begin : gen_int_sqrt
            assign out_data     = '0; 
        end
    endgenerate

endmodule
