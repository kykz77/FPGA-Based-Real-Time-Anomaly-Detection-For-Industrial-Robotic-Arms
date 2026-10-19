`default_nettype none

module rolling_sum 
# (
    parameter WINDOW_WIDTH  = 45,
    parameter DATA_WIDTH    = 16,
    parameter USE_FLOAT     = 1
) (
    input  wire                         clk,
    input  wire                         res_n,
    input  wire                         in_valid,
    input  wire  [DATA_WIDTH-1:0]       in_data,
    output logic                        out_valid,
    output logic [DATA_WIDTH-1:0]       out_data
);  
    logic [DATA_WIDTH-1:0]      add_data;

    logic [DATA_WIDTH-1:0]      rd_data_neg;
    logic [DATA_WIDTH-1:0]      rd_data;
    logic                       rd_en;
    logic                       rd_en_dly;

    logic [DATA_WIDTH-1:0]      wr_data;
    logic                       wr_en;
    
    logic                       full;
    /* verilator lint_off UNUSEDSIGNAL */
    logic                       empty;
    /* verialtor lint_on UNUSEDSIGNAL */

    logic [DATA_WIDTH-1:0]      sum_r;
    logic [DATA_WIDTH-1:0]      sum_c;
    
    sync_fifo # (
        .FIFO_DEPTH         (WINDOW_WIDTH),
        .DATA_WIDTH         (DATA_WIDTH)
    ) sync_fifo_I (
        .clk                (clk),
        .res_n              (res_n),
        .wr_en              (wr_en),
        .wr_data            (wr_data),
        .rd_en              (rd_en),
        .rd_data            (rd_data),
        .empty              (empty),
        .full               (full)
    );

    dly_stages # (
        .NUM_DLY_STAGES     (1),
        .DATA_WIDTH         (1)
    ) rd_en_dly_stages_I (
        .clk                (clk),
        .res_n              (res_n),
        .in_data            (rd_en),
        .out_data           (rd_en_dly)
    );

    dly_stages # (
        .NUM_DLY_STAGES     (1),
        .DATA_WIDTH         (1)
    ) rd_en_dly_dly_stages_I (
        .clk                (clk),
        .res_n              (res_n),
        .in_data            (rd_en_dly),
        .out_data           (out_valid)
    );

    adder # (
        .DATA_WIDTH         (DATA_WIDTH),
        .USE_FLOAT          (USE_FLOAT)
    ) adder_I (
        .in_data_a          (sum_r),
        .in_data_b          (add_data),
        .out_data           (sum_c)
    );

    always_ff @(posedge clk)
    begin
        if (!res_n)
        begin
            sum_r       <= '0;
        end
        else if (in_valid || rd_en_dly)
        begin
            sum_r       <= sum_c;
        end
    end

    assign rd_en        = in_valid && full;
    assign rd_data_neg  = (USE_FLOAT) ? {~rd_data[DATA_WIDTH-1], rd_data[DATA_WIDTH-2:0]} : -rd_data;
    assign wr_en        = in_valid;
    assign wr_data      = in_data;
    assign add_data     = (in_valid) ? in_data : rd_data_neg;
    assign out_data     = sum_r;
endmodule
