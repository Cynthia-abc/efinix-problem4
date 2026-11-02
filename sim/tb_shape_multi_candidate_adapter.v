`timescale 1ns/1ps
module tb_shape_multi_candidate_adapter;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0, in_vsync=0, in_href=0, edge_valid=0;
    reg [7:0] edge_data=0;
    wire record_valid, record_last, records_done, ccl_overflow;
    wire [1:0] record_index;
    wire [3:0] record_label;
    wire [31:0] record_edge_count, record_aspect_ratio_x1000;
    wire [10:0] record_x_min, record_x_max, record_y_min, record_y_max;
    shape_multi_candidate_adapter #(
        .IMAGE_WIDTH(8), .IMAGE_HEIGHT(8), .POOL(2), .TOP_K(3),
        .MAX_RUNS_PER_ROW(8), .MAX_LABELS(16)
    ) dut (
        .clk(clk), .rst_n(rst_n), .in_vsync(in_vsync), .in_href(in_href),
        .edge_valid(edge_valid), .edge_data(edge_data),
        .record_valid(record_valid), .record_last(record_last),
        .record_index(record_index), .record_label(record_label),
        .record_edge_count(record_edge_count), .record_x_min(record_x_min),
        .record_x_max(record_x_max), .record_y_min(record_y_min),
        .record_y_max(record_y_max),
        .record_aspect_ratio_x1000(record_aspect_ratio_x1000),
        .records_done(records_done), .ccl_overflow(ccl_overflow)
    );
    integer x,y,seen;
    task drive_pixel;
        input integer px; input integer py;
        begin
            edge_valid = 1'b0; edge_data=0;
            // Pooled cells (0,0)-(1,1) and (3,2) are two components.
            if ((px<4 && py<4) || (px>=6 && py>=4)) begin
                edge_valid=1'b1; edge_data=8'hff;
            end
            @(negedge clk);
        end
    endtask
    always @(posedge clk) if (record_valid) begin
        $display("idx=%0d count=%0d bbox=%0d,%0d..%0d,%0d ratio=%0d last=%b",
            record_index, record_edge_count, record_x_min, record_y_min,
            record_x_max, record_y_max, record_aspect_ratio_x1000, record_last);
        seen=seen+1;
    end
    always @(posedge clk) begin
        if (dut.grid_valid_r) $display("grid x=%0d y=%0d edge=%b weight=%0d rowlast=%b framelast=%b",dut.grid_x_r,dut.grid_y_r,dut.grid_edge_r,dut.grid_edge_weight_r,dut.grid_row_last_r,dut.grid_frame_last_r);
        if (dut.run_valid) $display("run %0d..%0d y=%0d w=%0d ww=%0d",dut.run_x_start,dut.run_x_end,dut.run_y,dut.run_weight,dut.u_encoder.work_weight);
        if (dut.row_done) $display("rowdone");
        if (dut.frame_done_i) $display("framedone");
        if (dut.u_topk.run_valid || dut.u_topk.row_done) $display("ccl run=%b row=%b prev=%0d curr=%0d p0=%0d..%0d p1=%0d..%0d l0=%0d l1=%0d",dut.u_topk.run_valid,dut.u_topk.row_done,dut.u_topk.prev_count,dut.u_topk.curr_count,dut.u_topk.prev_start[0],dut.u_topk.prev_end[0],dut.u_topk.prev_start[1],dut.u_topk.prev_end[1],dut.u_topk.prev_label[0],dut.u_topk.prev_label[1]);
    end
    initial begin
        seen=0;
        repeat(3) @(negedge clk); rst_n=1;
        @(negedge clk); in_vsync=1;
        for (y=0;y<8;y=y+1) begin
            in_href=1;
            for (x=0;x<8;x=x+1) drive_pixel(x,y);
            in_href=0; edge_valid=0; edge_data=0;
            @(negedge clk);
        end
        in_vsync=0; in_href=0;
        repeat(30) @(negedge clk);
        if (seen != 2) begin $display("FAIL seen=%0d",seen); $fatal; end
        if (ccl_overflow) begin $display("FAIL overflow"); $fatal; end
        $display("PASS tb_shape_multi_candidate_adapter"); $finish;
    end
endmodule
