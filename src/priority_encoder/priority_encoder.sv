`default_nettype none

module priority_encoder # (
    parameter INPUT_WIDTH   = 2,
    parameter DATA_WIDTH    = 16,
    parameter OUTPUT_WIDTH  = INPUT_WIDTH
) (
    input wire      [INPUT_WIDTH-1:0]                       in_req,
    input wire      [INPUT_WIDTH-1:0]   [DATA_WIDTH-1:0]    in_data,
    output logic    [OUTPUT_WIDTH-1:0]                      out_grant,
    output logic    [DATA_WIDTH-1:0]                        out_data
);  
    localparam INDEX_WIDTH = (INPUT_WIDTH > 1) ? $clog2(INPUT_WIDTH) : 1;

    always_comb
    begin
        logic [INDEX_WIDTH-1:0] index;
        logic                   has_req;

        index       = '0;
        has_req     = '0;
        out_grant   = '0;

        for (int i = INPUT_WIDTH-1; i >= 0; --i)
        begin
            if (in_req[i])
            begin
                index   = INDEX_WIDTH'(i);
                has_req = '1;
            end
        end
        out_grant[index]    = has_req;
        out_data            = in_data[index];
    end

endmodule
