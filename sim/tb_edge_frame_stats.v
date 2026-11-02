`timescale 1ns/1ps

module tb_edge_frame_stats;
    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg rst_n = 1'b0;
    reg in_vsync = 1'b0;
    reg in_hsync = 1'b0;
    reg in_href = 1'b0;
    reg edge_valid = 1'b0;
    reg [7:0] edge_data = 8'd0;
    wire frame_done;
    wire bbox_valid;
    wire [10:0] x_min, x_max, y_min, y_max;
    wire [31:0] edge_count;

    edge_frame_stats #(
        .IMAGE_WIDTH(8),
        .IMAGE_HEIGHT(4),
        .MIN_EDGE_PIXELS(3)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_vsync(in_vsync),
        .in_hsync(in_hsync),
        .in_href(in_href),
        .edge_valid(edge_valid),
        .edge_data(edge_data),
        .frame_done(frame_done),
        .bbox_valid(bbox_valid),
        .x_min(x_min),
        .x_max(x_max),
        .y_min(y_min),
        .y_max(y_max),
        .edge_count(edge_count)
    );

    task automatic send_pixel(input integer x, input integer y);
        begin
            edge_valid = ((x == 2 && y == 1) ||
                          (x == 5 && y == 2) ||
                          (x == 3 && y == 3));
            edge_data = edge_valid ? 8'hff : 8'd0;
            @(posedge clk);
        end
    endtask

    integer x, y;
    initial begin
        repeat (2) @(posedge clk);
        rst_n = 1'b1;

        in_vsync = 1'b1;
        for (y = 0; y < 4; y = y + 1) begin
            @(negedge clk);
            in_href = 1'b1;
            for (x = 0; x < 8; x = x + 1) begin
                send_pixel(x, y);
                if (x < 7)
                    @(negedge clk);
            end
            @(negedge clk);
            in_href = 1'b0;
            edge_valid = 1'b0;
            edge_data = 8'd0;
            @(posedge clk);
        end

        @(negedge clk);
        in_vsync = 1'b0;
        in_href = 1'b0;
        @(posedge clk);
        #1;

        if (!frame_done || !bbox_valid ||
            x_min != 11'd2 || x_max != 11'd5 ||
            y_min != 11'd1 || y_max != 11'd3 ||
            edge_count != 32'd3) begin
            $display("FAIL frame_done=%b bbox_valid=%b bbox=(%0d,%0d)-(%0d,%0d) count=%0d",
                     frame_done, bbox_valid, x_min, y_min, x_max, y_max, edge_count);
            $finish(1);
        end

        $display("PASS edge_frame_stats bbox=(%0d,%0d)-(%0d,%0d) count=%0d",
                 x_min, y_min, x_max, y_max, edge_count);
        $finish(0);
    end
endmodule
