`default_nettype none

module multiplier 
# (
    parameter DATA_WIDTH    = 16,
    parameter USE_FLOAT     = 1
) (
    input wire [DATA_WIDTH-1:0]     in_data_a,
    input wire [DATA_WIDTH-1:0]     in_data_b,
    output logic [DATA_WIDTH-1:0]   out_data
);
    generate
        if (USE_FLOAT)
        begin : gen_float_multiply
            float_multiplier float_multiplier_I (
                .in_data_a      (in_data_a),
                .in_data_b      (in_data_b),
                .out_data       (out_data)
            );
        end
        else
        begin : gen_int_multiply
            assign out_data     = in_data_a * in_data_b;
        end
    endgenerate
endmodule
