`default_nettype none

module dot_product_client
    import float_pkg::*;
    import dot_product_pkg::*;
# (
    parameter dot_product_pkg::dp_settings_t SETTINGS = dot_product_pkg::DEFAULT_SETTINGS,

    localparam USE_FLOAT                = SETTINGS.USE_FLOAT,
    localparam OUTPUT_WIDTH             = SETTINGS.OUTPUT_WIDTH,
    localparam DATA_WIDTH               = SETTINGS.DATA_WIDTH,
    localparam BANK_WIDTH               = SETTINGS.BANK_WIDTH,
    localparam INPUT_WIDTH              = SETTINGS.INPUT_WIDTH,
    localparam CYCLES_PER_CHANNEL       = SETTINGS.CYCLES_PER_CHANNEL,
    localparam PARALLEL                 = SETTINGS.PARALLEL,
    localparam STREAM                   = SETTINGS.STREAM,
    localparam USE_BIAS                 = SETTINGS.USE_BIAS,

    localparam CHUNK_WIDTH              = (SETTINGS.STREAM == 1) ? 1 : SETTINGS.CYCLES_PER_CHANNEL,
    localparam WINDOW_WIDTH             = window_width(SETTINGS)
) (
    input  wire                                                                                         clk,
    input  wire                                                                                         res_n,
    input  wire                                                                                         in_valid,
    input  wire  [CHUNK_WIDTH-1:0 ] [WINDOW_WIDTH-1:0      ] [DATA_WIDTH-1:0 ]                          in_window,
    input  wire  [OUTPUT_WIDTH-1:0] [CYCLES_PER_CHANNEL-1:0] [WINDOW_WIDTH-1:0] [DATA_WIDTH-1:0]        in_kernel,

    /* verilator lint_off UNUSED */
    input  wire  [OUTPUT_WIDTH-1:0] [DATA_WIDTH-1:0 ]                                                   in_bias,
    /* verilator lint_on UNUSED */
    
    output logic [OUTPUT_WIDTH-1:0] [DATA_WIDTH-1:0 ]                                                   out_data,
    output logic                                                                                        out_valid,
    output logic                                                                                        out_rd_done,

    dot_product_if.master                                                                               dp_if
);
    localparam CONST_ZERO           = 0;
    localparam CONST_ONE            = (SETTINGS.USE_FLOAT == 1) ? FLOAT_ONE  : 'd1;
    localparam CHANNELS_PER_CYCLE   = (SETTINGS.PARALLEL == 1)  ? SETTINGS.BANK_WIDTH : 'd1;

    localparam GROUPS               = ceil_div(OUTPUT_WIDTH,CHANNELS_PER_CYCLE);
    localparam PTR_WIDTH            = $clog2(GROUPS + 1);
    localparam PTR_MAX              = PTR_WIDTH'(GROUPS - 1);
    localparam ADDR_OFFSET          = ceil_div(OUTPUT_WIDTH,BANK_WIDTH);
    localparam ADDR_WIDTH           = (ADDR_OFFSET * BANK_WIDTH > 1) ? $clog2(ADDR_OFFSET * BANK_WIDTH) : 'd1;
    localparam COUNT_WIDTH          = $clog2(CYCLES_PER_CHANNEL + 1);
    localparam COUNT_MAX            = COUNT_WIDTH'(CYCLES_PER_CHANNEL - 1);

    logic [PTR_WIDTH-1:0 ]          rd_ptr;
    logic [COUNT_WIDTH-1:0]         rd_count;
    logic                           rd_at_max;
    logic                           rd_idle;
    logic                           last_rd;
    logic                           pending;
    logic                           rd_done;

    always_ff @(posedge clk)
    begin
        if (!res_n)
        begin
            rd_ptr      <= '0;
            rd_count    <= '0;
        end
        else if (dp_if.dp_grant)
        begin
            if (rd_at_max)
            begin
                rd_count    <= (last_rd) ? '0 : (rd_count + 'd1);
            end

            rd_ptr  <= (rd_at_max) ? '0 : (rd_ptr + 'd1);
        end
    end

    always_ff @(posedge clk)
    begin
        if (!res_n)
        begin
            pending     <= '0;
        end
        else if (!dp_if.dp_grant && in_valid)
        begin
            pending     <= '1;
        end
        else if (dp_if.dp_grant)
        begin
            pending     <= '0;
        end
    end

    assign last_rd          = (rd_count == COUNT_MAX);
    assign rd_done          = last_rd && dp_if.dp_grant && rd_at_max;
    assign rd_at_max        = (rd_ptr == PTR_MAX);
    assign rd_idle          = ((rd_ptr == '0) && ((STREAM == 1) || rd_count == '0));
    assign dp_if.dp_req     = (rd_idle && (in_valid || pending)) || !rd_idle;
    assign out_rd_done      = rd_done;

    logic [WINDOW_WIDTH-1:0] [DATA_WIDTH-1:0]   curr_window;
    generate
        if (STREAM == 1)
        begin : gen_stream_window
            assign curr_window  = in_window[0];
        end
        else
        begin : gen_chunk_window
            assign curr_window  = in_window[rd_count];
        end
    endgenerate
    
    /* verilator lint_off WIDTHEXPAND */
    generate
        for (genvar i = 0; i < BANK_WIDTH; ++i)
        begin : gen_read
            if (PARALLEL == 1)
            begin : gen_parallel   
                localparam OFFSET       = ADDR_OFFSET * i;

                logic [ADDR_WIDTH-1:0] addr;

                if (USE_BIAS == 1)
                begin : gen_bias
                    logic [DATA_WIDTH-1:0] num;
                    assign dp_if.dp_kernel[i]   = {in_kernel[addr][rd_count],in_bias[addr]};
                    assign dp_if.dp_window[i]   = {curr_window,num};
                    assign num                  = DATA_WIDTH'((rd_count == '0) ? CONST_ONE : CONST_ZERO);
                end
                else
                begin : gen_no_bias
                    assign dp_if.dp_kernel[i]   = in_kernel[addr][rd_count];
                    assign dp_if.dp_window[i]   = curr_window;
                end

                assign addr     = ADDR_WIDTH'(OFFSET) + ADDR_WIDTH'(rd_ptr);
            end
            else
            begin : gen_sequential
                localparam OFFSET       = INPUT_WIDTH * i;
                
                if (USE_BIAS == 1)
                begin : gen_bias
                    logic [DATA_WIDTH-1:0] num;

                    assign dp_if.dp_kernel[i]   = {in_kernel[rd_ptr][rd_count][OFFSET +: INPUT_WIDTH],in_bias[rd_ptr]};
                    assign dp_if.dp_window[i]   = {curr_window[OFFSET +: INPUT_WIDTH],num};
                    assign num                  = DATA_WIDTH'(((i == 0) && (rd_count == '0)) ? CONST_ONE : CONST_ZERO);
                end
                else
                begin : gen_no_bias
                    assign dp_if.dp_kernel[i]   = in_kernel[rd_ptr][rd_count][OFFSET +: INPUT_WIDTH];
                    assign dp_if.dp_window[i]   = curr_window[OFFSET +: INPUT_WIDTH];
                end
            end
        end
    endgenerate
    /* verilator lint_on WIDTHEXPAND */

    logic [PTR_WIDTH-1:0 ]      wr_ptr;
    logic [COUNT_WIDTH-1:0]     wr_count;
    logic                       wr_at_max;
    logic                       last_wr;
    logic                       wr_done;

    always_ff @(posedge clk)
    begin
        if (!res_n)
        begin
            wr_count        <= '0;
            wr_ptr          <= '0;
        end
        else if (dp_if.dp_res_valid)
        begin
            if (wr_at_max)
            begin
                wr_count  <= (last_wr) ? '0 : (wr_count + 'd1);
            end

            wr_ptr      <= wr_at_max ? '0 : (wr_ptr + 'd1);
        end
    end

    assign last_wr      = (wr_count == COUNT_MAX);
    assign wr_at_max    = (wr_ptr == PTR_MAX);
    assign wr_done      = last_wr && wr_at_max && dp_if.dp_res_valid;

    logic [OUTPUT_WIDTH-1:0] [DATA_WIDTH-1:0]   data_r;
    logic [OUTPUT_WIDTH-1:0] [DATA_WIDTH-1:0]   data_c; 

    always_ff @(posedge clk)
    begin
        if (!res_n)
            data_r  <= '0;
        else if (dp_if.dp_res_valid)
            data_r  <= data_c;
    end

    assign out_data     = data_c;
    assign out_valid    = wr_done;

    generate
        if (PARALLEL == 1)
        begin : gen_parallel
            logic [BANK_WIDTH-1:0] [ADDR_WIDTH-1:0]     wr_addr;
            logic [BANK_WIDTH-1:0] [DATA_WIDTH-1:0]     sum;

            for (genvar i = 0; i < BANK_WIDTH; ++i)
            begin : gen_write_address
                localparam OFFSET = ADDR_WIDTH'(ADDR_OFFSET * i);

                assign wr_addr[i] = ADDR_WIDTH'(wr_ptr) + OFFSET;

                if (CYCLES_PER_CHANNEL == 1)
                begin : gen_single
                    assign sum[i] = dp_if.dp_res[i]; 
                end
                else
                begin : gen_accumulate
                    logic [DATA_WIDTH-1:0] prev_sum;

                    adder # (
                        .DATA_WIDTH     (DATA_WIDTH),
                        .USE_FLOAT      (USE_FLOAT)
                    ) adder_I (
                        .in_data_a      (dp_if.dp_res[i]),
                        .in_data_b      (prev_sum),
                        .out_data       (sum[i])
                    );

                    assign prev_sum = (wr_count == '0) ? '0 : data_r[wr_addr[i]];
                end
            end

            always_comb
            begin
                data_c = data_r;
                if (dp_if.dp_res_valid)
                begin
                    for (int i = 0; i < BANK_WIDTH; ++i)
                    begin
                        if (32'(wr_addr[i]) < OUTPUT_WIDTH)
                        begin
                            data_c[wr_addr[i]] = sum[i];
                        end
                    end
                end
            end
        end
        else if ((BANK_WIDTH == 2) && (CYCLES_PER_CHANNEL == 1))
        begin : gen_sequential_write_1
            logic [DATA_WIDTH-1:0] sum;

            adder # (
                .DATA_WIDTH     (DATA_WIDTH),
                .USE_FLOAT      (USE_FLOAT)
            ) adder_I (
                .in_data_a      (dp_if.dp_res[0]),
                .in_data_b      (dp_if.dp_res[1]),
                .out_data       (sum)
            );

            always_comb
            begin
                data_c = data_r;
                if (dp_if.dp_res_valid)
                    data_c[wr_ptr] = sum;
            end
        end
        else if ((BANK_WIDTH == 1) && (CYCLES_PER_CHANNEL == 1))
        begin : gen_sequential_write_2
            always_comb
            begin
                data_c = data_r;
                if (dp_if.dp_res_valid)
                    data_c[wr_ptr] = dp_if.dp_res[0];
            end
        end
    endgenerate
endmodule
