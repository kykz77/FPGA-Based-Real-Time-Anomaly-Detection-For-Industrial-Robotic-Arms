`default_nettype none

module dot_product_bank
    import dot_product_pkg::*;
# ( 
    parameter NUM_CLIENTS   = 3,

    parameter dot_product_pkg::dp_settings_t SETTINGS = dot_product_pkg::DEFAULT_SETTINGS
) (
    input wire              clk,
    input wire              res_n,
    
    dot_product_if.slave    dp_if [NUM_CLIENTS]
);  
    localparam USE_FLOAT        = SETTINGS.USE_FLOAT;
    localparam DATA_WIDTH       = SETTINGS.DATA_WIDTH;
    localparam BANK_WIDTH       = SETTINGS.BANK_WIDTH;
    localparam DP_INPUT_WIDTH   = SETTINGS.INPUT_WIDTH;
    localparam DP_DLY           = $clog2(DP_INPUT_WIDTH) + 1;
    localparam WINDOW_WIDTH     = BANK_WIDTH * DP_INPUT_WIDTH * DATA_WIDTH;
    localparam KERNEL_WIDTH     = WINDOW_WIDTH;
    localparam REQ_DATA_WIDTH   = WINDOW_WIDTH + KERNEL_WIDTH;

    logic [NUM_CLIENTS-1:0]                                             req;
    logic [NUM_CLIENTS-1:0]                                             grant;
    logic [NUM_CLIENTS-1:0]                                             res_valid;
    logic [NUM_CLIENTS-1:0] [REQ_DATA_WIDTH-1:0]                        req_data;
    logic [BANK_WIDTH-1:0 ] [DATA_WIDTH-1:0    ]                        res;
    logic [BANK_WIDTH-1:0 ] [DP_INPUT_WIDTH-1:0] [DATA_WIDTH-1:0]       window;
    logic [BANK_WIDTH-1:0 ] [DP_INPUT_WIDTH-1:0] [DATA_WIDTH-1:0]       kernel;
    logic [NUM_CLIENTS-1:0] [BANK_WIDTH-1:0] [DP_INPUT_WIDTH-1:0] [DATA_WIDTH-1:0]  req_window;
    logic [NUM_CLIENTS-1:0] [BANK_WIDTH-1:0] [DP_INPUT_WIDTH-1:0] [DATA_WIDTH-1:0]  req_kernel;

    priority_encoder # (
        .INPUT_WIDTH        (NUM_CLIENTS),
        .DATA_WIDTH         (REQ_DATA_WIDTH)
    ) priority_encoder_I (
        .in_req             (req),
        .in_data            (req_data),
        .out_grant          (grant),
        .out_data           ({window,kernel})
    );

    dly_stages # (
        .NUM_DLY_STAGES     (DP_DLY),
        .DATA_WIDTH         (NUM_CLIENTS)
    ) dly_stages_I (
        .clk                (clk),
        .res_n              (res_n),
        .in_data            (grant),
        .out_data           (res_valid)
    );

    generate
        for (genvar i = 0; i < BANK_WIDTH; ++i)
        begin : gen_dot_product
            dot_product # (
                .INPUT_WIDTH    (DP_INPUT_WIDTH),
                .DATA_WIDTH     (DATA_WIDTH),
                .USE_FLOAT      (USE_FLOAT)
            ) dot_product_I (
                .clk            (clk),
                .res_n          (res_n),
                .in_data_a      (window[i]),
                .in_data_b      (kernel[i]),
                .out_data       (res[i])
            );
        end

        for (genvar i = 0; i < NUM_CLIENTS; ++i)
        begin : gen_if
            assign req[i]                   = dp_if[i].dp_req;
            
            for (genvar b = 0; b < BANK_WIDTH; ++b)
            begin : gen_rows
                assign req_window[i][b] = dp_if[i].dp_window[b][DP_INPUT_WIDTH-1:0];
                assign req_kernel[i][b] = dp_if[i].dp_kernel[b][DP_INPUT_WIDTH-1:0];
            end
            assign req_data[i] = {req_window[i], req_kernel[i]};

            assign dp_if[i].dp_grant        = grant[i];
            assign dp_if[i].dp_res_valid    = res_valid[i];
            /* verilator lint_off WIDTHEXPAND */
            assign dp_if[i].dp_res          = res;
            /* verilator lint_on WIDTHEXPAND */
        end
    endgenerate
endmodule
