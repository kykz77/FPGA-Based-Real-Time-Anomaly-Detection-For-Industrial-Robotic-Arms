interface dot_product_if 
    import dot_product_pkg::*;
# (
    parameter dot_product_pkg::dp_settings_t SETTINGS = dot_product_pkg::DEFAULT_SETTINGS,
    
    localparam   BANK_WIDTH      = SETTINGS.BANK_WIDTH,
    localparam   INPUT_WIDTH     = SETTINGS.INPUT_WIDTH,
    localparam   DATA_WIDTH      = SETTINGS.DATA_WIDTH
);
    logic [BANK_WIDTH-1:0] [INPUT_WIDTH-1:0] [DATA_WIDTH-1:0]   dp_window;
    logic [BANK_WIDTH-1:0] [INPUT_WIDTH-1:0] [DATA_WIDTH-1:0]   dp_kernel;
    logic [BANK_WIDTH-1:0] [DATA_WIDTH-1:0]                     dp_res;
    logic                                                       dp_grant;
    logic                                                       dp_req;
    logic                                                       dp_res_valid;

    modport master (
        input  dp_grant,
        input  dp_res,
        input  dp_res_valid,
        output dp_window,
        output dp_kernel,
        output dp_req
    );

    modport slave (
        output dp_grant,
        output dp_res,
        output dp_res_valid,
        input  dp_window,
        input  dp_kernel,
        input  dp_req
    );

endinterface : dot_product_if
