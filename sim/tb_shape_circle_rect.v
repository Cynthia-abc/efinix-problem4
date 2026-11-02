`timescale 1ns/1ps
module tb_shape_circle_rect;
    localparam integer W = 64;
    localparam integer H = 48;
    reg clk = 1'b0;
    always #5 clk = ~clk;
    reg rst_n = 1'b0;
    reg in_vsync = 1'b0;
    reg in_href = 1'b0;
    reg edge_valid = 1'b0;
    reg [7:0] edge_data = 8'd0;
    wire result_valid;
    wire [2:0] result_shape;
    wire display_valid;
    wire [2:0] display_shape;
    wire [10:0] result_x_min, result_x_max, result_y_min, result_y_max;
    wire [15:0] result_frame_id;
    wire [31:0] processing_cycles;
    integer shape_mode;
    integer frame_no;
    integer x, y;
    integer results;

    shape_geometry_v3_adapter #(
        .IMAGE_WIDTH(W), .IMAGE_HEIGHT(H),
        .ROI_X_MIN(0), .ROI_Y_MIN(0), .ROI_WIDTH(W), .ROI_HEIGHT(H),
        // Exercise the production-style inner recognition window while the
        // outer ROI remains the full test frame.
        .RECOG_X_MIN(8), .RECOG_Y_MIN(4), .RECOG_WIDTH(48), .RECOG_HEIGHT(40),
        .MIN_EDGE_COUNT(12), .MIN_CONTOUR_LENGTH(12), .STABLE_FRAMES(2)
    ) dut (
        .clk(clk), .rst_n(rst_n), .in_vsync(in_vsync), .in_href(in_href),
        .edge_valid(edge_valid), .edge_data(edge_data),
        .result_valid(result_valid), .result_shape(result_shape),
        .result_confidence(), .result_x_min(result_x_min), .result_x_max(result_x_max),
        .result_y_min(result_y_min), .result_y_max(result_y_max),
        .result_frame_id(result_frame_id), .input_frame_id(), .processing_frame_id(),
        .buffer0_state(), .buffer1_state(), .recognition_busy(), .input_overrun(),
        .last_processing_cycles(processing_cycles), .display_valid(display_valid),
        .display_shape(display_shape), .display_x_min(), .display_x_max(),
        .display_y_min(), .display_y_max(), .display_frame_id()
    );

    function integer is_edge;
        input integer xx;
        input integer yy;
        integer dx, dy, d2;
        begin
            is_edge = 0;
            if (shape_mode == 0) begin
                if (((xx == 16 || xx == 47) && yy >= 10 && yy <= 37) ||
                    ((yy == 10 || yy == 37) && xx >= 16 && xx <= 47))
                    is_edge = 1;
            end else begin
                dx = xx - 32;
                dy = yy - 24;
                d2 = dx*dx + dy*dy;
                if (d2 >= 13*13 && d2 <= 15*15)
                    is_edge = 1;
            end
        end
    endfunction

    task send_frame;
        integer xx, yy;
        begin
            @(negedge clk); in_vsync = 1'b1;
            for (yy = 0; yy < H; yy = yy + 1) begin
                for (xx = 0; xx < W; xx = xx + 1) begin
                    @(negedge clk);
                    in_href = 1'b1;
                    edge_valid = 1'b1;
                    edge_data = is_edge(xx, yy) ? 8'hff : 8'd0;
                end
                @(negedge clk); in_href = 1'b0; edge_valid = 1'b0; edge_data = 8'd0;
            end
            @(negedge clk); in_vsync = 1'b0; in_href = 1'b0;
            edge_valid = 1'b0; edge_data = 8'd0;
            repeat (20000) @(negedge clk);
        end
    endtask

    always @(posedge clk) begin
        if (dut.u_geometry.contour_feature_valid) begin
            $display("FEATURE frame=%0d edges=%0d steps=%0d vertices=%0d convex=%0d concave=%0d dir=%0d ortho=%0d radial=%b err=%0d bbox=(%0d,%0d)-(%0d,%0d)",
                     dut.u_geometry.active_frame_id,
                     dut.u_geometry.active_edge_count,
                     dut.u_geometry.contour_steps,
                     dut.u_geometry.vertex_count,
                     dut.u_geometry.convex_turns,
                     dut.u_geometry.concave_turns,
                     dut.u_geometry.direction_total,
                     dut.u_geometry.orthogonal_count,
                     dut.u_geometry.radial_valid,
                     dut.u_geometry.radial_error_permille,
                     dut.u_geometry.active_x_min, dut.u_geometry.active_y_min,
                     dut.u_geometry.active_x_max, dut.u_geometry.active_y_max);
        end
        if (result_valid) begin
            results = results + 1;
            $display("RESULT shape=%0d frame=%0d bbox=(%0d,%0d)-(%0d,%0d) cycles=%0d",
                     result_shape, result_frame_id, result_x_min, result_y_min,
                     result_x_max, result_y_max, processing_cycles);
        end
    end

    initial begin
        results = 0;
        #20 rst_n = 1'b1;
        shape_mode = 0;
        for (frame_no = 0; frame_no < 4; frame_no = frame_no + 1) send_frame();
        shape_mode = 1;
        for (frame_no = 0; frame_no < 4; frame_no = frame_no + 1) send_frame();
        if (results >= 2) $display("PASS circle/rectangle adapter results=%0d", results);
        else $display("FAIL circle/rectangle adapter results=%0d", results);
        $finish;
    end
endmodule
