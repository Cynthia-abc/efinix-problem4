`timescale 1ns/1ps
module tb_shape_multi_candidate_feature_pipeline;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0, grid_valid=0, grid_edge=0;
    reg [4:0] grid_edge_weight=0;
    reg grid_row_last=0, grid_frame_last=0;
    reg [2:0] grid_x=0, grid_y=0;
    wire feature_valid, feature_last, analysis_done, overrun;
    wire [1:0] feature_index;
    wire [31:0] feature_edge_count, feature_aspect_ratio_x1000, feature_contour_steps;
    wire [2:0] feature_x_min, feature_x_max, feature_y_min, feature_y_max;
    wire feature_contour_valid;
    shape_multi_candidate_feature_pipeline #(
        .GRID_WIDTH(8), .GRID_HEIGHT(6), .TOP_K(3), .MAX_RUNS_PER_ROW(8),
        .MAX_LABELS(16), .MAX_CONTOUR_STEPS(256), .X_WIDTH(3), .Y_WIDTH(3),
        .ADDR_WIDTH(6)
    ) dut (
        .clk(clk), .rst_n(rst_n), .grid_valid(grid_valid), .grid_edge(grid_edge),
        .grid_edge_weight(grid_edge_weight), .grid_row_last(grid_row_last),
        .grid_frame_last(grid_frame_last), .grid_x(grid_x), .grid_y(grid_y),
        .feature_valid(feature_valid), .feature_last(feature_last),
        .feature_index(feature_index), .feature_edge_count(feature_edge_count),
        .feature_x_min(feature_x_min), .feature_x_max(feature_x_max),
        .feature_y_min(feature_y_min), .feature_y_max(feature_y_max),
        .feature_aspect_ratio_x1000(feature_aspect_ratio_x1000),
        .feature_contour_steps(feature_contour_steps),
        .feature_contour_valid(feature_contour_valid),
        .analysis_done(analysis_done), .overrun(overrun)
    );
    integer x,y,seen;
    task drive_cell;
        input integer px; input integer py;
        begin
            grid_x=px; grid_y=py;
            grid_edge=0; grid_edge_weight=0;
            // Closed 3x3 ring at (1..3,1..3).
            if ((px>=1 && px<=3 && (py==1 || py==3)) ||
                (py>=1 && py<=3 && (px==1 || px==3))) begin
                grid_edge=1; grid_edge_weight=1;
            end
            // Separate 2x2 ring at (5..6,3..4).
            if ((px>=5 && px<=6 && (py==3 || py==4))) begin
                grid_edge=1; grid_edge_weight=1;
            end
            grid_row_last=(px==7);
            grid_frame_last=(px==7 && py==5);
            grid_valid=1;
            @(negedge clk);
            grid_valid=0; grid_row_last=0; grid_frame_last=0;
            grid_edge=0; grid_edge_weight=0;
        end
    endtask
    always @(posedge clk) if (feature_valid) begin
        $display("feature idx=%0d count=%0d bbox=(%0d,%0d)-(%0d,%0d) aspect=%0d steps=%0d closed=%b last=%b",
            feature_index, feature_edge_count, feature_x_min, feature_y_min,
            feature_x_max, feature_y_max, feature_aspect_ratio_x1000,
            feature_contour_steps, feature_contour_valid, feature_last);
        seen=seen+1;
    end
    initial begin
        seen=0;
        repeat(3) @(negedge clk); rst_n=1;
        for (y=0;y<6;y=y+1) begin
            for (x=0;x<8;x=x+1) drive_cell(x,y);
            repeat(2) @(negedge clk);
        end
        repeat(1000) @(negedge clk);
        if (seen < 1) begin $display("FAIL no feature"); $fatal; end
        if (overrun) begin $display("FAIL overrun"); $fatal; end
        $display("PASS tb_shape_multi_candidate_feature_pipeline seen=%0d",seen);
        $finish;
    end
endmodule
