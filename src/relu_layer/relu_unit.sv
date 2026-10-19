`default_nettype none

module relu_unit # (
    parameter DATA_WIDTH = 16
) (
    input wire [DATA_WIDTH-1:0]     in_data,
    output logic [DATA_WIDTH-1:0]   out_data
);
    assign out_data = (in_data[DATA_WIDTH-1]) ? '0 : in_data;

endmodule
