`timescale 1ns/1ps

module tb_target_recognition_pipeline_v3;
    localparam WIDTH = 64;
    localparam HEIGHT = 48;

    reg clk = 1'b0;
    always #5 clk = ~clk;
    reg rst_n = 1'b0;
    reg [7:0] gray_data = 8'd0;
    reg in_vsync = 1'b0;
    reg in_hsync = 1'b0;
    reg in_href = 1'b0;
    wire [7:0] edge_data;
    wire edge_valid;
    wire [1:0] edge_dir;
    wire signed [12:0] gradient_x, gradient_y;
    wire filtered_vsync, filtered_hsync, filtered_href;
    wire frame_done, target_valid;
    wire [1:0] target_shape;
    wire [10:0] bbox_x_min, bbox_x_max, bbox_y_min, bbox_y_max;
    wire [31:0] target_edge_count;
    wire [3:0] dominant_bin;
    integer x, y, errors = 0;

    function automatic target_pixel;
        input integer pattern, px, py;
        integer dx, dy, adx, ady, c0, c1, c2, c3, c, s, u, v;
        begin
            dx = px - 32;
            dy = py - 24;
            adx = (dx < 0) ? -dx : dx;
            ady = (dy < 0) ? -dy : dy;
            c0 = 32 * (py - 10) - 7 * (px - 18);
            c1 = -4 * (py - 17) - 21 * (px - 50);
            c2 = -32 * (py - 38) + 7 * (px - 46);
            c3 = 4 * (py - 31) + 21 * (px - 14);
            c = 256;
            s = 0;
            case (pattern)
                5: begin c = 247; s = 66; end
                6: begin c = 222; s = 128; end
                7: begin c = 181; s = 181; end
                8: begin c = 128; s = 222; end
            endcase
            u = dx * c + dy * s;
            v = -dx * s + dy * c;
            case (pattern)
                1: target_pixel = (px >= 16) && (px <= 47) &&
                                  (py >= 12) && (py <= 35);
                2: target_pixel = (adx + ady) <= 16;
                3: target_pixel = (c0 >= 0) && (c1 >= 0) &&
                                  (c2 >= 0) && (c3 >= 0);
                4: target_pixel =
                    ((dx * dx * 144) + (dy * dy * 256)) <= 36864;
                5, 6, 7, 8: target_pixel = (u >= -4096) && (u <= 4096) &&
                                             (v >= -2560) && (v <= 2560);
                default: target_pixel = 1'b0;
            endcase
        end
    endfunction

    median_sobel_stream_pipeline #(
        .IMAGE_WIDTH(WIDTH), .THRESHOLD(8'd64)
    ) u_pipeline (
        .clk(clk), .rst_n(rst_n), .gray_data(gray_data),
        .in_vsync(in_vsync), .in_hsync(in_hsync), .in_href(in_href),
        .edge_data(edge_data), .edge_valid(edge_valid), .edge_dir(edge_dir),
        .gradient_x(gradient_x), .gradient_y(gradient_y),
        .out_vsync(filtered_vsync), .out_hsync(filtered_hsync),
        .out_href(filtered_href), .threshold_i(8'd64),
        .threshold_i_valid(1'b1)
    );

    single_shape_recognizer_orientation #(
        .IMAGE_WIDTH(WIDTH), .IMAGE_HEIGHT(HEIGHT),
        .ROI_X_MIN(4), .ROI_X_MAX(59), .ROI_Y_MIN(4), .ROI_Y_MAX(43),
        .MIN_EDGE_PIXELS(20), .MIN_TARGET_SIZE(8),
        .MAX_TARGET_WIDTH(56), .MAX_TARGET_HEIGHT(40),
        .ROI_BORDER_MARGIN(0), .BBOX_TOLERANCE(4),
        .ANALYSIS_MARGIN(2), .GRADIENT_MIN(14'd96)
    ) u_recognizer (
        .clk(clk), .rst_n(rst_n),
        .in_vsync(filtered_vsync), .in_href(filtered_href),
        .gradient_valid(edge_valid),
        .gradient_x(gradient_x), .gradient_y(gradient_y),
        .frame_done(frame_done), .target_valid(target_valid),
        .target_shape(target_shape),
        .bbox_x_min(bbox_x_min), .bbox_x_max(bbox_x_max),
        .bbox_y_min(bbox_y_min), .bbox_y_max(bbox_y_max),
        .target_edge_count(target_edge_count), .dominant_bin(dominant_bin)
    );

    task automatic send_target_frame;
        input integer pattern;
        begin
            @(negedge clk);
            in_vsync = 1'b1;
            for (y = 0; y < HEIGHT; y = y + 1) begin
                in_href = 1'b1;
                in_hsync = 1'b1;
                for (x = 0; x < WIDTH; x = x + 1) begin
                    gray_data = target_pixel(pattern, x, y) ? 8'hff : 8'h00;
                    @(posedge clk);
                    @(negedge clk);
                end
                in_href = 1'b0;
                in_hsync = 1'b0;
                gray_data = 8'd0;
                repeat (4) begin @(posedge clk); @(negedge clk); end
            end
            in_vsync = 1'b0;
            repeat (40) begin @(posedge clk); @(negedge clk); end
        end
    endtask

    task automatic run_case;
        input integer pattern;
        input [1:0] expected_shape;
        begin
            rst_n = 1'b0;
            in_vsync = 1'b0;
            in_href = 1'b0;
            gray_data = 8'd0;
            repeat (4) @(posedge clk);
            @(negedge clk);
            rst_n = 1'b1;
            repeat (5) send_target_frame(pattern);
            if (!target_valid || target_shape != expected_shape) begin
                $display("FAIL pattern=%0d expected=%0d valid=%b shape=%0d edges=%0d bin=%0d bbox=(%0d,%0d)-(%0d,%0d)",
                       pattern, expected_shape, target_valid, target_shape,
                       target_edge_count, dominant_bin,
                       bbox_x_min, bbox_y_min, bbox_x_max, bbox_y_max);
                errors = errors + 1;
            end else begin
                $display("PASS pattern=%0d shape=%0d edges=%0d bin=%0d",
                         pattern, target_shape, target_edge_count, dominant_bin);
            end
        end
    endtask

    initial begin
        run_case(1, 2'b10); // Axis-aligned rectangle
        run_case(2, 2'b10); // 45-degree diamond
        run_case(5, 2'b10); // 15-degree rectangle
        run_case(6, 2'b10); // 30-degree rectangle
        run_case(7, 2'b10); // 45-degree rectangle
        run_case(8, 2'b10); // 60-degree rectangle
        run_case(3, 2'b10); // Mild perspective quadrilateral
        run_case(4, 2'b01); // Ellipse
        if (errors != 0) $fatal(1, "%0d V3 pipeline cases failed", errors);
        $display("PASS V3 median/Sobel/recognizer pipeline");
        $finish;
    end
endmodule
