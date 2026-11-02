`timescale 1ns/1ps
module tb_shape_run_ccl_topk;
    reg clk = 0; always #5 clk = ~clk;
    reg rst_n = 0;
    reg run_valid = 0;
    reg [8:0] run_x_start = 0, run_x_end = 0;
    reg [8:0] run_y = 0;
    reg [31:0] run_weight = 0;
    reg row_done = 0, frame_done_i = 0;
    wire record_valid, record_last, records_done, overflow;
    wire [1:0] record_index;
    wire [3:0] record_label;
    wire [31:0] record_edge_count, record_aspect_ratio_x1000;
    wire [8:0] record_x_min, record_x_max, record_y_min, record_y_max;

    shape_run_ccl_topk #(
        .MAX_RUNS_PER_ROW(8), .MAX_LABELS(16), .TOP_K(3), .X_WIDTH(9), .Y_WIDTH(9)
    ) dut (
        .clk(clk), .rst_n(rst_n), .run_valid(run_valid),
        .run_x_start(run_x_start), .run_x_end(run_x_end), .run_y(run_y),
        .run_weight(run_weight),
        .row_done(row_done), .frame_done_i(frame_done_i),
        .record_valid(record_valid), .record_last(record_last),
        .record_index(record_index), .record_label(record_label),
        .record_edge_count(record_edge_count), .record_x_min(record_x_min),
        .record_x_max(record_x_max), .record_y_min(record_y_min),
        .record_y_max(record_y_max), .record_aspect_ratio_x1000(record_aspect_ratio_x1000),
        .records_done(records_done), .overflow(overflow)
    );

    task emit_run;
        input integer x0; input integer x1; input integer y0;
        begin
            @(negedge clk);
            run_valid=1; run_x_start=x0; run_x_end=x1; run_y=y0;
            run_weight=x1-x0+1;
            @(negedge clk); run_valid=0;
        end
    endtask
    task finish_row;
        begin
            @(negedge clk); row_done=1;
            @(negedge clk); row_done=0;
        end
    endtask
    task finish_frame;
        begin
            @(negedge clk); frame_done_i=1;
            @(negedge clk); frame_done_i=0;
        end
    endtask

    integer seen;
    always @(posedge clk) begin
        if (record_valid) begin
            $display("record %0d count=%0d bbox=(%0d,%0d)-(%0d,%0d) aspect=%0d",
                record_index, record_edge_count, record_x_min, record_y_min,
                record_x_max, record_y_max, record_aspect_ratio_x1000);
            seen = seen + 1;
        end
    end

    initial begin
        seen=0;
        repeat (3) @(negedge clk);
        rst_n=1;
        // Component A: two touching rows, count 3+4+2=9, bbox 10..13 x 2..4.
        emit_run(10,12,2); finish_row;
        emit_run(10,13,3); finish_row;
        emit_run(11,12,4); finish_row;
        // Component B: count 5, bbox 30..34 x 8..8.
        emit_run(30,34,8); finish_row;
        // Component C: count 4, bbox 50..51 x 12..13.
        emit_run(50,51,12); finish_row;
        emit_run(50,51,13); finish_row;
        finish_frame;
        repeat (30) @(negedge clk);
        if (seen != 3) begin $display("FAIL records=%0d", seen); $fatal; end
        if (overflow) begin $display("FAIL overflow"); $fatal; end
        $display("PASS tb_shape_run_ccl_topk");
        $finish;
    end
endmodule
