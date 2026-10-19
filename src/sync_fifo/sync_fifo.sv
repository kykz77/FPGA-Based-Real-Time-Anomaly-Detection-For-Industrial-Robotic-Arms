`default_nettype none

module sync_fifo 
# (
    parameter           FIFO_DEPTH      = 45,
    parameter           DATA_WIDTH      = 16,
    /* verilator lint_off UNUSEDPARAM */
    parameter string    RAM_STYLE       = "block",
    /* verilator lint_on UNUSEDPARAM */
    localparam          ADDR_WIDTH      = $clog2(FIFO_DEPTH + 1)
) (
    input wire                      clk,
    input wire                      res_n,
    input wire                      wr_en,
    input wire                      rd_en,
    input wire [DATA_WIDTH-1:0]     wr_data,
    output logic [DATA_WIDTH-1:0]   rd_data,
    output logic                    empty,
    output logic                    full
);  
    localparam ADDR_MAX = ADDR_WIDTH'(FIFO_DEPTH);

    (* ram_style = RAM_STYLE *) logic [DATA_WIDTH-1:0] mem [FIFO_DEPTH:0];

    logic [ADDR_WIDTH-1:0]                      rd_ptr;
    
    always_ff @(posedge clk)
    begin
        if (!res_n)
        begin
            rd_ptr      <= '0;
        end
        else if (rd_en && !empty)
        begin
            rd_data     <= mem[rd_ptr];
            rd_ptr      <= (rd_ptr == ADDR_MAX) ? '0 : (rd_ptr + 'd1);
        end
    end

    logic [ADDR_WIDTH-1:0]                      wr_ptr;

    always_ff @(posedge clk)
    begin
        if (!res_n)
        begin
            wr_ptr          <= '0;
        end
        else if (wr_en && (!full || rd_en))
        begin
            mem[wr_ptr]     <= wr_data;
            wr_ptr          <= (wr_ptr == ADDR_MAX) ? '0 : (wr_ptr + 'd1);
        end
    end

    assign empty    = (rd_ptr == wr_ptr);
    assign full     = ((wr_ptr == ADDR_MAX) && (rd_ptr == '0)) || (wr_ptr + 'd1 == rd_ptr);
endmodule
