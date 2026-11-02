 
 
 
 
module harris_corner_stream #(
    parameter IMAGE_WIDTH = 1920,
    parameter GRAD_SHIFT = 3,
    parameter [19:0] ENERGY_MIN = 20'd6000,
    parameter [42:0] HARRIS_MIN = 43'd100000000
) (
    input                     clk,
    input                     rst_n,
    input signed [12:0]       gradient_x,
    input signed [12:0]       gradient_y,
    input                     gradient_valid,
    input                     in_vsync,
    input                     in_hsync,
    input                     in_href,
    output reg                response_valid,
    output reg                corner,
    output reg [42:0]         response,
    output reg [10:0]         corner_x,
    output reg [10:0]         corner_y,
    output reg                frame_done
);

    function signed [7:0] quantize_gradient;
        input signed [12:0] value;
        reg signed [12:0] shifted;
        begin
            shifted = value >>> GRAD_SHIFT;
            if (shifted > 13'sd127)
                quantize_gradient = 8'sd127;
            else if (shifted < -13'sd128)
                quantize_gradient = -8'sd128;
            else
                quantize_gradient = shifted[7:0];
        end
    endfunction

    wire signed [7:0] gx_q = quantize_gradient(gradient_x);
    wire signed [7:0] gy_q = quantize_gradient(gradient_y);
    wire signed [15:0] gx_sq = gx_q * gx_q;
    wire signed [15:0] gy_sq = gy_q * gy_q;
    wire signed [15:0] gx_gy = gx_q * gy_q;

    reg [47:0] tensor_data;
    reg        tensor_vsync;
    reg        tensor_hsync;
    reg        tensor_href;

    reg previous_nms_vsync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tensor_data <= 48'd0;
            tensor_vsync <= 1'b0;
            tensor_hsync <= 1'b0;
            tensor_href <= 1'b0;
        end else begin
            tensor_data <= gradient_valid ?
                           {gx_gy[15:0], gy_sq[15:0], gx_sq[15:0]} : 48'd0;
            tensor_vsync <= in_vsync;
            tensor_hsync <= in_hsync;
            tensor_href <= in_href;
        end
    end

    wire [47:0] p00, p01, p02;
    wire [47:0] p10, p11, p12;
    wire [47:0] p20, p21, p22;
    wire window_vsync;
    wire window_hsync;
    wire window_href;
    wire window_valid;
    wire [10:0] window_x;
    wire [10:0] window_y;

    stream_window_3x3 #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .DATA_WIDTH(48),
        .RAM_ADDR_WIDTH(11)
    ) u_tensor_window (
        .clk(clk), .rst_n(rst_n),
        .in_data(tensor_data),
        .in_vsync(tensor_vsync),
        .in_hsync(tensor_hsync),
        .in_href(tensor_href),
        .p00(p00), .p01(p01), .p02(p02),
        .p10(p10), .p11(p11), .p12(p12),
        .p20(p20), .p21(p21), .p22(p22),
        .out_vsync(window_vsync),
        .out_hsync(window_hsync),
        .out_href(window_href),
        .window_valid(window_valid),
        .center_x(window_x),
        .center_y(window_y)
    );

    wire [15:0] xx00 = p00[15:0];
    wire [15:0] xx01 = p01[15:0];
    wire [15:0] xx02 = p02[15:0];
    wire [15:0] xx10 = p10[15:0];
    wire [15:0] xx11 = p11[15:0];
    wire [15:0] xx12 = p12[15:0];
    wire [15:0] xx20 = p20[15:0];
    wire [15:0] xx21 = p21[15:0];
    wire [15:0] xx22 = p22[15:0];
    wire [15:0] yy00 = p00[31:16];
    wire [15:0] yy01 = p01[31:16];
    wire [15:0] yy02 = p02[31:16];
    wire [15:0] yy10 = p10[31:16];
    wire [15:0] yy11 = p11[31:16];
    wire [15:0] yy12 = p12[31:16];
    wire [15:0] yy20 = p20[31:16];
    wire [15:0] yy21 = p21[31:16];
    wire [15:0] yy22 = p22[31:16];
    wire signed [15:0] xy00 = p00[47:32];
    wire signed [15:0] xy01 = p01[47:32];
    wire signed [15:0] xy02 = p02[47:32];
    wire signed [15:0] xy10 = p10[47:32];
    wire signed [15:0] xy11 = p11[47:32];
    wire signed [15:0] xy12 = p12[47:32];
    wire signed [15:0] xy20 = p20[47:32];
    wire signed [15:0] xy21 = p21[47:32];
    wire signed [15:0] xy22 = p22[47:32];

    reg [18:0] sum_xx;
    reg [18:0] sum_yy;
    reg signed [19:0] sum_xy;
    reg sum_valid;
    reg sum_vsync;
    reg sum_hsync;
    reg sum_href;
    reg [10:0] sum_x;
    reg [10:0] sum_y;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum_xx <= 19'd0;
            sum_yy <= 19'd0;
            sum_xy <= 20'sd0;
            sum_valid <= 1'b0;
            sum_vsync <= 1'b0;
            sum_hsync <= 1'b0;
            sum_href <= 1'b0;
            sum_x <= 11'd0;
            sum_y <= 11'd0;
        end else begin
            sum_valid <= window_valid;
            sum_vsync <= window_vsync;
            sum_hsync <= window_hsync;
            sum_href <= window_href;
            sum_x <= window_x;
            sum_y <= window_y;
            if (window_valid) begin
                sum_xx <= {3'd0, xx00} + {3'd0, xx01} + {3'd0, xx02} +
                          {3'd0, xx10} + {3'd0, xx11} + {3'd0, xx12} +
                          {3'd0, xx20} + {3'd0, xx21} + {3'd0, xx22};
                sum_yy <= {3'd0, yy00} + {3'd0, yy01} + {3'd0, yy02} +
                          {3'd0, yy10} + {3'd0, yy11} + {3'd0, yy12} +
                          {3'd0, yy20} + {3'd0, yy21} + {3'd0, yy22};
                sum_xy <= {{4{xy00[15]}}, xy00} + {{4{xy01[15]}}, xy01} +
                          {{4{xy02[15]}}, xy02} + {{4{xy10[15]}}, xy10} +
                          {{4{xy11[15]}}, xy11} + {{4{xy12[15]}}, xy12} +
                          {{4{xy20[15]}}, xy20} + {{4{xy21[15]}}, xy21} +
                          {{4{xy22[15]}}, xy22};
            end else begin
                sum_xx <= 19'd0;
                sum_yy <= 19'd0;
                sum_xy <= 20'sd0;
            end
        end
    end

    wire [19:0] energy_now = {1'b0, sum_xx} + {1'b0, sum_yy};
    wire signed [39:0] xy_product_now = sum_xy * sum_xy;

    reg [37:0] xx_yy_product;
    reg [39:0] xy_xy_product;
    reg [39:0] trace_product;
    reg [19:0] energy_d;
    reg product_valid;
    reg product_vsync;
    reg product_hsync;
    reg product_href;
    reg [10:0] product_x;
    reg [10:0] product_y;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            xx_yy_product <= 38'd0;
            xy_xy_product <= 40'd0;
            trace_product <= 40'd0;
            energy_d <= 20'd0;
            product_valid <= 1'b0;
            product_vsync <= 1'b0;
            product_hsync <= 1'b0;
            product_href <= 1'b0;
            product_x <= 11'd0;
            product_y <= 11'd0;
        end else begin
            xx_yy_product <= sum_xx * sum_yy;
            xy_xy_product <= xy_product_now[39:0];
            trace_product <= energy_now * energy_now;
            energy_d <= energy_now;
            product_valid <= sum_valid;
            product_vsync <= sum_vsync;
            product_hsync <= sum_hsync;
            product_href <= sum_href;
            product_x <= sum_x;
            product_y <= sum_y;
        end
    end

    wire determinant_positive =
        ({2'b00, xx_yy_product} > xy_xy_product);
    wire [39:0] determinant = determinant_positive ?
        ({2'b00, xx_yy_product} - xy_xy_product) : 40'd0;
    reg [39:0] determinant_d;
    reg [39:0] trace_product_d;
    reg determinant_valid_d;
    reg energy_ok_d;
    reg determinant_vsync_d;
    reg determinant_hsync_d;
    reg determinant_href_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            determinant_d <= 40'd0;
            trace_product_d <= 40'd0;
            determinant_valid_d <= 1'b0;
            energy_ok_d <= 1'b0;
            determinant_vsync_d <= 1'b0;
            determinant_hsync_d <= 1'b0;
            determinant_href_d <= 1'b0;
        end else begin
            determinant_d <= determinant;
            trace_product_d <= trace_product;
            determinant_valid_d <= product_valid && determinant_positive;
            energy_ok_d <= (energy_d >= ENERGY_MIN);
            determinant_vsync_d <= product_vsync;
            determinant_hsync_d <= product_hsync;
            determinant_href_d <= product_href;
        end
    end

    reg [42:0] determinant_x25_d;
    reg [42:0] trace_product_ext_d;
    reg scaled_valid_d;
    reg scaled_energy_ok_d;
    reg scaled_vsync_d;
    reg scaled_hsync_d;
    reg scaled_href_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            determinant_x25_d <= 43'd0;
            trace_product_ext_d <= 43'd0;
            scaled_valid_d <= 1'b0;
            scaled_energy_ok_d <= 1'b0;
            scaled_vsync_d <= 1'b0;
            scaled_hsync_d <= 1'b0;
            scaled_href_d <= 1'b0;
        end else begin
            determinant_x25_d <= ({3'd0, determinant_d} << 4) +
                                 ({3'd0, determinant_d} << 3) +
                                 {3'd0, determinant_d};
            trace_product_ext_d <= {3'd0, trace_product_d};
            scaled_valid_d <= determinant_valid_d;
            scaled_energy_ok_d <= energy_ok_d;
            scaled_vsync_d <= determinant_vsync_d;
            scaled_hsync_d <= determinant_hsync_d;
            scaled_href_d <= determinant_href_d;
        end
    end

    wire [42:0] response_now =
        (determinant_x25_d > trace_product_ext_d) ?
        (determinant_x25_d - trace_product_ext_d) : 43'd0;
    reg [42:0] qualified_response;
    reg response_vsync;
    reg response_hsync;
    reg response_href;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            qualified_response <= 43'd0;
            response_vsync <= 1'b0;
            response_hsync <= 1'b0;
            response_href <= 1'b0;
        end else begin
            qualified_response <=
                scaled_valid_d && scaled_energy_ok_d &&
                (response_now >= HARRIS_MIN) ? response_now : 43'd0;
            response_vsync <= scaled_vsync_d;
            response_hsync <= scaled_hsync_d;
            response_href <= scaled_href_d;
        end
    end

    wire [42:0] r00, r01, r02;
    wire [42:0] r10, r11, r12;
    wire [42:0] r20, r21, r22;
    wire nms_window_valid;
    wire nms_vsync;
    wire nms_hsync;
    wire nms_href;
    wire [10:0] nms_x;
    wire [10:0] nms_y;

    stream_window_3x3 #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .DATA_WIDTH(43),
        .RAM_ADDR_WIDTH(11)
    ) u_response_window (
        .clk(clk), .rst_n(rst_n),
        .in_data(qualified_response),
        .in_vsync(response_vsync),
        .in_hsync(response_hsync),
        .in_href(response_href),
        .p00(r00), .p01(r01), .p02(r02),
        .p10(r10), .p11(r11), .p12(r12),
        .p20(r20), .p21(r21), .p22(r22),
        .out_vsync(nms_vsync),
        .out_hsync(nms_hsync),
        .out_href(nms_href),
        .window_valid(nms_window_valid),
        .center_x(nms_x),
        .center_y(nms_y)
    );

     
     
     
    wire nms_peak = (r11 != 43'd0) &&
                    (r11 >  r00) && (r11 >  r01) &&
                    (r11 >  r02) && (r11 >  r10) &&
                    (r11 >= r12) && (r11 >= r20) &&
                    (r11 >= r21) && (r11 >= r22);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            response_valid <= 1'b0;
            corner <= 1'b0;
            response <= 43'd0;
            corner_x <= 11'd0;
            corner_y <= 11'd0;
            previous_nms_vsync <= 1'b0;
            frame_done <= 1'b0;
        end else begin
            previous_nms_vsync <= nms_vsync;
            frame_done <= previous_nms_vsync && !nms_vsync;
            response_valid <= nms_window_valid;
            response <= nms_window_valid ? r11 : 43'd0;
            corner <= nms_window_valid && nms_peak;
            corner_x <= nms_x;
            corner_y <= nms_y;
        end
    end

endmodule
