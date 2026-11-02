 
 
 
module median_sobel_pipeline #(
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

    wire [7:0] magnitude_window_data;
    wire [7:0] direction_window_data;
    wire       nms_window_valid;
    wire       nms_window_vsync;
    wire       nms_window_hsync;
    wire       nms_window_href;

    wire [7:0] m00, m01, m02;
    wire [7:0] m10, m11, m12;
    wire [7:0] m20, m21, m22;
    wire [7:0] d00, d01, d02;
    wire [7:0] d10, d11, d12;
    wire [7:0] d20, d21, d22;
    wire [7:0] nms_data;
    wire       nms_valid;
    wire [7:0] full_canny_data;
    wire       full_canny_valid;
    wire       full_canny_vsync;
    wire       full_canny_hsync;
    wire       full_canny_href;

    gaussian_stream_3x3 #(
        .IMAGE_WIDTH(IMAGE_WIDTH)
    ) u_gaussian_stream_3x3 (
        .clk         (clk),
        .rst_n       (rst_n),
        .gray_data   (gray_data),
        .in_vsync    (in_vsync),
        .in_hsync    (in_hsync),
        .in_href     (in_href),
        .gaussian_data (median_data_stream),
        .gaussian_valid(median_valid),
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
        .edge_dir     (sobel_dir)
    );

     
    window_3x3 #(
        .IMAGE_WIDTH(IMAGE_WIDTH)
    ) u_nms_magnitude_window (
        .clk          (clk),
        .rst_n        (rst_n),
        .gray_data    (sobel_data),
        .in_vsync     (window_b_vsync),
        .in_hsync     (window_b_hsync),
        .in_href      (window_b_href),
        .p00          (m00),
        .p01          (m01),
        .p02          (m02),
        .p10          (m10),
        .p11          (m11),
        .p12          (m12),
        .p20          (m20),
        .p21          (m21),
        .p22          (m22),
        .out_vsync    (nms_window_vsync),
        .out_hsync    (nms_window_hsync),
        .out_href     (nms_window_href),
        .window_valid (nms_window_valid)
    );

     
     
    window_3x3 #(
        .IMAGE_WIDTH(IMAGE_WIDTH)
    ) u_nms_direction_window (
        .clk          (clk),
        .rst_n        (rst_n),
        .gray_data    ({6'd0, sobel_dir}),
        .in_vsync     (window_b_vsync),
        .in_hsync     (window_b_hsync),
        .in_href      (window_b_href),
        .p00          (d00),
        .p01          (d01),
        .p02          (d02),
        .p10          (d10),
        .p11          (d11),
        .p12          (d12),
        .p20          (d20),
        .p21          (d21),
        .p22          (d22),
        .out_vsync    (),
        .out_hsync    (),
        .out_href     (),
        .window_valid ()
    );

    canny_nms_core u_canny_nms_core (
        .m00          (m00),
        .m01          (m01),
        .m02          (m02),
        .m10          (m10),
        .m11          (m11),
        .m12          (m12),
        .m20          (m20),
        .m21          (m21),
        .m22          (m22),
        .direction    (d11[1:0]),
        .window_valid (nms_window_valid),
        .edge_data    (nms_data),
        .edge_valid   (nms_valid)
    );


     
     
    reg [31:0] median_col_count;
    reg [31:0] median_row_count;
    reg        median_previous_href;
    reg        pending_all_median_valid;
    reg        all_median_valid_d;
    reg        all_median_valid_nms_d;
    wire median_active = median_vsync && median_href;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            median_col_count          <= 32'd0;
            median_row_count          <= 32'd0;
            median_previous_href      <= 1'b0;
            pending_all_median_valid  <= 1'b0;
            all_median_valid_d        <= 1'b0;
            all_median_valid_nms_d    <= 1'b0;
        end else if (!median_vsync) begin
            median_col_count          <= 32'd0;
            median_row_count          <= 32'd0;
            median_previous_href      <= 1'b0;
            pending_all_median_valid  <= 1'b0;
            all_median_valid_d        <= 1'b0;
            all_median_valid_nms_d    <= 1'b0;
        end else begin
            all_median_valid_d     <= pending_all_median_valid;
            all_median_valid_nms_d <= all_median_valid_d;
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

    wire full_nms_valid = nms_valid && all_median_valid_nms_d;

    canny_multiround_frame #(
        .IMAGE_WIDTH  (IMAGE_WIDTH),
        .IMAGE_HEIGHT (1080),
        .WORK_WIDTH   (IMAGE_WIDTH / 2),
        .WORK_HEIGHT  (1080 / 2),
        .THRESHOLD    (THRESHOLD),
        .MAX_ROUNDS   (16)
    ) u_canny_multiround_frame (
        .clk                (clk),
        .rst_n              (rst_n),
        .nms_data           (nms_data),
        .nms_valid          (full_nms_valid),
        .in_vsync           (nms_window_vsync),
        .in_hsync           (nms_window_hsync),
        .in_href            (nms_window_href),
        .threshold_i        (threshold_i),
        .threshold_i_valid  (threshold_i_valid),
        .edge_data          (full_canny_data),
        .edge_valid         (full_canny_valid),
        .out_vsync          (full_canny_vsync),
        .out_hsync          (full_canny_hsync),
        .out_href           (full_canny_href)
    );

    assign edge_valid = full_canny_valid;
    assign edge_data  = edge_valid ? full_canny_data : 8'd0;
    assign out_vsync  = full_canny_vsync;
    assign out_hsync  = full_canny_hsync;
    assign out_href   = full_canny_href;

endmodule




