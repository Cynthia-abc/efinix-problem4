// Combinational RGB888 to 8-bit grayscale converter.
module grayscale (
    input        clk,        // Pixel clock (interface compatibility; no register delay)
    input        rst_n,      // Active-low reset (interface compatibility; no register delay)
    input  [7:0] in_r,       // 8-bit red input
    input  [7:0] in_g,       // 8-bit green input
    input  [7:0] in_b,       // 8-bit blue input
    input        in_vsync,   // Input frame-sync signal
    input        in_hsync,   // Input line-sync signal
    input        in_href,    // Input data-valid signal
    output [7:0] gray_data,  // 8-bit grayscale output
    output       out_vsync,  // Output frame-sync signal
    output       out_hsync,  // Output line-sync signal
    output       out_href    // Output data-valid signal
);

    wire [15:0] r_ext = {8'd0, in_r};
    wire [15:0] g_ext = {8'd0, in_g};
    wire [15:0] b_ext = {8'd0, in_b};
    wire [15:0] weighted_sum;

    // Shift-add arithmetic avoids multiplier/divider hardware in the FPGA.
    assign weighted_sum = (r_ext << 6) + (r_ext << 3) +
                          (r_ext << 2) + r_ext +
                          (g_ext << 7) + (g_ext << 4) +
                          (g_ext << 2) + (g_ext << 1) +
                          (b_ext << 4) + (b_ext << 3) +
                          (b_ext << 2) + b_ext;

    assign gray_data = weighted_sum[15:8];

    // This version is combinational, so timing signals pass through unchanged.
    assign out_vsync = in_vsync;
    assign out_hsync = in_hsync;
    assign out_href  = in_href;

endmodule
