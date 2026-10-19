`default_nettype none

module float_multiplier
    import float_pkg::*;
(
    input float_pkg::float_t            in_data_a,
    input float_pkg::float_t            in_data_b,
    output float_pkg::float_t           out_data
);
    float_pkg::exponent_sum_t           exponent_sum;               
    float_pkg::exponent_sum_t           exponent_raw;
    float_pkg::exponent_t               exponent_out;

    float_pkg::full_mantissa_t          mantissa_a;
    float_pkg::full_mantissa_t          mantissa_b;

    float_pkg::mantissa_t               mantissa_out;

    float_pkg::mantissa_product_t       product_raw;

    /* verilator lint_off UNUSED */
    float_pkg::mantissa_product_t       product_norm;
    /* verilator lint_on  UNUSED */
    
    float_pkg::sign_t                   sign_out;

    logic                               overflow_detected;
    logic                               underflow_detected;
    logic                               product_greater_than_two;
    logic                               product_is_nan;
    logic                               product_is_inf;
    logic                               product_is_zero;

    always_comb
    begin
        product_is_nan              = (is_nan(in_data_a) || is_nan(in_data_b)) 
                                    || ((in_data_a == '0) && is_inf(in_data_b)) 
                                    || (is_inf(in_data_a) && (in_data_b == '0));

        sign_out                    = in_data_a.sign ^ in_data_b.sign;

        exponent_sum                = in_data_a.exponent + in_data_b.exponent;

        exponent_raw                = exponent_sum - EXPONENT_BIAS;

        overflow_detected           = (exponent_sum >= EXPONENT_OVERFLOW_BOUND);
        underflow_detected          = (exponent_sum < EXPONENT_UNDERFLOW_BOUND);

        product_is_inf              = (is_inf(in_data_a) || is_inf(in_data_b));
        product_is_zero             = underflow_detected || (in_data_a == '0) || (in_data_b == '0);

        mantissa_a                  = '0;
        mantissa_b                  = '0;
        product_raw                 = '0;
        product_greater_than_two    = '0;
        product_norm                = '0;

        if (product_is_nan)
        begin
            sign_out                = '0;
            exponent_out            = '1;
            mantissa_out            = 'b1;
        end
        else if (product_is_inf)
        begin
            exponent_out            = '1;
            mantissa_out            = '0;
        end
        else if (overflow_detected)
        begin
            exponent_out            = '1 - 1'b1;
            mantissa_out            = '1;
        end
        else if (product_is_zero)
        begin
            exponent_out            = '0;
            mantissa_out            = '0;
        end
        else
        begin
            mantissa_a                  = add_implicit_one(in_data_a.mantissa, in_data_a.exponent);
            mantissa_b                  = add_implicit_one(in_data_b.mantissa, in_data_b.exponent);

            product_raw                 = mantissa_a * mantissa_b;

            product_greater_than_two    = (product_raw[MANTISSA_PRODUCT_WIDTH-1] == '1);    

            exponent_raw                = (product_greater_than_two) ? (exponent_raw + 'd1)   : exponent_raw;

            if (exponent_raw >= EXPONENT_MAX)
            begin
                exponent_out    = '1 - 1'b1;
                mantissa_out    = '1; 
            end
            else if (exponent_raw == '0)
            begin
                exponent_out    = '0;
                mantissa_out    = '0;
            end
            else
            begin
                product_norm    = (product_greater_than_two) ? (product_raw >> 1) : product_raw;
                exponent_out    = exponent_raw[EXPONENT_WIDTH-1:0];
                mantissa_out    = product_norm[MANTISSA_PRODUCT_SLICE_INDEX -: MANTISSA_WIDTH];
            end
        end
    end

    assign out_data.sign           = sign_out;
    assign out_data.exponent       = exponent_out;
    assign out_data.mantissa       = mantissa_out;

endmodule
