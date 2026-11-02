`timescale 1ns/1ps
module tb_shape_erosion_multi_candidate_top;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0, in_vsync=0, in_href=0, edge_valid=0;
    reg [7:0] edge_data=0;
    wire feature_valid, feature_last, analysis_done, analysis_overrun;
    wire [1:0] feature_index;
    wire [31:0] feature_edge_count, feature_aspect_ratio_x1000, feature_contour_steps_grid;
    wire [10:0] feature_x_min, feature_x_max, feature_y_min, feature_y_max;
    wire feature_contour_valid;
    shape_erosion_multi_candidate_top #(
        .IMAGE_WIDTH(32), .IMAGE_HEIGHT(24), .POOL(4), .TOP_K(3), .LABEL_BITS(8), .MIN_EDGES(1)
    ) dut (
        .clk(clk), .rst_n(rst_n), .in_vsync(in_vsync), .in_href(in_href),
        .edge_valid(edge_valid), .edge_data(edge_data),
        .feature_valid(feature_valid), .feature_last(feature_last),
        .feature_index(feature_index), .feature_edge_count(feature_edge_count),
        .feature_x_min(feature_x_min), .feature_x_max(feature_x_max),
        .feature_y_min(feature_y_min), .feature_y_max(feature_y_max),
        .feature_aspect_ratio_x1000(feature_aspect_ratio_x1000),
        .feature_contour_steps_grid(feature_contour_steps_grid),
        .feature_contour_valid(feature_contour_valid),
        .analysis_done(analysis_done), .analysis_overrun(analysis_overrun)
    );
    integer x,y,seen;
    task drive_pixel;
        input integer px; input integer py;
        integer gx,gy;
        begin
            gx=px/4; gy=py/4;
            edge_valid=0; edge_data=0;
            if ((gx>=1 && gx<=3 && (gy==1 || gy==3)) ||
                (gy>=1 && gy<=3 && (gx==1 || gx==3)) ||
                (gx>=5 && gx<=6 && (gy==3 || gy==4))) begin
                edge_valid=1; edge_data=8'hff;
            end
            @(negedge clk);
        end
    endtask
    always @(posedge clk) if (feature_valid) begin
        $display("source feature idx=%0d count=%0d bbox=%0d,%0d..%0d,%0d aspect=%0d steps_grid=%0d closed=%b",
            feature_index, feature_edge_count, feature_x_min, feature_y_min,
            feature_x_max, feature_y_max, feature_aspect_ratio_x1000,
            feature_contour_steps_grid, feature_contour_valid);
        seen=seen+1;
    end
    initial begin
        seen=0; repeat(3) @(negedge clk); rst_n=1;
        @(negedge clk); in_vsync=1;
        for (y=0;y<24;y=y+1) begin
            in_href=1;
            for (x=0;x<32;x=x+1) drive_pixel(x,y);
            in_href=0; edge_valid=0; edge_data=0; @(negedge clk);
        end
        in_vsync=0; in_href=0;
        repeat(5000) @(negedge clk);
        if (seen != 2) begin $display("FAIL no feature"); $fatal; end
        if (analysis_overrun) begin $display("FAIL overrun"); $fatal; end
        $display("PASS tb_shape_erosion_multi_candidate_top seen=%0d",seen); $finish;
    end
endmodule
