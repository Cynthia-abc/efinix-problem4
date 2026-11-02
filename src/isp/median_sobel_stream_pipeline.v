 
 
 
module median_sobel_stream_pipeline #(
    parameter IMAGE_WIDTH = 1920,
    parameter THRESHOLD = 8'd64
) (
    input        clk,
    input        rst_n,
    input  [7:0] gray_data,
    input        in_vsync,
    input        in_hsync,
    input        in_href,
    output [7:0] edge_data,
    output       edge_valid,
    output [1:0] edge_dir,
    output signed [12:0] gradient_x,
    output signed [12:0] gradient_y,
    output       out_vsync,
    output       out_hsync,
    output       out_href,
    input  [7:0] threshold_i,
    input        threshold_i_valid
);

    wire [7:0] median_data_stream;
    wire       median_valid;
    wire       median_vsync;
    wire       median_hsync;
    wire       median_href;

    wire [7:0] p00, p01, p02;
    wire [7:0] p10, p11, p12;
    wire [7:0] p20, p21, p22;
    wire       window_b_valid;
    wire       window_b_vsync;
    wire       window_b_hsync;
    wire       window_b_href;
    wire [7:0] sobel_data;
    wire       sobel_valid;
    wire [1:0] sobel_dir;
    wire signed [12:0] sobel_gx;
    wire signed [12:0] sobel_gy;
    wire [7:0] threshold_data;
    wire       threshold_valid;

     
    median_stream_3x3 #(
        .IMAGE_WIDTH(IMAGE_WIDTH)
    ) u_median_stream_3x3 (
        .clk         (clk),
        .rst_n       (rst_n),
        .gray_data   (gray_data),
        .in_vsync    (in_vsync),
        .in_hsync    (in_hsync),
        .in_href     (in_href),
        .median_data (median_data_stream),
        .median_valid(median_valid),
        .out_vsync   (median_vsync),
        .out_hsync   (median_hsync),
        .out_href    (median_href)
    );

     
     
    window_3x3 #(
        .IMAGE_WIDTH(IMAGE_WIDTH)
    ) u_window_b (
        .clk          (clk),
        .rst_n        (rst_n),
        .gray_data    (median_data_stream),
        .in_vsync     (median_vsync),
        .in_hsync     (median_hsync),
        .in_href      (median_href),
        .p00          (p00),
        .p01          (p01),
        .p02          (p02),
        .p10          (p10),
        .p11          (p11),
        .p12          (p12),
        .p20          (p20),
        .p21          (p21),
        .p22          (p22),
        .out_vsync    (window_b_vsync),
        .out_hsync    (window_b_hsync),
        .out_href     (window_b_href),
        .window_valid (window_b_valid)
    );

    sobel_core u_sobel_core (
        .p00          (p00),
        .p01          (p01),
        .p02          (p02),
        .p10          (p10),
        .p11          (p11),
        .p12          (p12),
        .p20          (p20),
        .p21          (p21),
        .p22          (p22),
        .window_valid (window_b_valid),
        .edge_data    (sobel_data),
        .edge_valid   (sobel_valid),
        .edge_dir     (sobel_dir),
        .gradient_x   (sobel_gx),
        .gradient_y   (sobel_gy)
    );

    edge_threshold #(
        .THRESHOLD(THRESHOLD)
    ) u_edge_threshold (
        .edge_data_in  (sobel_data),
        .edge_valid_in (sobel_valid),
        .threshold_i   (threshold_i),
        .threshold_i_valid(threshold_i_valid),
        .edge_data_out (threshold_data),
        .edge_valid_out(threshold_valid)
    );

     
     
    reg [31:0] median_col_count;
    reg [31:0] median_row_count;
    reg        median_previous_href;
    reg        pending_all_median_valid;
    reg        all_median_valid_d;

    wire median_active = median_vsync && median_href;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            median_col_count <= 32'd0;
            median_row_count <= 32'd0;
            median_previous_href <= 1'b0;
            pending_all_median_valid <= 1'b0;
            all_median_valid_d <= 1'b0;
        end else if (!median_vsync) begin
            median_col_count <= 32'd0;
            median_row_count <= 32'd0;
            median_previous_href <= 1'b0;
            pending_all_median_valid <= 1'b0;
            all_median_valid_d <= 1'b0;
        end else begin
            all_median_valid_d <= pending_all_median_valid;
            pending_all_median_valid <= median_active && median_valid &&
                                         (median_row_count >= 32'd4) &&
                                         (median_col_count >= 32'd4);

            if (!median_href) begin
                pending_all_median_valid <= 1'b0;
                median_col_count <= 32'd0;
                median_previous_href <= 1'b0;
                if (median_previous_href)
                    median_row_count <= median_row_count + 1'b1;
            end else begin
                median_previous_href <= 1'b1;
                if (median_col_count < IMAGE_WIDTH - 1)
                    median_col_count <= median_col_count + 1'b1;
                else
                    median_col_count <= 32'd0;
            end
        end
    end

    assign edge_valid = threshold_valid && all_median_valid_d;
    assign edge_data  = edge_valid ? threshold_data : 8'd0;
    assign edge_dir   = sobel_dir;
    assign gradient_x = edge_valid ? sobel_gx : 13'sd0;
    assign gradient_y = edge_valid ? sobel_gy : 13'sd0;
    assign out_vsync  = window_b_vsync;
    assign out_hsync  = window_b_hsync;
    assign out_href   = window_b_href;

endmodule
