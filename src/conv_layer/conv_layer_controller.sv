`default_nettype none

module conv_layer_controller
# (
    parameter INPUT_WIDTH       = 1,
    parameter KERNEL_WIDTH      = 9,
    parameter KERNEL_HEIGHT     = 3,
    parameter IMAGE_WIDTH       = 9,
    parameter SHIFT_REG_WIDTH   = (KERNEL_HEIGHT-1) * IMAGE_WIDTH
) (
    input  wire         clk,
    input  wire         res_n,
    input  wire         in_valid,
    output logic        out_buffer_window,
    output logic        out_window_partial_full
);
    typedef enum {
        WINDOW_EMPTY_STATE,
        WINDOW_PARTIAL_STATE,
        WINDOW_FULL_STATE
    } state_t;

    localparam SIZE_COUNT_WIDTH     = $clog2(SHIFT_REG_WIDTH + KERNEL_WIDTH + 1);
    localparam SIZE_COUNT_MAX       = SIZE_COUNT_WIDTH'(SHIFT_REG_WIDTH + KERNEL_WIDTH);
    localparam PARTIAL_THRES        = SIZE_COUNT_WIDTH'((KERNEL_HEIGHT - 1) * IMAGE_WIDTH);
    localparam FULL_THRES           = SIZE_COUNT_MAX;

    state_t                                         window_state_r;
    state_t                                         window_state_c;
    logic                                           buffer_window_c;
    logic                                           buffer_window_r;
    logic                                           window_full;
    logic   [SIZE_COUNT_WIDTH-1:0]                  size_r;
    logic   [SIZE_COUNT_WIDTH-1:0]                  size_c;

    always_comb
    begin
        window_state_c      = window_state_r;
        size_c              = size_r;
        buffer_window_c     = '0;

        if (in_valid)
        begin
            case (window_state_r)
                WINDOW_EMPTY_STATE:
                begin
                    size_c  = size_r + SIZE_COUNT_WIDTH'(INPUT_WIDTH);

                    if (size_c == PARTIAL_THRES)
                    begin
                        window_state_c      = WINDOW_PARTIAL_STATE;
                        buffer_window_c     = '1;
                    end
                end
                WINDOW_PARTIAL_STATE:
                begin
                    size_c  = size_r + SIZE_COUNT_WIDTH'(INPUT_WIDTH);

                    if (size_c == FULL_THRES)
                    begin
                        buffer_window_c     = '1;
                        window_state_c      = WINDOW_FULL_STATE;
                    end
                end
                WINDOW_FULL_STATE:
                begin
                    window_state_c      = WINDOW_PARTIAL_STATE;
                    size_c              = PARTIAL_THRES + SIZE_COUNT_WIDTH'(INPUT_WIDTH);
                end
                default:
                begin
                    window_state_c      = WINDOW_EMPTY_STATE;
                end
            endcase
        end
        else if (window_full)
        begin
            window_state_c  = WINDOW_PARTIAL_STATE;
            size_c          = PARTIAL_THRES;
        end
    end

    always_ff @(posedge clk)
    begin
        if (!res_n)
        begin
            window_state_r      <= WINDOW_EMPTY_STATE;
            buffer_window_r     <= '0;
            size_r              <= '0;
        end
        else
        begin
            window_state_r      <= window_state_c;
            buffer_window_r     <= buffer_window_c;
            size_r              <= size_c;
        end
    end

    assign window_full              = (window_state_r == WINDOW_FULL_STATE);
    assign out_buffer_window        = buffer_window_r;
    assign out_window_partial_full  = (window_state_r == WINDOW_PARTIAL_STATE || window_state_r == WINDOW_FULL_STATE);
endmodule
