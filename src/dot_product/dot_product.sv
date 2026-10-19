`default_nettype none

module dot_product
    import binary_op_pkg::*;
# (
    parameter INPUT_WIDTH   = 18,
    parameter DATA_WIDTH    = 16,
    parameter USE_FLOAT     = 1
) (
    input wire                                          clk,
    input wire                                          res_n,
    input wire [INPUT_WIDTH-1:0] [DATA_WIDTH-1:0]       in_data_a,
    input wire [INPUT_WIDTH-1:0] [DATA_WIDTH-1:0]       in_data_b,
    output logic [DATA_WIDTH-1:0]                       out_data
);
    localparam NUM_DLY_STAGES   = 1;
    localparam DLY_DATA_WIDTH   = INPUT_WIDTH * DATA_WIDTH;

    logic [INPUT_WIDTH-1:0] [DATA_WIDTH-1:0]            products;
    logic [INPUT_WIDTH-1:0] [DATA_WIDTH-1:0]            products_dly;

    generate
        for (genvar i = 0; i < INPUT_WIDTH; ++i)
        begin : gen_multipliers 
            multiplier #(
                .DATA_WIDTH     (DATA_WIDTH),
                .USE_FLOAT      (USE_FLOAT)
            ) multiplier_I (
                .in_data_a      (in_data_a[i]),
                .in_data_b      (in_data_b[i]),
                .out_data       (products[i])
            );
        end
    endgenerate

    dly_stages # (
        .NUM_DLY_STAGES     (NUM_DLY_STAGES),
        .DATA_WIDTH         (DLY_DATA_WIDTH)
    ) dly_stages_I (
        .clk                (clk),
        .res_n              (res_n),
        .in_data            (products),
        .out_data           (products_dly)
    );

    binary_tree # (
        .OP_TYPE            (binary_op_pkg::ADD),
        .INPUT_WIDTH        (INPUT_WIDTH),
        .DATA_WIDTH         (DATA_WIDTH),
        .USE_FLOAT          (USE_FLOAT),
        .PIPELINE           (1)
    ) binary_tree_I (
        .clk                (clk),
        .res_n              (res_n),
        .in_data            (products_dly),
        .out_data           (out_data)
    );
endmodule
