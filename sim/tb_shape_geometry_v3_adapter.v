`timescale 1ns/1ps
module tb_shape_geometry_v3_adapter;
    reg clk = 0; always #5 clk = ~clk;
    reg rst_n = 0, in_vsync = 0, in_href = 0;
    reg edge_valid = 0; reg [7:0] edge_data = 0;
    wire result_valid; wire [2:0] result_shape; wire [10:0] x0,x1,y0,y1;
    wire [15:0] result_frame_id;
    wire [31:0] processing_cycles;

    shape_geometry_v3_adapter #(
        .IMAGE_WIDTH(16), .IMAGE_HEIGHT(12),
        .ROI_X_MIN(0), .ROI_Y_MIN(0), .ROI_WIDTH(16), .ROI_HEIGHT(12),
        .MIN_EDGE_COUNT(10), .MIN_CONTOUR_LENGTH(10)
    ) dut (
        .clk(clk), .rst_n(rst_n), .in_vsync(in_vsync), .in_href(in_href),
        .edge_valid(edge_valid), .edge_data(edge_data),
        .result_valid(result_valid), .result_shape(result_shape),
        .result_confidence(), .result_x_min(x0), .result_x_max(x1),
        .result_y_min(y0), .result_y_max(y1), .result_frame_id(result_frame_id),
        .input_frame_id(), .processing_frame_id(), .buffer0_state(),
        .buffer1_state(), .recognition_busy(), .input_overrun(),
        .last_processing_cycles(processing_cycles), .display_valid(), .display_shape(),
        .display_x_min(), .display_x_max(), .display_y_min(), .display_y_max(),
        .display_frame_id()
    );

    integer frame, x, y, results;
    task put_pixel;
        input integer xx, yy;
        begin
            @(negedge clk); in_href=1; edge_valid=1;
            edge_data = (((xx==3 || xx==8) && yy>=2 && yy<=6) ||
                         ((yy==2 || yy==6) && xx>=3 && xx<=8)) ? 8'hff : 8'd0;
        end
    endtask
    task frame_task;
        integer xx, yy;
        begin
            @(negedge clk); in_vsync=1;
            for (yy=0; yy<12; yy=yy+1) begin
                for (xx=0; xx<16; xx=xx+1) begin
                    pixel_x_dummy = xx;
                    pixel_y_dummy = yy;
                    put_pixel(xx,yy);
                end
                @(negedge clk); in_href=0; edge_valid=0; edge_data=0;
                @(negedge clk);
            end
            @(negedge clk); in_vsync=0; in_href=0; edge_valid=0; edge_data=0;
            repeat (60) @(negedge clk);
        end
    endtask
    // The adapter generates x/y internally; these are only task temporaries.
    integer pixel_x_dummy, pixel_y_dummy;
    always @(posedge clk) begin
        if (dut.u_geometry.input_overrun) $display("OVERRUN");
        if (result_valid) begin
        results = results + 1;
        $display("ADAPTER RESULT frame=%0d shape=%0d bbox=(%0d,%0d)-(%0d,%0d)",
                 result_frame_id,result_shape,x0,y0,x1,y1);
        $display("PROCESSING cycles=%0d budget_30fps=4950000", processing_cycles);
        if (processing_cycles >= 32'd4950000) $display("FAIL processing budget");
        end
    end
    initial begin
        results=0; #12 rst_n=1;
        for(frame=0; frame<4; frame=frame+1) frame_task();
        repeat(3000) @(posedge clk);
        if(results < 2) $display("FAIL adapter results=%0d",results);
        else $display("PASS adapter results=%0d",results);
        $finish;
    end
endmodule
