`default_nettype none

/* NOTE: This file was generated using AI */

module top_level
    import cnn_config_pkg::*;
    import rmse_pkg::*;
# (
    parameter string MEM_FILE       = "mem_files/imu_anomaly_example.mem",
    parameter string SQRT_MEM_FILE  = "mem_files/sqrt_table.mem",
    parameter int    NUM_ROWS       = 600,
    parameter int    RESET_CYCLES   = 16,
    parameter int    DRAIN_CYCLES   = 256,
    parameter int    IDLE_CYCLES    = 1_000_000         // ~10 ms at 100 MHz between runs
) (
    input  wire                                         sys_clk_p,
    input  wire                                         sys_clk_n,
    output logic                                        led
);
    // ------------------------------------------------------------------ clock
    wire clk;

`ifdef VERILATOR
    assign clk = sys_clk_p;
`else
    wire clk_ibuf;

    IBUFDS clk_ibufds_I (
        .I      (sys_clk_p),
        .IB     (sys_clk_n),
        .O      (clk_ibuf)
    );

    BUFG clk_bufg_I (
        .I      (clk_ibuf),
        .O      (clk)
    );
`endif

    localparam int NUM_SAMPLES  = NUM_ROWS * NUM_FEATURES;
    localparam int DW           = cnn_config_pkg::DATA_WIDTH;
    localparam int ADDR_W       = $clog2(NUM_SAMPLES);
    localparam int TIMER_W      = $clog2(IDLE_CYCLES + 1);
    localparam int COUNT_W      = $clog2(NUM_ROWS + 1);

    // ------------------------------------------------------------------ test vector ROM
    (* rom_style = "block" *) logic [DW-1:0] rom [NUM_SAMPLES];
    initial $readmemh(MEM_FILE, rom);

    // ------------------------------------------------------------------ run control
    typedef enum logic [1:0] {S_RESET, S_STREAM, S_DRAIN, S_IDLE} state_t;

    state_t                 state   = S_RESET;
    logic [TIMER_W-1:0]     timer   = '0;
    logic [ADDR_W-1:0]      addr    = '0;

    always_ff @(posedge clk)
    begin
        case (state)
            S_RESET:
            begin
                timer   <= timer + 1'b1;
                addr    <= '0;
                if (timer == TIMER_W'(RESET_CYCLES - 1))
                begin
                    timer   <= '0;
                    state   <= S_STREAM;
                end
            end

            S_STREAM:
            begin
                addr    <= addr + 1'b1;
                if (addr == ADDR_W'(NUM_SAMPLES - 1))
                    state   <= S_DRAIN;
            end

            S_DRAIN:
            begin
                timer   <= timer + 1'b1;
                if (timer == TIMER_W'(DRAIN_CYCLES - 1))
                begin
                    timer   <= '0;
                    state   <= S_IDLE;
                end
            end

            S_IDLE:
            begin
                timer   <= timer + 1'b1;
                if (timer == TIMER_W'(IDLE_CYCLES - 1))
                begin
                    timer   <= '0;
                    state   <= S_RESET;
                end
            end

            default:
                state   <= S_RESET;
        endcase
    end

    // ROM read is registered (block RAM), so in_valid / in_index are delayed one cycle to match
    (* mark_debug = "true" *) logic                     res_n       = 1'b0;
    (* mark_debug = "true" *) logic                     in_valid    = 1'b0;
    (* mark_debug = "true" *) logic [ADDR_W-1:0]        in_index    = '0;
                              logic [DW-1:0]            in_data;

    always_ff @(posedge clk)
    begin
        res_n       <= (state != S_RESET);
        in_valid    <= (state == S_STREAM);
        in_index    <= addr;
        in_data     <= rom[addr];
    end

    // ------------------------------------------------------------------ DUT
    (* mark_debug = "true" *) logic                                     pred_valid;
    (* mark_debug = "true" *) logic [NUM_CLASSES-1:0] [DW-1:0]          pred_data;
    (* mark_debug = "true" *) logic                                     out_valid;
    (* mark_debug = "true" *) logic                                     out_anomaly;
    (* mark_debug = "true" *) logic [RMSE_FIX_WIDTH-1:0]                out_data;       // S x 256

    anomaly_detector # (
        .SQRT_MEM_FILE      (SQRT_MEM_FILE)
    ) anomaly_detector_I (
        .clk                (clk),
        .res_n              (res_n),
        .in_valid           (in_valid),
        .in_data            (in_data),
        .pred_valid         (pred_valid),
        .pred_data          (pred_data),
        .out_valid          (out_valid),
        .out_anomaly        (out_anomaly),
        .out_data           (out_data)
    );

    // ------------------------------------------------------------------ counters for the ILA
    // pred_count / s_count / anomaly_count: per run, run_count: which run this is
    (* mark_debug = "true" *) logic [COUNT_W-1:0]   pred_count      = '0;
    (* mark_debug = "true" *) logic [COUNT_W-1:0]   s_count         = '0;
    (* mark_debug = "true" *) logic [COUNT_W-1:0]   anomaly_count   = '0;
    (* mark_debug = "true" *) logic [7:0]           run_count       = '0;
                              logic                 anomaly_seen    = 1'b0;

    always_ff @(posedge clk)
    begin
        if (!res_n)
        begin
            pred_count      <= '0;
            s_count         <= '0;
            anomaly_count   <= '0;
            anomaly_seen    <= 1'b0;
        end
        else
        begin
            if (pred_valid)
                pred_count      <= pred_count + 1'b1;
            if (out_valid)
                s_count         <= s_count + 1'b1;
            if (out_anomaly)
            begin
                anomaly_count   <= anomaly_count + 1'b1;
                anomaly_seen    <= 1'b1;
            end
        end

        if ((state == S_IDLE) && (timer == TIMER_W'(IDLE_CYCLES - 1)))
            run_count   <= run_count + 1'b1;
    end

    // out_anomaly depends on every bit of S, which depends on the whole pipeline, so this
    // output alone keeps the design from being optimised away
    assign led = anomaly_seen;
endmodule