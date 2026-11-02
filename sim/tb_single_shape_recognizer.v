`timescale 1ns/1ps

module tb_single_shape_recognizer;
    localparam [1:0] SHAPE_UNKNOWN = 2'b00;
    localparam [1:0] SHAPE_CIRCLE  = 2'b01;
    localparam [1:0] SHAPE_RECT    = 2'b10;

    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg rst_n = 1'b0;
    reg in_vsync = 1'b0;
    reg in_hsync = 1'b0;
    reg in_href = 1'b0;
    reg edge_valid = 1'b0;
    reg [7:0] edge_data = 8'd0;
    reg [1:0] edge_dir = 2'b00;
    wire frame_done;
    wire target_valid;
    wire [1:0] target_shape;
    wire [10:0] bbox_x_min, bbox_x_max, bbox_y_min, bbox_y_max;
    wire [31:0] target_edge_count, target_side_hits;

    integer x;
    integer y;
    integer distance_sq;

    single_shape_recognizer #(
        .IMAGE_WIDTH(40),
        .IMAGE_HEIGHT(34),
        .ROI_X_MIN(2),
        .ROI_X_MAX(37),
        .ROI_Y_MIN(2),
        .ROI_Y_MAX(31),
        .MIN_EDGE_PIXELS(12),
        .MIN_TARGET_SIZE(8),
        .MAX_TARGET_WIDTH(40),
        .MAX_TARGET_HEIGHT(34),
        .ROI_BORDER_MARGIN(0),
        .SIDE_BAND(0),
        .BBOX_TOLERANCE(1),
        .STABLE_FRAMES(1),
        .LOST_FRAMES(2)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_vsync(in_vsync),
        .in_hsync(in_hsync),
        .in_href(in_href),
        .edge_valid(edge_valid),
        .edge_data(edge_data),
        .edge_dir(edge_dir),
        .frame_done(frame_done),
        .target_valid(target_valid),
        .target_shape(target_shape),
        .bbox_x_min(bbox_x_min),
        .bbox_x_max(bbox_x_max),
        .bbox_y_min(bbox_y_min),
        .bbox_y_max(bbox_y_max),
        .target_edge_count(target_edge_count),
        .target_side_hits(target_side_hits)
    );

    function automatic pixel_is_edge;
        input integer pattern;
        input integer px;
        input integer py;
        input integer offset;
        integer dx;
        integer dy;
        integer d2;
        begin
            pixel_is_edge = 1'b0;
            case (pattern)
                1: pixel_is_edge =
                    ((((px == 10 + offset) || (px == 29 + offset)) &&
                      (py >= 8) && (py <= 25)) ||
                     (((py == 8) || (py == 25)) &&
                      (px >= 10 + offset) && (px <= 29 + offset)));
                2: begin
                    dx = px - (20 + offset);
                    dy = py - 17;
                    d2 = dx * dx + dy * dy;
                    pixel_is_edge = (d2 >= 72) && (d2 <= 90);
                end
                3: pixel_is_edge =
                    (((px == 10 + offset) && (py >= 8) && (py <= 25)) ||
                     ((py == 25) && (px >= 10 + offset) &&
                      (px <= 29 + offset)));
                4: pixel_is_edge =
                    (((px >= 12) && (px <= 30) &&
                      (py == 6 + (((px - 12) * 2) / 9))) ||
                     ((px >= 8) && (px <= 26) &&
                      (py == 24 + (((px - 8) * 2) / 9))) ||
                     ((py >= 6) && (py <= 24) &&
                      (px == 12 - (((py - 6) * 2) / 9))) ||
                     ((py >= 10) && (py <= 28) &&
                      (px == 30 - (((py - 10) * 2) / 9))));
                default: pixel_is_edge = 1'b0;
            endcase
        end
    endfunction

    function automatic [1:0] pixel_edge_dir;
        input integer pattern;
        input integer px;
        input integer py;
        input integer offset;
        integer dx;
        integer dy;
        integer ax;
        integer ay;
        begin
            dx = px - (20 + offset);
            dy = py - 17;
            ax = (dx < 0) ? -dx : dx;
            ay = (dy < 0) ? -dy : dy;
            case (pattern)
                1, 3: pixel_edge_dir =
                    ((px == 10 + offset) || (px == 29 + offset)) ? 2'b00 : 2'b01;
                2: begin
                    if (ax >= (ay << 1))
                        pixel_edge_dir = 2'b00;
                    else if (ay >= (ax << 1))
                        pixel_edge_dir = 2'b01;
                    else if ((dx < 0) == (dy < 0))
                        pixel_edge_dir = 2'b10;
                    else
                        pixel_edge_dir = 2'b11;
                end
                4: begin
                    if ((py == 6 + (((px - 12) * 2) / 9)) ||
                        (py == 24 + (((px - 8) * 2) / 9)))
                        pixel_edge_dir = 2'b01;
                    else
                        pixel_edge_dir = 2'b00;
                end
                default: pixel_edge_dir = 2'b00;
            endcase
        end
    endfunction

    task automatic send_frame;
        input integer pattern;
        input integer offset;
        begin
            @(negedge clk);
            in_vsync = 1'b1;
            for (y = 0; y < 34; y = y + 1) begin
                in_href = 1'b1;
                for (x = 0; x < 40; x = x + 1) begin
                    edge_valid = pixel_is_edge(pattern, x, y, offset);
                    edge_data = edge_valid ? 8'hff : 8'd0;
                    edge_dir = pixel_edge_dir(pattern, x, y, offset);
                    @(posedge clk);
                    @(negedge clk);
                end
                in_href = 1'b0;
                edge_valid = 1'b0;
                edge_data = 8'd0;
                edge_dir = 2'b00;
                @(posedge clk);
                @(negedge clk);
            end
            in_vsync = 1'b0;
            in_href = 1'b0;
            @(posedge clk);
            #1;
            if (!frame_done) begin
                $display("FAIL missing frame_done pattern=%0d", pattern);
                $finish(1);
            end
        end
    endtask

    task automatic expect_shape;
        input expected_valid;
        input [1:0] expected_shape;
        input [127:0] label;
        begin
            if ((target_valid !== expected_valid) ||
                (expected_valid && (target_shape !== expected_shape))) begin
                $display("FAIL %0s valid=%b shape=%b bbox=(%0d,%0d)-(%0d,%0d) edges=%0d sides=%0d",
                         label, target_valid, target_shape,
                         bbox_x_min, bbox_y_min, bbox_x_max, bbox_y_max,
                         target_edge_count, target_side_hits);
                $finish(1);
            end
        end
    endtask

    initial begin
        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        send_frame(1, 0);
        expect_shape(1'b0, SHAPE_UNKNOWN, "rectangle acquire");
        send_frame(1, 0);
        expect_shape(1'b1, SHAPE_RECT, "rectangle classify");

        send_frame(4, 0);
        send_frame(4, 0);
        expect_shape(1'b1, SHAPE_RECT, "rotated rectangle classify");

        send_frame(2, 0);
        send_frame(2, 0);
        expect_shape(1'b1, SHAPE_CIRCLE, "circle classify");

        send_frame(3, 0);
        send_frame(3, 0);
        expect_shape(1'b1, SHAPE_UNKNOWN, "incomplete rectangle unknown");

        send_frame(1, 0);
        send_frame(1, 3);
        send_frame(1, 6);
        expect_shape(1'b0, SHAPE_UNKNOWN, "moving target rejected");

        send_frame(0, 0);
        send_frame(0, 0);
        expect_shape(1'b0, SHAPE_UNKNOWN, "empty frames clear");

        $display("PASS single_shape_recognizer rectangle/circle/unknown/stability");
        $finish(0);
    end
endmodule
