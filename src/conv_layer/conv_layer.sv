`default_nettype none

module conv_layer
    import dot_product_pkg::*;
# (
    parameter                   KERNEL_WIDTH                    = 9,
    parameter                   KERNEL_HEIGHT                   = 3,
    parameter                   IMAGE_WIDTH                     = 9,
    parameter                   INPUT_WIDTH                     = 1,
    parameter                   NUM_CLIENTS                     = 2,
    parameter                   DATA_WIDTH                      = 16,
    parameter                   OUTPUT_WIDTH                    = 8,
    parameter                   USE_FLOAT                       = 1,
    localparam                  KERNEL_SIZE                     = KERNEL_HEIGHT * KERNEL_WIDTH,
    localparam                  WINDOW_BOT_WIDTH                = (KERNEL_HEIGHT - 1) * KERNEL_WIDTH,
    localparam                  WINDOW_TOP_WIDTH                = KERNEL_WIDTH,

    parameter dot_product_pkg::dp_settings_arr_t DP_SETTINGS    = dot_product_pkg::EMPTY_SETTINGS
) (
    input  wire                                                                 clk,
    input  wire                                                                 res_n,

    input  wire                                                                 in_valid,
    input  wire  [INPUT_WIDTH-1:0  ]    [DATA_WIDTH-1:0 ]                       in_data,
    input  wire  [OUTPUT_WIDTH-1:0 ]    [KERNEL_SIZE-1:0] [DATA_WIDTH-1:0]      in_kernel,
    input  wire  [OUTPUT_WIDTH-1:0 ]    [DATA_WIDTH-1:0 ]                       in_bias,

    output logic                                                                out_valid,
    output logic [OUTPUT_WIDTH-1:0 ]    [DATA_WIDTH-1:0 ]                       out_data,

    dot_product_if.master                                                       dp_if [NUM_CLIENTS]
);  
    localparam TOP_DP                   = 0;
    localparam BOT_DP                   = 1;
    localparam SHIFT_REG_WIDTH          = (KERNEL_HEIGHT - 1) * IMAGE_WIDTH;

    logic   buffer_window;
    logic   window_partial_full;

    conv_layer_controller # (
        .INPUT_WIDTH                (INPUT_WIDTH),
        .KERNEL_WIDTH               (KERNEL_WIDTH),
        .KERNEL_HEIGHT              (KERNEL_HEIGHT),
        .IMAGE_WIDTH                (IMAGE_WIDTH),
        .SHIFT_REG_WIDTH            (SHIFT_REG_WIDTH)
    ) conv_layer_controller_I (
        .clk                        (clk),
        .res_n                      (res_n),
        .in_valid                   (in_valid),
        .out_buffer_window          (buffer_window),
        .out_window_partial_full    (window_partial_full)
    );

    logic [SHIFT_REG_WIDTH-1:0] [DATA_WIDTH-1:0]    buffer;

    shift_register # (
        .SHIFT_REG_WIDTH    (SHIFT_REG_WIDTH),
        .INPUT_WIDTH        (INPUT_WIDTH),
        .DATA_WIDTH         (DATA_WIDTH)
    ) shift_register_I (
        .clk                (clk),
        .res_n              (res_n),
        .in_valid           (in_valid),
        .in_data            (in_data),
        .out_data           (buffer)
    );

    logic [WINDOW_BOT_WIDTH-1:0] [DATA_WIDTH-1:0]       window_bot_r;
    logic [WINDOW_BOT_WIDTH-1:0] [DATA_WIDTH-1:0]       window_bot_c;
    logic [WINDOW_BOT_WIDTH-1:0] [DATA_WIDTH-1:0]       window_bot_dp; 
    logic                                               window_bot_valid;

    always_ff @(posedge clk)
    begin
        if (!res_n)
        begin
            window_bot_r        <= '0;
        end
        else if (buffer_window)
        begin
            window_bot_r        <= window_bot_c;
        end
    end
    
    assign window_bot_c         = buffer[SHIFT_REG_WIDTH-1 -: WINDOW_BOT_WIDTH];
    assign window_bot_dp        = (buffer_window) ? window_bot_c : window_bot_r; 
    assign window_bot_valid     = buffer_window;

    logic [NUM_CLIENTS-1:0] [OUTPUT_WIDTH-1:0] [DATA_WIDTH-1:0]   client_out_data;
    logic [NUM_CLIENTS-1:0]                                       client_out_valid;

    generate
        for (genvar i = 0; i < NUM_CLIENTS; ++i)
        begin : gen_dp_client
            localparam START_INDEX      = slice_start(DP_SETTINGS,i);
            localparam SLICE_WIDTH      = slice_len(DP_SETTINGS[i]);
            localparam WINDOW_WIDTH     = ((DP_SETTINGS[i].STREAM == 1) ? window_width(DP_SETTINGS[i]) : SLICE_WIDTH);

            logic [WINDOW_WIDTH-1:0] [DATA_WIDTH-1:0 ]                      window;
            logic [OUTPUT_WIDTH-1:0] [SLICE_WIDTH-1:0] [DATA_WIDTH-1:0]     kernel;
            logic                                                           valid;

            for (genvar ch = 0; ch < OUTPUT_WIDTH; ++ch)
            begin : gen_kernel
                assign kernel[ch]   = in_kernel[ch][START_INDEX +: SLICE_WIDTH];
            end

            if (DP_SETTINGS[i].STREAM == 1)
            begin : gen_top
                assign window   = in_data;
                assign valid    = in_valid && window_partial_full;
            end
            else
            begin : gen_bottom
                assign window   = window_bot_dp[(START_INDEX - WINDOW_TOP_WIDTH) +: SLICE_WIDTH];
                assign valid    = window_bot_valid;
            end

            dot_product_client # (
                .SETTINGS               (DP_SETTINGS[i])
            ) dot_product_client_I (
                .clk                    (clk),
                .res_n                  (res_n),
                .in_valid               (valid),
                .in_window              (window),
                .in_kernel              (kernel),
                .in_bias                (in_bias),
                .out_data               (client_out_data[i]),
                .out_valid              (client_out_valid[i]),
                /* verilator lint_off PINCONNECTEMPTY */
                .out_rd_done            (),
                /* verilator lint_on PINCONNECTEMPTY */
                .dp_if                  (dp_if[i])
            );
        end
    endgenerate

    logic [OUTPUT_WIDTH-1:0] [DATA_WIDTH-1:0]   client_sum_c;
    logic [OUTPUT_WIDTH-1:0] [DATA_WIDTH-1:0]   client_sum_r;
    logic                                       client_sum_valid;

    generate
        for (genvar i = 0; i < OUTPUT_WIDTH; ++i)
        begin : gen_adders
            adder # (
                .DATA_WIDTH     (DATA_WIDTH),
                .USE_FLOAT      (USE_FLOAT)
            ) adder_I (
                .in_data_a      (client_out_data[TOP_DP][i]),
                .in_data_b      (client_out_data[BOT_DP][i]),
                .out_data       (client_sum_c[i])
            );
        end
    endgenerate

    always_ff @(posedge clk)
    begin
        if (!res_n)
        begin
            client_sum_r    <= '0;
        end
        else if (client_out_valid[TOP_DP])
        begin
            client_sum_r    <= client_sum_c;
        end
    end

    dly_stages # (
        .NUM_DLY_STAGES     (1),
        .DATA_WIDTH         (1)
    ) dly_stages_I (
        .clk                (clk),
        .res_n              (res_n),
        .in_data            (client_out_valid[TOP_DP]),
        .out_data           (client_sum_valid)
    );

    assign out_valid    = client_sum_valid;
    assign out_data     = client_sum_r;
endmodule 
