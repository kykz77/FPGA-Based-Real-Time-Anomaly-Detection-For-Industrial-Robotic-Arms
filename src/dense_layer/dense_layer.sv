`default_nettype none

module dense_layer
    import dot_product_pkg::*;
# (
    parameter INPUT_WIDTH       = 8,
    parameter BUFFER_WIDTH      = 12,
    parameter OUTPUT_WIDTH      = 9,
    parameter DATA_WIDTH        = 16,
    parameter NUM_CLIENTS       = 5,
    /* verilator lint_off UNUSEDPARAM */
    parameter USE_FLOAT         = 1,
    /* verilator lint_on UNUSEDPARAM */
    localparam KERNEL_WIDTH     = INPUT_WIDTH * (BUFFER_WIDTH + 1),

    parameter dot_product_pkg::dp_settings_arr_t DP_SETTINGS = dot_product_pkg::EMPTY_SETTINGS
) (
    input  wire                                                             clk,
    input  wire                                                             res_n,
    input  wire                                                             in_valid,
    input  wire                                                             in_buffer_valid,
    input  wire  [INPUT_WIDTH-1:0 ] [DATA_WIDTH-1:0   ]                     in_data,
    input  wire  [INPUT_WIDTH-1:0 ] [BUFFER_WIDTH-1:0 ] [DATA_WIDTH-1:0]    in_buffer,
    input  wire  [OUTPUT_WIDTH-1:0] [DATA_WIDTH-1:0   ]                     in_bias,
    input  wire  [OUTPUT_WIDTH-1:0] [KERNEL_WIDTH-1:0 ] [DATA_WIDTH-1:0]    in_kernel,
    output logic                                                            out_valid,
    output logic [OUTPUT_WIDTH-1:0] [DATA_WIDTH-1:0   ]                     out_data,

    dot_product_if.master                                                   dp_if [NUM_CLIENTS]
);
    localparam LAST_SAMPLE_CLIENT       = NUM_CLIENTS - 1;
    localparam BUFFER_FLATTEN_WIDTH     = BUFFER_WIDTH * INPUT_WIDTH;
    localparam NUM_BUFFER_CLIENTS       = NUM_CLIENTS - 1;

    logic [BUFFER_WIDTH-1:0        ] [INPUT_WIDTH-1:0] [DATA_WIDTH-1:0]     buffer_pos_major;
    logic [BUFFER_FLATTEN_WIDTH-1:0] [DATA_WIDTH-1:0 ]                      buffer_flatten;

    generate
        for (genvar i = 0; i < BUFFER_WIDTH; ++i)
        begin : gen_r
            for (genvar j = 0; j < INPUT_WIDTH; ++j)
            begin : gen_c
                assign buffer_pos_major[i][j] = in_buffer[j][i];
            end
        end
    endgenerate

    assign buffer_flatten   = buffer_pos_major;

    logic [NUM_CLIENTS-1:0] [OUTPUT_WIDTH-1:0] [DATA_WIDTH-1:0]     client_out_data;
    logic [NUM_CLIENTS-1:0]                                         client_out_valid;
    /* verilator lint_off UNUSEDSIGNAL */
    logic [NUM_CLIENTS-1:0]                                         client_out_rd_done;
    /* verilator lint_on UNUSEDSIGNAL */
    
    generate
        for (genvar i = 0; i < NUM_CLIENTS; ++i)
        begin : gen_clients
            localparam START                = DP_SETTINGS[i].START;
            localparam OUT_WIDTH            = DP_SETTINGS[i].OUTPUT_WIDTH;

            localparam KERNEL_START_INDEX   = DP_SETTINGS[i].KERNEL_START;
            localparam KERNEL_SLICE_WIDTH   = slice_len(DP_SETTINGS[i]);

            logic [KERNEL_SLICE_WIDTH-1:0] [DATA_WIDTH-1:0        ]                         window;
            logic [OUT_WIDTH-1:0         ] [KERNEL_SLICE_WIDTH-1:0] [DATA_WIDTH-1:0]        kernel;
            logic [OUT_WIDTH-1:0         ] [DATA_WIDTH-1:0        ]                         part;
            logic                                                                           valid;

            dot_product_client # (
                .SETTINGS               (DP_SETTINGS[i])
            ) dot_product_client_I (
                .clk                    (clk),
                .res_n                  (res_n),
                .in_valid               (valid),
                .in_window              (window),
                .in_kernel              (kernel),
                .in_bias                (in_bias[START +: OUT_WIDTH]),
                .out_data               (part),
                .out_valid              (client_out_valid[i]),
                .out_rd_done            (client_out_rd_done[i]),
                .dp_if                  (dp_if[i])
            );

            if (i == LAST_SAMPLE_CLIENT)
            begin : gen_last_input
                assign window   = in_data;
                assign valid    = in_valid;
            end
            else
            begin : gen_input
                assign window   = buffer_flatten[KERNEL_START_INDEX +: KERNEL_SLICE_WIDTH];
                assign valid    = in_buffer_valid;
            end

            for (genvar j = 0; j < OUT_WIDTH; ++j)
            begin : gen_kernel
                assign kernel[j]       = in_kernel[START + j][KERNEL_START_INDEX +: KERNEL_SLICE_WIDTH];
            end

            always_comb
            begin
                client_out_data[i]                      = '0;
                client_out_data[i][START +: OUT_WIDTH]  = part;
            end
        end
    endgenerate

    logic [NUM_BUFFER_CLIENTS-1:0]              rd_done_r;
    logic [NUM_BUFFER_CLIENTS-1:0]              rd_done_c;
    logic [NUM_BUFFER_CLIENTS-1:0]              rd_done_all;
    logic                                       rd_done;

    always_ff @(posedge clk)
    begin
        if (!res_n || rd_done)
        begin
            rd_done_r       <= '0;
        end
        else
        begin
            rd_done_r       <= rd_done_all;
        end
    end    

    assign rd_done_c        = (client_out_rd_done[0 +: NUM_BUFFER_CLIENTS]);
    assign rd_done_all      = (rd_done_r | rd_done_c);
    assign rd_done          = &rd_done_all;

    localparam PSUM_PTR_WIDTH   = $clog2(NUM_BUFFER_CLIENTS);
    localparam PSUM_PTR_LAST    = PSUM_PTR_WIDTH'(NUM_BUFFER_CLIENTS - 1);

    logic [NUM_BUFFER_CLIENTS-1:0] [OUTPUT_WIDTH-1:0] [DATA_WIDTH-1:0]  client_saved;
    logic [NUM_BUFFER_CLIENTS-1:0]                                      client_ready;
    logic [OUTPUT_WIDTH-1:0] [DATA_WIDTH-1:0]                           psum_r;
    logic [OUTPUT_WIDTH-1:0] [DATA_WIDTH-1:0]                           psum_c;
    logic [PSUM_PTR_WIDTH-1:0]                                          psum_ptr;
    logic                                                               psum_add;
    logic                                                               psum_done;
    /* verilator lint_off WIDTHEXPAND */
    assign psum_add     = client_ready[psum_ptr];
    /* verilator lint_on WIDTHEXPAND */
    assign psum_done    = psum_add && (psum_ptr == PSUM_PTR_LAST);

    generate
        for (genvar o = 0; o < OUTPUT_WIDTH; ++o)
        begin : gen_psum_adder
            adder # (
                .DATA_WIDTH     (DATA_WIDTH),
                .USE_FLOAT      (USE_FLOAT)
            ) adder_I (
                .in_data_a      (psum_r[o]),
                .in_data_b      (client_saved[psum_ptr][o]),
                .out_data       (psum_c[o])
            );
        end
    endgenerate

    always_ff @(posedge clk)
    begin
        if (!res_n)
        begin
            psum_ptr    <= '0;
            psum_r      <= in_bias;
        end
        else if (psum_add)
        begin
            psum_ptr    <= (psum_done) ? '0      : (psum_ptr + 'd1);
            psum_r      <= (psum_done) ? in_bias : psum_c;
        end
    end

    always_ff @(posedge clk)
    begin
        if (!res_n)
        begin
            client_ready    <= '0;
        end
        else
        begin
            for (int i = 0; i < NUM_BUFFER_CLIENTS; ++i)
            begin
                if (psum_add && (psum_ptr == PSUM_PTR_WIDTH'(i)))
                begin
                    client_ready[i]     <= client_ready[i] && client_out_valid[i];
                    if (client_ready[i] && client_out_valid[i])
                    begin
                        client_saved[i] <= client_out_data[i];
                    end
                end
                else if (client_out_valid[i] && !client_ready[i])
                begin
                    client_ready[i]     <= 1'b1;
                    client_saved[i]     <= client_out_data[i];
                end
            end
        end
    end

    localparam QUEUE_DEPTH      = 4;
    localparam QUEUE_PTR_WIDTH  = $clog2(QUEUE_DEPTH);

    logic [QUEUE_DEPTH-1:0] [OUTPUT_WIDTH-1:0] [DATA_WIDTH-1:0]       queue;
    logic [QUEUE_PTR_WIDTH-1:0]                                       queue_wr;
    logic [QUEUE_PTR_WIDTH-1:0]                                       queue_rd;
    logic                                                             last_valid;
    logic [OUTPUT_WIDTH-1:0] [DATA_WIDTH-1:0]                         final_c;

    always_ff @(posedge clk)
    begin
        if (!res_n)
        begin
            queue_wr    <= '0;
            queue_rd    <= '0;
        end
        else
        begin
            if (psum_done)
            begin
                queue[queue_wr] <= psum_c;
                queue_wr        <= queue_wr + 'd1;
            end
            if (last_valid)
            begin
                queue_rd        <= queue_rd + 'd1;
            end
        end
    end

    assign last_valid = client_out_valid[LAST_SAMPLE_CLIENT];

    generate
        for (genvar i = 0; i < OUTPUT_WIDTH; ++i)
        begin : gen_final_adder
            adder # (
                .DATA_WIDTH     (DATA_WIDTH),
                .USE_FLOAT      (USE_FLOAT)
            ) adder_I (
                .in_data_a      (queue[queue_rd][i]),
                .in_data_b      (client_out_data[LAST_SAMPLE_CLIENT][i]),
                .out_data       (final_c[i])
            );
        end
    endgenerate

    always_ff @(posedge clk)
    begin
        if (!res_n)
        begin
            out_valid   <= 1'b0;
            out_data    <= '0;
        end
        else
        begin
            out_valid   <= last_valid;
            if (last_valid)
                out_data <= final_c;
        end
    end
endmodule
