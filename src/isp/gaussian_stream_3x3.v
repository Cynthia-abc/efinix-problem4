 
 
module gaussian_stream_3x3 #(
    parameter IMAGE_WIDTH = 1920
) (
    input        clk,
    input        rst_n,
    input  [7:0] gray_data,
    input        in_vsync,
    input        in_hsync,
    input        in_href,
    output [7:0] gaussian_data,
    output       gaussian_valid,
    output       out_vsync,
    output       out_hsync,
    output       out_href
);

    wire [7:0] p00, p01, p02;
    wire [7:0] p10, p11, p12;
    wire [7:0] p20, p21, p22;
    wire       window_valid;
    wire       window_vsync;
    wire       window_hsync;
    wire       window_href;
    wire [7:0] gaussian_value;
    wire       gaussian_value_valid;

    window_3x3 #(
        .IMAGE_WIDTH(IMAGE_WIDTH)
    ) u_window_3x3 (
        .clk          (clk),
        .rst_n        (rst_n),
        .gray_data    (gray_data),
        .in_vsync     (in_vsync),
        .in_hsync     (in_hsync),
        .in_href      (in_href),
        .p00          (p00),
        .p01          (p01),
        .p02          (p02),
        .p10          (p10),
        .p11          (p11),
        .p12          (p12),
        .p20          (p20),
        .p21          (p21),
        .p22          (p22),
        .out_vsync    (window_vsync),
        .out_hsync    (window_hsync),
        .out_href     (window_href),
        .window_valid (window_valid)
    );

    gaussian_filter_3x3 u_gaussian_filter_3x3 (
        .p00           (p00),
        .p01           (p01),
        .p02           (p02),
        .p10           (p10),
        .p11           (p11),
        .p12           (p12),
        .p20           (p20),
        .p21           (p21),
        .p22           (p22),
        .window_valid  (window_valid),
        .gaussian_data (gaussian_value),
        .gaussian_valid(gaussian_value_valid)
    );

    assign gaussian_data  = gaussian_value_valid ? gaussian_value : 8'd0;
    assign gaussian_valid = gaussian_value_valid;
    assign out_vsync      = window_vsync;
    assign out_hsync      = window_hsync;
    assign out_href       = window_href;

endmodule
