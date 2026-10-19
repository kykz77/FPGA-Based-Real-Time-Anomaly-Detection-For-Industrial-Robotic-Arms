`default_nettype none

module relu_layer # (
    parameter DATA_WIDTH    = 16,
    parameter INPUT_WIDTH   = 8
) (
    input wire [INPUT_WIDTH-1:0] [DATA_WIDTH-1:0]       in_data,
    output logic [INPUT_WIDTH-1:0] [DATA_WIDTH-1:0]     out_data
);
    generate
        for (genvar i = 0; i < INPUT_WIDTH; ++i)
        begin : gen_relu_units
            relu_unit # (
                .DATA_WIDTH     (DATA_WIDTH)
            ) relu_unit_I (
                .in_data        (in_data[i]),
                .out_data       (out_data[i])
            );
        end
    endgenerate

endmodule
