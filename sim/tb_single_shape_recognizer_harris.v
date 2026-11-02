`timescale 1ns/1ps

module tb_single_shape_recognizer_harris;
    localparam [1:0] SHAPE_UNKNOWN = 2'b00;
    localparam [1:0] SHAPE_CIRCLE  = 2'b01;
    localparam [1:0] SHAPE_RECT    = 2'b10;
    localparam WIDTH = 40;
    localparam HEIGHT = 34;

    reg clk = 1'b0;
    always #5 clk = ~clk;
    reg rst_n = 1'b0;
    reg edge_vsync = 1'b0;
    reg edge_hsync = 1'b0;
    reg edge_href = 1'b0;
    reg edge_valid = 1'b0;
    reg [7:0] edge_data = 8'd0;
    reg [1:0] edge_dir = 2'b00;
    reg corner_event = 1'b0;
    reg [10:0] corner_x = 11'd0;
    reg [10:0] corner_y = 11'd0;
    reg corner_frame_done = 1'b0;
    wire frame_done;
    wire target_valid;
    wire [1:0] target_shape;
    wire [10:0] bbox_x_min, bbox_x_max, bbox_y_min, bbox_y_max;
    wire [31:0] target_edge_count;
    wire [3:0] target_corner_count;

    integer x;
    integer y;
    integer dx;
    integer dy;
    integer metric;

    function automatic [1:0] test_edge_dir;
        input integer pattern;
        input integer px;
        input integer py;
        integer lx;
        integer ly;
        integer ax;
        integer ay;
        begin
            lx = px - 20;
            ly = py - 17;
            ax = (lx < 0) ? -lx : lx;
            ay = (ly < 0) ? -ly : ly;
            if (pattern == 2 || pattern == 4) begin
                if (ax >= (ay * 2))
                    test_edge_dir = 2'b00;
                else if (ay >= (ax * 2))
                    test_edge_dir = 2'b01;
                else if ((lx < 0) == (ly < 0))
                    test_edge_dir = 2'b10;
                else
                    test_edge_dir = 2'b11;
            end else if ((px == 10) || (px == 29)) begin
                test_edge_dir = 2'b00;
            end else begin
                test_edge_dir = 2'b01;
            end
        end
    endfunction

    single_shape_recognizer_harris #(
        .IMAGE_WIDTH(WIDTH), .IMAGE_HEIGHT(HEIGHT),
        .ROI_X_MIN(2), .ROI_X_MAX(37),
        .ROI_Y_MIN(2), .ROI_Y_MAX(31),
        .MIN_EDGE_PIXELS(12), .MIN_TARGET_SIZE(8),
        .MAX_TARGET_WIDTH(36), .MAX_TARGET_HEIGHT(30),
        .ROI_BORDER_MARGIN(0), .BBOX_TOLERANCE(2),
        .CORNER_MARGIN(2), .CORNER_SEPARATION(2),
        .MAX_CORNERS(8), .STABLE_FRAMES(1), .LOST_FRAMES(2)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .edge_vsync(edge_vsync), .edge_hsync(edge_hsync),
        .edge_href(edge_href), .edge_valid(edge_valid),
        .edge_data(edge_data),
        .edge_dir(edge_dir),
        .corner_event(corner_event), .corner_x(corner_x),
        .corner_y(corner_y), .corner_frame_done(corner_frame_done),
        .frame_done(frame_done), .target_valid(target_valid),
        .target_shape(target_shape),
        .bbox_x_min(bbox_x_min), .bbox_x_max(bbox_x_max),
        .bbox_y_min(bbox_y_min), .bbox_y_max(bbox_y_max),
        .target_edge_count(target_edge_count),
        .target_corner_count(target_corner_count)
    );

    function automatic is_edge;
        input integer pattern;
        input integer px;
        input integer py;
        integer lx;
        integer ly;
        integer value;
        begin
            lx = px - 20;
            ly = py - 17;
            is_edge = 1'b0;
            case (pattern)
                1: is_edge = ((((px == 10) || (px == 29)) &&
                               (py >= 8) && (py <= 25)) ||
                              (((py == 8) || (py == 25)) &&
                               (px >= 10) && (px <= 29)));
                2: is_edge = ((lx < 0 ? -lx : lx) +
                              (ly < 0 ? -ly : ly)) == 10;
                3: is_edge =
                    ((px >= 10 && px <= 30 &&
                      py == 7 + ((px - 10) / 10)) ||
                     (px >= 8 && px <= 27 &&
                      py == 25 - ((px - 8) / 10)) ||
                     (py >= 7 && py <= 25 &&
                      px == 10 - ((py - 7) / 9)) ||
                     (py >= 9 && py <= 25 &&
                      px == 30 - (((py - 9) * 3) / 16)));
                4: begin
                    value = lx * lx * 64 + ly * ly * 100;
                    is_edge = (value >= 5600) && (value <= 7200);
                end
                5: is_edge = ((px == 10 && py >= 8 && py <= 25) ||
                              (py == 25 && px >= 10 && px <= 29));
            endcase
        end
    endfunction

    task automatic drive_corner;
        input integer pattern;
        input integer px;
        input integer py;
        begin
            corner_event = 1'b0;
            corner_x = px;
            corner_y = py;
            case (pattern)
                1: corner_event =
                    (((px == 10 || px == 11) && (py == 8 || py == 9)) ||
                     ((px == 29 || px == 28) && (py == 8 || py == 9)) ||
                     ((px == 10 || px == 11) && (py == 25 || py == 24)) ||
                     ((px == 29 || px == 28) && (py == 25 || py == 24)));
                2: corner_event = ((px == 20 && py == 7) ||
                                   (px == 30 && py == 17) ||
                                   (px == 20 && py == 27) ||
                                   (px == 10 && py == 17));
                3: corner_event = ((px == 10 && py == 7) ||
                                   (px == 30 && py == 9) ||
                                   (px == 27 && py == 25) ||
                                   (px == 8 && py == 25));
                default: corner_event = 1'b0;
            endcase
        end
    endtask

    task automatic send_frame;
        input integer pattern;
        begin
            @(negedge clk);
            edge_vsync = 1'b1;
            for (y = 0; y < HEIGHT; y = y + 1) begin
                edge_href = 1'b1;
                edge_hsync = 1'b1;
                for (x = 0; x < WIDTH; x = x + 1) begin
                    edge_valid = is_edge(pattern, x, y);
                    edge_data = edge_valid ? 8'hff : 8'd0;
                    edge_dir = test_edge_dir(pattern, x, y);
                    drive_corner(pattern, x, y);
                    @(posedge clk);
                    @(negedge clk);
                end
                edge_href = 1'b0;
                edge_hsync = 1'b0;
                edge_valid = 1'b0;
                edge_data = 8'd0;
                corner_event = 1'b0;
                repeat (2) begin
                    @(posedge clk);
                    @(negedge clk);
                end
            end
            edge_vsync = 1'b0;
            edge_href = 1'b0;
            corner_event = 1'b0;
            repeat (2) begin
                @(posedge clk);
                @(negedge clk);
            end
            corner_frame_done = 1'b1;
            @(posedge clk);
            @(negedge clk);
            corner_frame_done = 1'b0;
            #1;
        end
    endtask

    task automatic reset_dut;
        begin
            rst_n = 1'b0;
            repeat (3) @(posedge clk);
            @(negedge clk);
            rst_n = 1'b1;
        end
    endtask

    task automatic expect_shape;
        input integer pattern;
        input expected_valid;
        input [1:0] expected_shape;
        input [127:0] label;
        begin
            reset_dut;
            send_frame(pattern);
            send_frame(pattern);
            if (target_valid !== expected_valid ||
                (expected_valid && target_shape !== expected_shape)) begin
                $display("FAIL %0s valid=%b shape=%b corners=%0d bbox=(%0d,%0d)-(%0d,%0d) edges=%0d",
                         label, target_valid, target_shape,
                         target_corner_count, bbox_x_min, bbox_y_min,
                         bbox_x_max, bbox_y_max, target_edge_count);
                $finish(1);
            end
            $display("PASS %0s shape=%b corners=%0d", label,
                     target_shape, target_corner_count);
        end
    endtask

    initial begin
        expect_shape(1, 1'b1, SHAPE_RECT, "axis rectangle");
        expect_shape(2, 1'b1, SHAPE_RECT, "rotated rectangle");
        expect_shape(3, 1'b1, SHAPE_RECT, "perspective quadrilateral");
        expect_shape(4, 1'b1, SHAPE_CIRCLE, "ellipse");
        expect_shape(5, 1'b1, SHAPE_UNKNOWN, "open L contour");
        $display("PASS Harris frame-level shape classification");
        $finish(0);
    end
endmodule
