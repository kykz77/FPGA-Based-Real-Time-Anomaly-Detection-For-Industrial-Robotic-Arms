`default_nettype none

module binary_tree
    import binary_op_pkg::*;
# (
    parameter                       INPUT_WIDTH     = 10,
    parameter                       DATA_WIDTH      = 16,
    parameter                       USE_FLOAT       = 1,
    parameter                       PIPELINE        = 1,
    parameter binary_op_pkg::op_t   OP_TYPE         = binary_op_pkg::ADD
) (
    //verilator lint_off UNUSED
    input  wire                                             clk,
    input  wire                                             res_n,
    //verilator lint_on UNUSED
    input  wire  [INPUT_WIDTH-1:0] [DATA_WIDTH-1:0]         in_data,
    output logic [DATA_WIDTH-1:0]                           out_data
);
    generate
        if (INPUT_WIDTH == 1)
        begin : gen_base_case
            assign out_data = in_data[0];
        end
        else
        begin : gen_left_right
            localparam NUM_LEFT_ELEMENTS        = (1 << ($clog2(INPUT_WIDTH) - 1));
            localparam NUM_RIGHT_ELEMENTS       = INPUT_WIDTH - NUM_LEFT_ELEMENTS;

            localparam LEFT_SUBTREE_DEPTH       = $clog2(NUM_LEFT_ELEMENTS);
            localparam RIGHT_SUBTREE_DEPTH      = $clog2(NUM_RIGHT_ELEMENTS);
            localparam NUM_DLY_STAGES           = LEFT_SUBTREE_DEPTH - RIGHT_SUBTREE_DEPTH;
            
            logic [DATA_WIDTH-1:0]      out_data_c;
            logic [DATA_WIDTH-1:0]      out_left;
            logic [DATA_WIDTH-1:0]      out_right;
            logic [DATA_WIDTH-1:0]      out_right_unaligned;

            binary_tree # (
                .OP_TYPE        (OP_TYPE),
                .INPUT_WIDTH    (NUM_LEFT_ELEMENTS),
                .DATA_WIDTH     (DATA_WIDTH),
                .USE_FLOAT      (USE_FLOAT),
                .PIPELINE       (PIPELINE)
            ) left_binary_tree_I (
                .clk            (clk),
                .res_n          (res_n),
                .in_data        (in_data[INPUT_WIDTH-1 -: NUM_LEFT_ELEMENTS]),
                .out_data       (out_left)
            );

            binary_tree # (
                .OP_TYPE        (OP_TYPE),
                .INPUT_WIDTH    (NUM_RIGHT_ELEMENTS),
                .DATA_WIDTH     (DATA_WIDTH),
                .USE_FLOAT      (USE_FLOAT),
                .PIPELINE       (PIPELINE)
            ) right_binary_tree_I (
                .clk            (clk),
                .res_n          (res_n),
                .in_data        (in_data[NUM_RIGHT_ELEMENTS-1 : 0]),
                .out_data       (out_right_unaligned)
            );

            if ((NUM_DLY_STAGES == 0) || (PIPELINE == 0))
            begin : gen_no_dly
                assign out_right    = out_right_unaligned;
            end
            else
            begin : gen_dly
                dly_stages # (
                    .NUM_DLY_STAGES     (NUM_DLY_STAGES),
                    .DATA_WIDTH         (DATA_WIDTH)
                ) dly_stages_I (
                    .clk                (clk),
                    .res_n              (res_n),
                    .in_data            (out_right_unaligned),
                    .out_data           (out_right)
                );
            end

            binary_op # (
                .DATA_WIDTH     (DATA_WIDTH),
                .USE_FLOAT      (USE_FLOAT),
                .OP_TYPE        (OP_TYPE)
            ) binary_op_I (
                .in_data_a      (out_left),
                .in_data_b      (out_right),
                .out_data       (out_data_c)
            );

            if (PIPELINE)
            begin : gen_pipeline
                always_ff @(posedge clk)
                begin
                    if (!res_n)
                    begin
                        out_data     <= '0;
                    end
                    else
                    begin
                        out_data     <= out_data_c;
                    end
                end
            end
            else
            begin : gen_no_pipeline
                assign out_data     = out_data_c;
            end
        end
    endgenerate
endmodule
