`ifndef DOT_PRODUCT_PKG_SV
`define DOT_PRODUCT_PKG_SV

package dot_product_pkg;
    localparam MAX_DP = 8;

    typedef struct packed {
        int     BANK_WIDTH;
        int     INPUT_WIDTH;
        int     CYCLES_PER_CHANNEL;
        int     PARALLEL;
        int     USE_BIAS;
        int     STREAM;
        int     DATA_WIDTH;
        int     OUTPUT_WIDTH;
        int     USE_FLOAT;
        int     START;
        int     KERNEL_START;
    } dp_settings_t;

    typedef dp_settings_t [MAX_DP-1:0] dp_settings_arr_t;

    /* verilator lint_off UNUSED */
    localparam dp_settings_t        DEFAULT_SETTINGS = '{
        BANK_WIDTH:         32'd1,
        INPUT_WIDTH:        32'd1,
        CYCLES_PER_CHANNEL: 32'd1,
        PARALLEL:           32'd0,
        USE_BIAS:           32'd0,
        STREAM:             32'd0,
        DATA_WIDTH:         32'd1,
        OUTPUT_WIDTH:       32'd1,
        USE_FLOAT:          32'd0,
        START:              32'd0,
        KERNEL_START:       32'd0
    };
    localparam dp_settings_arr_t    EMPTY_SETTINGS  = '0;
    /* verilator lint_on UNUSED */

    function int ceil_div(int x, int y);
        return ((x + y - 1) / y);
    endfunction

    /* verilator lint_off UNUSED */
    function automatic int window_width(dp_settings_t S);
        return S.INPUT_WIDTH * ((S.PARALLEL == 1) ? 1 : S.BANK_WIDTH);
    endfunction

    function automatic int slice_len(dp_settings_t S);
        return S.CYCLES_PER_CHANNEL * window_width(S);
    endfunction

    function automatic int slice_start(dp_settings_arr_t S, int i);
        int start = 0;
        for (int j = 0; j < i; ++j)
        begin
            start += slice_len(S[j]);
        end
        return start;
    endfunction

    function automatic int num_dp(dp_settings_arr_t S);
        int num = 0;
        for (int i = 0; i < MAX_DP; ++i)
        begin
            if (S[i] != 0)
            begin
                num ++;
            end
        end
        return num;
    endfunction
    /* verilator lint_on UNUSED */



endpackage

`endif
