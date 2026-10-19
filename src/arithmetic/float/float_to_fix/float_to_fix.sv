`default_nettype none

module float_to_fix 
    import float_pkg::*;
# (
    parameter FIX_WIDTH     = 28
) (
    /* verilator lint_off UNUSEDSIGNAL */
    input  float_pkg::float_t                           in_data,
    /* verilator lint_on UNUSEDSIGNAL */
    output logic                [FIX_WIDTH-1:0  ]       out_data
);
    float_pkg::full_mantissa_t  full_mantissa;

    //shift by (E-15) instead of (E-17) to undo the /4 overflow headroom in SCALE_FACTOR
    always_comb
    begin
        full_mantissa   = add_implicit_one(in_data.mantissa, in_data.exponent);

        if (in_data.exponent == '0)
        begin
            out_data    = '0;
        end
        else if (in_data.exponent >= EXPONENT_BIAS)
        begin
            out_data    = FIX_WIDTH'(full_mantissa) << (in_data.exponent - EXPONENT_BIAS);
        end
        else
        begin
            out_data    = FIX_WIDTH'(full_mantissa) >> (EXPONENT_BIAS - in_data.exponent);
        end
    end
endmodule
