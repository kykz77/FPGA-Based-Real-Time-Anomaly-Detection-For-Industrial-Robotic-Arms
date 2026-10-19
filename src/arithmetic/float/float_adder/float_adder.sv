`default_nettype none

module float_adder
    import float_pkg::*;
(
    input  float_pkg::float_t       in_data_a,
    input  float_pkg::float_t       in_data_b,
    output float_pkg::float_t       out_data
);
    localparam INDEX_WIDTH          = $clog2(MANTISSA_GRS_WIDTH);
    localparam NORM_SHIFT_WIDTH     = $clog2(MANTISSA_GRS_WIDTH + 1);
    localparam NORM_SHIFT_MAX       = NORM_SHIFT_WIDTH'(MANTISSA_GRS_WIDTH - 1);

    logic [NORM_SHIFT_WIDTH-1:0]    norm_shift_amount;
    logic [INDEX_WIDTH-1:0]         leading_one_index;

    float_pkg::shift_amount_t       shift_amount;

    float_pkg::exponent_t           larger_exponent;
    float_pkg::exponent_t           lower_exponent;
    float_pkg::exponent_t           exponent_out;
    
    float_pkg::exponent_t           adj_larger;
    float_pkg::exponent_t           adj_lower;
    
    float_pkg::mantissa_grs_t       mantissa_a;
    float_pkg::mantissa_grs_t       mantissa_b;
    float_pkg::mantissa_sum_t       mantissa_sum; 
    float_pkg::mantissa_t           mantissa_out;

    float_pkg::sign_t               sign_out;

    logic                           exp_a_greater_exp_b;
    logic                           man_a_greater_man_b;

    logic                           overflow_found;

    logic                           sign_same;

    logic                           sum_is_nan;
    logic                           sum_is_inf;

    logic                           float_a_is_inf;
    logic                           float_b_is_inf;

    always_comb
    begin
        exp_a_greater_exp_b         = (in_data_a.exponent > in_data_b.exponent);
        
        larger_exponent             = (exp_a_greater_exp_b) ? in_data_a.exponent : in_data_b.exponent;
        lower_exponent              = (exp_a_greater_exp_b) ? in_data_b.exponent : in_data_a.exponent;

        adj_larger                  = (larger_exponent == '0) ? EXPONENT_WIDTH'(1) : larger_exponent;
        adj_lower                   = (lower_exponent == '0)  ? EXPONENT_WIDTH'(1) : lower_exponent;
        shift_amount                = adj_larger - adj_lower;

        mantissa_a                  = {add_implicit_one(in_data_a.mantissa, in_data_a.exponent), {(GRS_WIDTH){1'b0}}};
        mantissa_b                  = {add_implicit_one(in_data_b.mantissa, in_data_b.exponent), {(GRS_WIDTH){1'b0}}};

        if (exp_a_greater_exp_b)
        begin
            mantissa_b              = (mantissa_b >> shift_amount);
        end
        else
        begin
            mantissa_a              = (mantissa_a >> shift_amount);
        end

        sign_same                   = (in_data_a.sign == in_data_b.sign);

        man_a_greater_man_b         = '0;
        norm_shift_amount           = '0;
        leading_one_index           = '0;
        overflow_found              = '0;
        mantissa_sum                = '0;

        float_a_is_inf              = is_inf(in_data_a);
        float_b_is_inf              = is_inf(in_data_b);

        sum_is_nan                  = (is_nan(in_data_a) || is_nan(in_data_b)) || (float_a_is_inf && float_b_is_inf && (!sign_same));
        sum_is_inf                  = (float_a_is_inf || float_b_is_inf) && !sum_is_nan;

        if (sum_is_nan)
        begin
            sign_out                = '0;
            exponent_out            = '1;
            mantissa_out            = 'b1;
        end
        else if (sum_is_inf)
        begin
            sign_out                = (float_a_is_inf) ? in_data_a.sign : in_data_b.sign;
            exponent_out            = '1;
            mantissa_out            = '0;
        end
        else if (sign_same)
        begin
            mantissa_sum            = mantissa_a + mantissa_b;
            overflow_found          = mantissa_sum[MANTISSA_GRS_WIDTH];

            sign_out                = in_data_a.sign;
            mantissa_out            = (overflow_found) ? mantissa_sum[MANTISSA_GRS_WIDTH-1 -: MANTISSA_WIDTH]   
                                                       : mantissa_sum[MANTISSA_GRS_WIDTH-2 -: MANTISSA_WIDTH];

            if (larger_exponent == '0) 
            begin
                exponent_out        = mantissa_sum[MANTISSA_GRS_WIDTH-1] ? EXPONENT_WIDTH'(1) : '0;
            end 
            else 
            begin
                exponent_out        = larger_exponent + EXPONENT_WIDTH'(overflow_found);
            end
            
            if ((larger_exponent == ('1 - 1'b1)) && overflow_found)
            begin
                exponent_out        = '1 - 1'b1;
                mantissa_out        = '1;
            end
        end
        else
        begin
            man_a_greater_man_b     = (mantissa_a > mantissa_b);

            mantissa_sum            = (man_a_greater_man_b) ? (mantissa_a - mantissa_b) : (mantissa_b - mantissa_a);

            if (mantissa_sum == '0)
            begin
                sign_out        = '0;
                exponent_out    = '0;
                mantissa_out    = '0;
            end
            else
            begin
                for (int index = 0; index < MANTISSA_GRS_WIDTH; ++index)
                begin
                    if (mantissa_sum[index] == '1)
                    begin
                        leading_one_index   = INDEX_WIDTH'(index);
                    end
                end

                norm_shift_amount       = NORM_SHIFT_MAX - NORM_SHIFT_WIDTH'(leading_one_index);

                if (larger_exponent > EXPONENT_WIDTH'(norm_shift_amount)) 
                begin
                    exponent_out            = larger_exponent - EXPONENT_WIDTH'(norm_shift_amount);
                    mantissa_sum            = (mantissa_sum << norm_shift_amount);
                end
                else 
                begin
                    exponent_out            = '0;
                    mantissa_sum            = (mantissa_sum << (larger_exponent > '0 ? (larger_exponent - 1) : '0));
                end

                sign_out                = (man_a_greater_man_b) ? in_data_a.sign : in_data_b.sign;

                mantissa_out            = mantissa_sum[MANTISSA_GRS_WIDTH-2 -: MANTISSA_WIDTH];
            end
        end
    end

    assign out_data.sign           = sign_out;
    assign out_data.exponent       = exponent_out;
    assign out_data.mantissa       = mantissa_out;
endmodule
