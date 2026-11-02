 
module grayscale (
    input        clk,         
    input        rst_n,       
    input  [7:0] in_r,        
    input  [7:0] in_g,        
    input  [7:0] in_b,        
    input        in_vsync,    
    input        in_hsync,    
    input        in_href,     
    output [7:0] gray_data,   
    output       out_vsync,   
    output       out_hsync,   
    output       out_href     
);

    wire [15:0] r_ext = {8'd0, in_r};
    wire [15:0] g_ext = {8'd0, in_g};
    wire [15:0] b_ext = {8'd0, in_b};
    wire [15:0] weighted_sum;

     
    assign weighted_sum = (r_ext << 6) + (r_ext << 3) +
                          (r_ext << 2) + r_ext +
                          (g_ext << 7) + (g_ext << 4) +
                          (g_ext << 2) + (g_ext << 1) +
                          (b_ext << 4) + (b_ext << 3) +
                          (b_ext << 2) + b_ext;

    assign gray_data = weighted_sum[15:8];

     
    assign out_vsync = in_vsync;
    assign out_hsync = in_hsync;
    assign out_href  = in_href;

endmodule
