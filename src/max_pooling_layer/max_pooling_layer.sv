`default_nettype none

module max_pooling_layer
    import binary_op_pkg::*;
# (
    parameter INPUT_WIDTH           = 8,
    parameter OUTPUT_WIDTH          = 8,
    parameter POOL_WIDTH            = 3,
    parameter POOL_COUNT            = 13,
    parameter DATA_WIDTH            = 16,
    parameter USE_FLOAT             = 1,

    localparam BUFFER_WIDTH         = POOL_COUNT - 1
) (
    input  wire                                                             clk,
    input  wire                                                             res_n,
    input  wire                                                             in_valid,
    input  wire  [INPUT_WIDTH-1:0 ] [DATA_WIDTH-1:0  ]                      in_data,
    output logic                                                            out_valid,
    output logic                                                            out_buffer_valid,
    output logic [OUTPUT_WIDTH-1:0] [DATA_WIDTH-1:0  ]                      out_data,
    output logic [OUTPUT_WIDTH-1:0] [BUFFER_WIDTH-1:0] [DATA_WIDTH-1:0]     out_buffer
);
    localparam SHIFT_REG_WIDTH      = POOL_WIDTH * BUFFER_WIDTH;
    localparam TAIL_WIDTH           = POOL_WIDTH - 1;
    localparam FILL_WIDTH           = SHIFT_REG_WIDTH + TAIL_WIDTH;
    localparam COUNT_WIDTH          = $clog2(FILL_WIDTH + 1);
    localparam COUNT_MAX            = COUNT_WIDTH'(FILL_WIDTH);

    logic [OUTPUT_WIDTH-1:0] [SHIFT_REG_WIDTH-1:0] [DATA_WIDTH-1:0]     shift_reg;
    logic [OUTPUT_WIDTH-1:0] [TAIL_WIDTH-1     :0] [DATA_WIDTH-1:0]     tail;
    logic [COUNT_WIDTH-1:0 ]                                            count;
    
    logic                                                               filling;
    logic                                                               full;
    logic                                                               buffer_shift;
    logic                                                               buffer_done;

    always_ff @(posedge clk)
    begin
        if (!res_n)
        begin
            count       <= '0;
        end
        else if (in_valid && filling)
        begin
            count       <= count + 'd1;
        end
    end

    always_ff @(posedge clk)
    begin
        if (!res_n)
        begin
            shift_reg   <= '0;
        end
        else if (buffer_shift)
        begin
            for (int i = 0; i < OUTPUT_WIDTH; ++i)
            begin
                shift_reg[i]    <= {in_data[i], shift_reg[i][SHIFT_REG_WIDTH-1:1]};
            end
        end
    end

    always_ff @(posedge clk)
    begin
        if (!res_n)
        begin
            tail            <= '0;
        end
        else if (in_valid)
        begin
            for (int i = 0; i < OUTPUT_WIDTH; ++i)
            begin
                tail[i]     <= {in_data[i], tail[i][TAIL_WIDTH-1:1]};
            end
        end
    end

    generate
        for (genvar i = 0; i < OUTPUT_WIDTH; ++i)
        begin : gen_channel_max
            for (genvar j = 0; j < POOL_COUNT; ++j)
            begin : gen_max
                logic [POOL_WIDTH-1:0] [DATA_WIDTH-1:0]     window;
                logic [DATA_WIDTH-1:0]                      max_result;
                
                binary_tree # (
                    .OP_TYPE        (binary_op_pkg::MAX),
                    .INPUT_WIDTH    (POOL_WIDTH),
                    .DATA_WIDTH     (DATA_WIDTH),
                    .USE_FLOAT      (USE_FLOAT),
                    .PIPELINE       (0)
                ) binary_tree_I (
                    .clk            (clk),
                    .res_n          (res_n),
                    .in_data        (window),
                    .out_data       (max_result)
                );

                if (j == POOL_COUNT - 1)
                begin : gen_last
                    assign window               = {tail[i], in_data[i]};
                    assign out_data[i]          = max_result;
                end
                else
                begin : gen_buffer
                    assign window               = shift_reg[i][POOL_WIDTH*j +: POOL_WIDTH];
                    assign out_buffer[i][j]     = max_result;
                end
            end
        end
    endgenerate

    dly_stages # (
        .NUM_DLY_STAGES     (1),
        .DATA_WIDTH         (1)
    ) dly_stages_I (
        .clk                (clk),
        .res_n              (res_n),
        .in_data            (buffer_done),
        .out_data           (out_buffer_valid)
    );

    assign buffer_shift     = in_valid;
    assign buffer_done      = in_valid && (count >= COUNT_WIDTH'(SHIFT_REG_WIDTH - 1));
    
    assign filling          = (count < COUNT_MAX);
    assign full             = (count == COUNT_MAX);
    assign out_valid        = in_valid && full;
endmodule
