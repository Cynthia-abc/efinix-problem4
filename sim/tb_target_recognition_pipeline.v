`timescale 1ns/1ps

module tb_target_recognition_pipeline;
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
    wire signed [12:0] gradient_x;
    wire signed [12:0] gradient_y;
    wire filtered_vsync, filtered_hsync, filtered_href;
    wire corner_event;
    wire [10:0] corner_x, corner_y;
    wire harris_frame_done;
    wire response_valid;
    wire [42:0] response;
    wire target_frame_done;
    wire target_valid;
    wire [1:0] target_shape;
    wire [10:0] bbox_x_min, bbox_x_max, bbox_y_min, bbox_y_max;
    wire [31:0] target_edge_count;
    wire [3:0] target_corner_count;

    integer x;
    integer y;
    integer frame_index;
    integer test_pattern;

    function automatic target_pixel;
        input integer pattern;
        input integer px;
        input integer py;
        integer dx;
        integer dy;
        integer adx;
        integer ady;
        integer c0;
        integer c1;
        integer c2;
        integer c3;
        begin
            dx = px - 32;
            dy = py - 24;
            adx = (dx < 0) ? -dx : dx;
            ady = (dy < 0) ? -dy : dy;
            c0 = 32 * (py - 10) - 7 * (px - 18);
            c1 = -4 * (py - 17) - 21 * (px - 50);
            c2 = -32 * (py - 38) + 7 * (px - 46);
            c3 = 4 * (py - 31) + 21 * (px - 14);
            case (pattern)
                1: target_pixel = (px >= 16) && (px <= 47) &&
                                  (py >= 12) && (py <= 35);
                2: target_pixel = (adx + ady) <= 16;
                3: target_pixel = (c0 >= 0) && (c1 >= 0) &&
                                  (c2 >= 0) && (c3 >= 0);
                4: target_pixel =
                    ((dx * dx * 144) + (dy * dy * 256)) <= 36864;
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

    harris_corner_stream #(
        .IMAGE_WIDTH(WIDTH), .GRAD_SHIFT(3),
        .ENERGY_MIN(20'd6000), .HARRIS_MIN(43'd20000000000)
    ) u_harris (
        .clk(clk), .rst_n(rst_n),
        .gradient_x(gradient_x), .gradient_y(gradient_y),
        .gradient_valid(edge_valid),
        .in_vsync(filtered_vsync), .in_hsync(filtered_hsync),
        .in_href(filtered_href), .response_valid(response_valid),
        .corner(corner_event), .response(response),
        .corner_x(corner_x), .corner_y(corner_y),
        .frame_done(harris_frame_done)
    );

    single_shape_recognizer_harris #(
        .IMAGE_WIDTH(WIDTH), .IMAGE_HEIGHT(HEIGHT),
        .ROI_X_MIN(4), .ROI_X_MAX(59), .ROI_Y_MIN(4), .ROI_Y_MAX(43),
        .MIN_EDGE_PIXELS(20), .MIN_TARGET_SIZE(8),
        .MAX_TARGET_WIDTH(56), .MAX_TARGET_HEIGHT(40),
        .ROI_BORDER_MARGIN(0), .BBOX_TOLERANCE(4),
        .CORNER_MARGIN(4), .CORNER_SEPARATION(4),
        .MAX_CORNERS(8), .STABLE_FRAMES(2), .LOST_FRAMES(3)
    ) u_recognizer (
        .clk(clk), .rst_n(rst_n),
        .edge_vsync(filtered_vsync), .edge_hsync(filtered_hsync),
        .edge_href(filtered_href), .edge_valid(edge_valid),
        .edge_data(edge_data), .edge_dir(edge_dir),
        .corner_event(corner_event),
        .corner_x(corner_x), .corner_y(corner_y),
        .corner_frame_done(harris_frame_done),
        .frame_done(target_frame_done), .target_valid(target_valid),
        .target_shape(target_shape), .bbox_x_min(bbox_x_min),
        .bbox_x_max(bbox_x_max), .bbox_y_min(bbox_y_min),
        .bbox_y_max(bbox_y_max), .target_edge_count(target_edge_count),
        .target_corner_count(target_corner_count)
    );

    always @(posedge clk) begin
        if (corner_event)
            $display("corner frame=%0d at (%0d,%0d) response=%0d",
                     frame_index, corner_x, corner_y, response);
        if (target_frame_done)
            $display("publish frame=%0d ref=%b pending_valid=%b stable=%b quadrants=%b distinct=%0d target=%b shape=%b",
                     frame_index, u_recognizer.reference_valid,
                     u_recognizer.pending_valid, u_recognizer.pending_stable,
                     u_recognizer.pending_quadrants,
                     u_recognizer.distinct_count, target_valid, target_shape);
    end

    task automatic send_target_frame;
        input integer pattern;
        begin
            frame_index = frame_index + 1;
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
                repeat (4) begin
                    @(posedge clk);
                    @(negedge clk);
                end
            end
            in_vsync = 1'b0;
            in_href = 1'b0;
            gray_data = 8'd0;
            repeat (40) begin
                @(posedge clk);
                @(negedge clk);
            end
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
            frame_index = 0;
            repeat (4) @(posedge clk);
            @(negedge clk);
            rst_n = 1'b1;
            repeat (5) send_target_frame(pattern);
            if (!target_valid || target_shape != expected_shape) begin
                $display("FAIL end-to-end pattern=%0d valid=%b shape=%b",
                         pattern, target_valid, target_shape);
                $finish(1);
            end
            $display("PASS end-to-end pattern=%0d shape=%b", pattern,
                     target_shape);
        end
    endtask

    initial begin
        run_case(1, 2'b10);
        run_case(2, 2'b10);
        run_case(3, 2'b10);
        run_case(4, 2'b01);
        $display("PASS end-to-end axis/rotated/perspective/ellipse cases");
        $finish(0);
    end
endmodule
