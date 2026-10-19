`ifndef BINARY_OP_PKG_SV
`define BINARY_OP_PKG_SV

package binary_op_pkg;

    typedef enum int {
        ADD = 0,
        MAX = 1,
        MUL = 2
    } op_t;

endpackage
`endif //BINARY_OP_PKG_SV
