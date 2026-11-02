`timescale 1ns/1ps

module tb_color_edge_overlay_label;
    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg rst_n = 1'b0;
    reg in_vsync = 1'b1;
    reg in_hsync = 1'b1;
    reg in_href = 1'b1;
    reg [7:0] in_r = 8'd0;
    reg [7:0] in_g = 8'd0;
    reg [7:0] in_b = 8'd0;
    reg [7:0] in_gray = 8'd0;
    reg [7:0] edge_data = 8'd0;
    reg edge_valid = 1'b0;
    reg target_valid = 1'b1;
    reg [1:0] target_shape = 2'b01;
    reg [10:0] bbox_x_min = 11'd400;
    reg [10:0] bbox_x_max = 11'd500;
    reg [10:0] bbox_y_min = 11'd400;
    reg [10:0] bbox_y_max = 11'd500;
    wire [7:0] out_r, out_g, out_b;

    color_edge_overlay #(
        .IMAGE_WIDTH(1920),
        .DISPLAY_MODE(1'b1),
        .SHOW_ROI_GUIDE(1'b0)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .in_vsync(in_vsync), .in_hsync(in_hsync), .in_href(in_href),
        .in_r(in_r), .in_g(in_g), .in_b(in_b), .in_gray(in_gray),
        .edge_data(edge_data), .edge_valid(edge_valid),
        .target_valid(target_valid), .target_shape(target_shape),
        .bbox_x_min(bbox_x_min), .bbox_x_max(bbox_x_max),
        .bbox_y_min(bbox_y_min), .bbox_y_max(bbox_y_max),
        .out_r(out_r), .out_g(out_g), .out_b(out_b)
    );

    task check_label;
        input [10:0] px;
        input [10:0] py;
        input expected;
        input [127:0] label;
        begin
            force dut.x_d3 = px;
            force dut.y_d3 = py;
            #1;
            if (dut.label_pixel !== expected) begin
                $display("FAIL %0s x=%0d y=%0d label_pixel=%b",
                         label, px, py, dut.label_pixel);
                $finish(1);
            end
            release dut.x_d3;
            release dut.y_d3;
        end
    endtask

    initial begin
        #1;
        // Row 0, column 1 of the first C is set.
        check_label(11'd36, 11'd24, 1'b1, "first label pixel");
        // These coordinates previously wrapped and repeated every 256x32.
        check_label(11'd292, 11'd24, 1'b0, "horizontal repeat blocked");
        check_label(11'd36, 11'd56, 1'b0, "vertical repeat blocked");
        $display("PASS color_edge_overlay label bounds");
        $finish(0);
    end
endmodule
