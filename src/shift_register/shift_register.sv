`default_nettype none

module shift_register 
# (
    parameter SHIFT_REG_WIDTH   = 8,
    parameter DATA_WIDTH        = 16,
    parameter INPUT_WIDTH       = 1
) (
    input   wire                                            clk,
    input   wire                                            res_n,
    input   wire                                            in_valid,
    input   wire    [INPUT_WIDTH-1:0    ] [DATA_WIDTH-1:0]  in_data,
    output  logic   [SHIFT_REG_WIDTH-1:0] [DATA_WIDTH-1:0]  out_data
);
    logic [SHIFT_REG_WIDTH-1:0] [DATA_WIDTH-1:0] shift_reg;
    always_ff @(posedge clk)
    begin
        if (!res_n)
        begin
            shift_reg   <= '0;
        end
        else if (in_valid)
        begin
            shift_reg   <= {in_data, shift_reg[SHIFT_REG_WIDTH-1 : INPUT_WIDTH]};
        end
    end

    assign out_data     = shift_reg;
endmodule
