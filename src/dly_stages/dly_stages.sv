`default_nettype none

module dly_stages 
# (
    NUM_DLY_STAGES  = 4,
    DATA_WIDTH      = 1
) (
    input wire                          clk,
    input wire                          res_n,
    input wire [DATA_WIDTH-1:0]         in_data,
    output logic [DATA_WIDTH-1:0]       out_data 
);  
    logic [NUM_DLY_STAGES-1:0] [DATA_WIDTH-1:0]     in_data_dly;

    always_ff @(posedge clk)
    begin
        if (!res_n)
        begin
            in_data_dly     <= '0;
        end
        else
        begin
            in_data_dly[0]  <=  in_data;

            for (int i = 1; i < NUM_DLY_STAGES; ++i)
            begin
                in_data_dly[i]      <= in_data_dly[i-1];
            end
        end
    end

    assign out_data = in_data_dly[NUM_DLY_STAGES-1];

endmodule
