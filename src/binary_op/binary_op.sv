module binary_op
    import binary_op_pkg::*;
# (
    /* verilator lint_off UNUSEDPARAM */
    parameter       DATA_WIDTH      = 16,
    parameter       USE_FLOAT       = 1,
    parameter op_t  OP_TYPE         = binary_op_pkg::ADD
    /* verilator lint_on UNUSEDPARAM */
) (
    /* verilator lint_off UNUSEDSIGNAL */
    input  wire  [DATA_WIDTH-1:0]       in_data_a,
    input  wire  [DATA_WIDTH-1:0]       in_data_b,
    /* verilator lint_on UNUSEDSIGNAL */
    output logic [DATA_WIDTH-1:0]       out_data
);
    generate
        case (OP_TYPE)
            binary_op_pkg::ADD:
            begin : gen_add
                adder # (
                    .DATA_WIDTH     (DATA_WIDTH),
                    .USE_FLOAT      (USE_FLOAT)
                ) adder_I (
                    .in_data_a      (in_data_a),
                    .in_data_b      (in_data_b),
                    .out_data       (out_data)
                );
            end
            binary_op_pkg::MAX:
            begin : gen_max
                max # (
                    .DATA_WIDTH     (DATA_WIDTH),
                    .USE_FLOAT      (USE_FLOAT)
                ) max_I (
                    .in_data_a      (in_data_a),
                    .in_data_b      (in_data_b),
                    .out_data       (out_data)
                );
            end
            binary_op_pkg::MUL:
            begin : gen_mul
                multiplier # (
                    .DATA_WIDTH     (DATA_WIDTH),
                    .USE_FLOAT      (USE_FLOAT)
                ) multiplier (
                    .in_data_a      (in_data_a),
                    .in_data_b      (in_data_b),
                    .out_data       (out_data)
                );
            end
            default:
            begin : gen_none
                assign out_data     = '0;
            end
        endcase
    endgenerate
endmodule
