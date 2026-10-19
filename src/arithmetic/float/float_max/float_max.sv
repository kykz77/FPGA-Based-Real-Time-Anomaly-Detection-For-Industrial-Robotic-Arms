`default_nettype none

module float_max
    import float_pkg::*;
(
    //verilator lint_off UNUSED
    input  float_pkg::float_t       in_data_a, 
    input  float_pkg::float_t       in_data_b,
    //verilator lint_on UNUSED
    output float_pkg::float_t       out_data
);
    localparam FLOAT_MAG_WIDTH = FLOAT_WIDTH - 1;
    logic [FLOAT_MAG_WIDTH-1:0]     mag_a;
    logic [FLOAT_MAG_WIDTH-1:0]     mag_b;

    assign mag_a    = in_data_a[FLOAT_MAG_WIDTH-1:0];
    assign mag_b    = in_data_b[FLOAT_MAG_WIDTH-1:0];

    assign out_data = (mag_a > mag_b) ? in_data_a : in_data_b;
endmodule
