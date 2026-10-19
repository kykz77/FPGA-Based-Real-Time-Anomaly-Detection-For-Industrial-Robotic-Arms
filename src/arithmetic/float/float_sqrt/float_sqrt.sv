`default_nettype none

module float_sqrt
    import float_pkg::*;
# (
    parameter string    MEM_FILE_PATH   = ""
) (
    input  wire                     clk,
    input  wire                     res_n,
    input  wire                     in_valid,
    /* verilator lint_off UNUSEDSIGNAL */
    input  float_pkg::float_t       in_data,
    /* verilator lint_on UNUSEDSIGNAL */
    output logic                    out_valid,
    output float_pkg::float_t       out_data
);
    localparam PARITY_WIDTH     = 1;
    localparam EXP_WIDTH        = float_pkg::EXPONENT_WIDTH;
    localparam EXP_SUM_WIDTH    = EXP_WIDTH + 1;
    localparam MEM_DATA_WIDTH   = float_pkg::MANTISSA_WIDTH;
    localparam ADDR_WIDTH       = MEM_DATA_WIDTH + PARITY_WIDTH;
    localparam MEM_WIDTH        = (1 << ADDR_WIDTH);

    (* rom_style = "block" *) logic [MEM_DATA_WIDTH-1:0] mem [MEM_WIDTH-1:0];

    initial
    begin
        $readmemh(MEM_FILE_PATH, mem);
    end

    logic [EXP_WIDTH-1:0     ]      sqrt_exp;
    logic [MEM_DATA_WIDTH-1:0]      sqrt_mantissa;
    logic [ADDR_WIDTH-1:0    ]      addr;
    logic                           is_zero;
    logic                           is_zero_dly;

    float_pkg::float_t              sqrt;

    always_ff @(posedge clk)
    begin
        if (!res_n)
        begin
            sqrt_mantissa       <= '0;
            sqrt_exp            <= '0;
        end
        else if (in_valid) 
        begin
            sqrt_mantissa       <= mem[addr];
            sqrt_exp            <= EXP_WIDTH'((EXP_SUM_WIDTH'(in_data.exponent) + EXP_SUM_WIDTH'(EXPONENT_BIAS)) >> 1);
        end
    end

    dly_stages # (
        .NUM_DLY_STAGES     (1),
        .DATA_WIDTH         (2)
    ) dly_stages_I (
        .clk                (clk),
        .res_n              (res_n),
        .in_data            ({in_valid,is_zero}),
        .out_data           ({out_valid, is_zero_dly})
    );
    
    assign is_zero          = (in_data.exponent == '0);
    assign addr             = {~in_data.exponent[0], in_data.mantissa};
    assign sqrt.sign        = '0;
    assign sqrt.exponent    = (is_zero_dly) ? '0 : sqrt_exp;
    assign sqrt.mantissa    = (is_zero_dly) ? '0 : sqrt_mantissa;
    assign out_data         = sqrt;
endmodule
