`timescale 1ns / 1ps
`default_nettype none

/* NOTE: This file was generated using AI */

module top_level_tb;
    import rmse_pkg::*;

    localparam int NUM_ROWS     = 600;
    localparam int FIRST_ROW    = 45 + RMSE_WINDOW;
    localparam int EXPECTED_S   = NUM_ROWS - FIRST_ROW;

    logic sys_clk_p = 1'b0;
    always #5 sys_clk_p = ~sys_clk_p;
    wire  sys_clk_n = ~sys_clk_p;

    wire led;

    top_level #(
        .NUM_ROWS       (NUM_ROWS),
        .IDLE_CYCLES    (100)
    ) dut (
        .sys_clk_p      (sys_clk_p),
        .sys_clk_n      (sys_clk_n),
        .led            (led)
    );

    int s_seen = 0;

    always @(posedge sys_clk_p) 
    begin
        if (dut.res_n && dut.out_valid) 
        begin
            $display("S for row %0d = %0.4f%s", FIRST_ROW + s_seen, real'(dut.out_data) / 256.0,
                     dut.out_anomaly ? "  ANOMALY" : "");
            s_seen++;
        end

        if (dut.state == 2'd3) 
        begin 
            $display("done: %0d predictions (expect %0d), %0d S values (expect %0d), %0d anomalies, led = %0b",
                     dut.pred_count, NUM_ROWS - 42, dut.s_count, EXPECTED_S, dut.anomaly_count, led);
            $finish;
        end
    end

    initial begin
        #50ms;
        $display("TIMEOUT");
        $finish;
    end
endmodule