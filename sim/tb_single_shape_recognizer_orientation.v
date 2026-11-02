`timescale 1ns/1ps

module tb_single_shape_recognizer_orientation;
    localparam WIDTH = 96;
    localparam HEIGHT = 96;
    localparam [1:0] UNKNOWN = 2'b00;
    localparam [1:0] CIRCLE = 2'b01;
    localparam [1:0] RECT = 2'b10;

    reg clk = 1'b0;
    always #5 clk = ~clk;
    reg rst_n = 1'b0;
    reg in_vsync = 1'b0;
    reg in_href = 1'b0;
    reg gradient_valid = 1'b0;
    reg signed [12:0] gradient_x = 13'sd0;
    reg signed [12:0] gradient_y = 13'sd0;
    wire frame_done, target_valid;
    wire [1:0] target_shape;
    wire [10:0] bbox_x_min, bbox_x_max, bbox_y_min, bbox_y_max;
    wire [31:0] target_edge_count;
    wire [3:0] dominant_bin;
    integer x, y;

    single_shape_recognizer_orientation #(
        .IMAGE_WIDTH(WIDTH), .IMAGE_HEIGHT(HEIGHT),
        .ROI_X_MIN(8), .ROI_X_MAX(87),
        .ROI_Y_MIN(8), .ROI_Y_MAX(87),
        .MIN_EDGE_PIXELS(50), .MIN_TARGET_SIZE(24),
        .MAX_TARGET_WIDTH(72), .MAX_TARGET_HEIGHT(72),
        .ROI_BORDER_MARGIN(1), .BBOX_TOLERANCE(2),
        .ANALYSIS_MARGIN(2), .GRADIENT_MIN(14'd96)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .in_vsync(in_vsync), .in_href(in_href),
        .gradient_valid(gradient_valid),
        .gradient_x(gradient_x), .gradient_y(gradient_y),
        .frame_done(frame_done), .target_valid(target_valid),
        .target_shape(target_shape),
        .bbox_x_min(bbox_x_min), .bbox_x_max(bbox_x_max),
        .bbox_y_min(bbox_y_min), .bbox_y_max(bbox_y_max),
        .target_edge_count(target_edge_count),
        .dominant_bin(dominant_bin)
    );

    function integer abs_i;
        input integer value;
        begin abs_i = (value < 0) ? -value : value; end
    endfunction

    task automatic drive_pixel;
        input integer pattern, px, py;
        integer c, s, dx, dy, u, v, rr;
        reg on_u, on_v;
        begin
            c = 256; s = 0;
            case (pattern)
                2: begin c = 247; s = 66; end
                3: begin c = 222; s = 128; end
                4: begin c = 181; s = 181; end
                5: begin c = 128; s = 222; end
                6: begin c = 66; s = 247; end
            endcase
            dx = px - 48;
            dy = py - 48;
            u = dx * c + dy * s;
            v = -dx * s + dy * c;
            on_u = (abs_i(abs_i(u) - 22*256) <= 180) &&
                   (abs_i(v) <= 16*256);
            on_v = (abs_i(abs_i(v) - 16*256) <= 180) &&
                   (abs_i(u) <= 22*256);
            gradient_x = 13'sd0;
            gradient_y = 13'sd0;
            if (pattern >= 1 && pattern <= 6) begin
                if (on_u) begin
                    gradient_x = (u < 0) ? -2*c : 2*c;
                    gradient_y = (u < 0) ? -2*s : 2*s;
                end else if (on_v) begin
                    gradient_x = (v < 0) ? 2*s : -2*s;
                    gradient_y = (v < 0) ? -2*c : 2*c;
                end
            end else if (pattern == 7) begin
                rr = dx*dx + dy*dy;
                if (rr >= 365 && rr <= 440) begin
                    gradient_x = dx * 24;
                    gradient_y = dy * 24;
                end
            end else if (pattern == 8) begin
                rr = dx*dx*16 + dy*dy*25;
                if (rr >= 9300 && rr <= 10700) begin
                    gradient_x = dx * 16;
                    gradient_y = dy * 25;
                end
            end else if (pattern == 9) begin
                if (on_u && u < 0) begin
                    gradient_x = -2*c;
                    gradient_y = -2*s;
                end else if (on_v && v < 0) begin
                    gradient_x = 2*s;
                    gradient_y = -2*c;
                end
            end
        end
    endtask

    task automatic send_frame;
        input integer pattern;
        begin
            @(negedge clk);
            in_vsync = 1'b1;
            for (y = 0; y < HEIGHT; y = y + 1) begin
                in_href = 1'b1;
                gradient_valid = 1'b1;
                for (x = 0; x < WIDTH; x = x + 1) begin
                    drive_pixel(pattern, x, y);
                    @(posedge clk);
                    @(negedge clk);
                end
                in_href = 1'b0;
                gradient_valid = 1'b0;
                gradient_x = 13'sd0;
                gradient_y = 13'sd0;
                repeat (2) begin @(posedge clk); @(negedge clk); end
            end
            in_vsync = 1'b0;
            repeat (20) begin @(posedge clk); @(negedge clk); end
        end
    endtask

    task automatic check_pattern;
        input integer pattern;
        input [1:0] expected;
        begin
            rst_n = 1'b0;
            repeat (3) @(posedge clk);
            @(negedge clk);
            rst_n = 1'b1;
            send_frame(pattern);
            send_frame(pattern);
            if (expected == UNKNOWN) begin
                if (target_valid || target_shape != UNKNOWN)
                    $fatal(1, "pattern %0d false positive shape=%0d", pattern,
                           target_shape);
            end else if (!target_valid || target_shape != expected) begin
                $fatal(1, "pattern %0d expected=%0d got=%0d valid=%0d edges=%0d bin=%0d",
                       pattern, expected, target_shape, target_valid,
                       target_edge_count, dominant_bin);
            end
            $display("PASS pattern=%0d shape=%0d edges=%0d bin=%0d",
                     pattern, target_shape, target_edge_count, dominant_bin);
        end
    endtask

    initial begin
        check_pattern(1, RECT);    // 0 degrees
        check_pattern(2, RECT);    // 15 degrees
        check_pattern(3, RECT);    // 30 degrees
        check_pattern(4, RECT);    // 45 degrees
        check_pattern(5, RECT);    // 60 degrees
        check_pattern(6, RECT);    // 75 degrees
        check_pattern(7, CIRCLE);
        check_pattern(8, CIRCLE);  // mild ellipse / perspective
        check_pattern(9, UNKNOWN); // open L contour
        check_pattern(0, UNKNOWN); // empty ROI
        $display("PASS orientation-based shape recognition");
        $finish;
    end
endmodule
