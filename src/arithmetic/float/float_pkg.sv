`ifndef FLOAT_PKG_SV
`define FLOAT_PKG_SV

package float_pkg;

    localparam SIGN_WIDTH                       = 1;
    localparam EXPONENT_WIDTH                   = 5;
    localparam MANTISSA_WIDTH                   = 10;
    localparam NUM_BITS_CONTAINING_LEADING_ONE  = 2;
    localparam GRS_WIDTH                        = 0;

    /* verilator lint_off UNUSED */
    localparam FLOAT_WIDTH                      = SIGN_WIDTH + EXPONENT_WIDTH + MANTISSA_WIDTH;
    /* verilator lint_on  UNUSED */

    localparam SHIFT_AMOUNT_WIDTH               = EXPONENT_WIDTH;
    localparam EXPONENT_SUM_WIDTH               = EXPONENT_WIDTH + 1;

    /* verilator lint_off UNUSED */
    localparam EXPONENT_MAX                     = EXPONENT_SUM_WIDTH'(2**EXPONENT_WIDTH - 1);
    localparam EXPONENT_BIAS                    = EXPONENT_WIDTH'(2**(EXPONENT_WIDTH - 1) - 1);
    localparam EXPONENT_OVERFLOW_BOUND          = EXPONENT_SUM_WIDTH'(2**EXPONENT_WIDTH - 1 + EXPONENT_BIAS);
    localparam EXPONENT_UNDERFLOW_BOUND         = EXPONENT_SUM_WIDTH'(EXPONENT_BIAS);
    /* verilator lint_on  UNUSED */

    localparam FULL_MANTISSA_WIDTH              = MANTISSA_WIDTH + 1;
    localparam MANTISSA_GRS_WIDTH               = FULL_MANTISSA_WIDTH + GRS_WIDTH;
    localparam MANTISSA_SUM_WIDTH               = MANTISSA_GRS_WIDTH + 1;
    localparam MANTISSA_PRODUCT_WIDTH           = FULL_MANTISSA_WIDTH * 2;

    /* verilator lint_off UNUSED */
    localparam MANTISSA_PRODUCT_SLICE_INDEX     = (MANTISSA_PRODUCT_WIDTH - 1) - NUM_BITS_CONTAINING_LEADING_ONE;

    localparam FLOAT_ONE                        = 16'h3c00;
    /* verilator lint_on  UNUSED */

    typedef logic [EXPONENT_WIDTH-1:0]          exponent_t;
    typedef logic [EXPONENT_SUM_WIDTH-1:0]      exponent_sum_t;
    typedef logic [SIGN_WIDTH-1:0]              sign_t;
    typedef logic [MANTISSA_WIDTH-1:0]          mantissa_t;
    typedef logic [MANTISSA_GRS_WIDTH-1:0]      mantissa_grs_t;
    typedef logic [FULL_MANTISSA_WIDTH-1:0]     full_mantissa_t;
    typedef logic [MANTISSA_PRODUCT_WIDTH-1:0]  mantissa_product_t;
    typedef logic [MANTISSA_SUM_WIDTH-1:0]      mantissa_sum_t;
    typedef logic [SHIFT_AMOUNT_WIDTH-1:0]      shift_amount_t;

    typedef struct packed {
        sign_t       sign;
        exponent_t   exponent;
        mantissa_t   mantissa;
    } float_t;

    function automatic full_mantissa_t add_implicit_one(mantissa_t mantissa, exponent_t exponent);
        return (exponent == '0) ? {1'b0, mantissa} : {1'b1, mantissa};
    endfunction

    /* verilator lint_off UNUSED */
    function automatic logic is_nan(float_t in);
    /* verilator lint_on UNUSED */
        logic exponent_all_ones;
        logic mantissa_non_zero;
        logic float_is_nan;

        exponent_all_ones   = &in.exponent;
        mantissa_non_zero   = |in.mantissa;

        float_is_nan        = exponent_all_ones && mantissa_non_zero;

        return float_is_nan;
    endfunction

    /* verilator lint_off UNUSED */
    function automatic logic is_inf(float_t in);
    /* verilator lint_on UNUSED */
        logic exponent_all_ones;
        logic mantissa_all_zeros;
        logic float_is_inf;

        exponent_all_ones   = &in.exponent;
        mantissa_all_zeros  = (|in.mantissa == '0);

        float_is_inf        = exponent_all_ones && mantissa_all_zeros;

        return float_is_inf;
    endfunction

endpackage
`endif
