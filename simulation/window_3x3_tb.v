`timescale 1ns/1ps

module window_3x3_tb;

    reg        clk;
    reg        rst_n;
    reg  [7:0] gray_data;
    reg        in_vsync;
    reg        in_hsync;
    reg        in_href;

    wire [7:0] p00, p01, p02;
    wire [7:0] p10, p11, p12;
    wire [7:0] p20, p21, p22;
    wire       out_vsync;
    wire       out_hsync;
    wire       out_href;
    wire       window_valid;

    integer errors;
    integer valid_count;
    integer sampled_row;
    integer sampled_col;
    reg     sampled_previous_href;
    integer pending_row;
    integer pending_col;
    reg     pending_input_active;
    reg     pending_input_vsync;
    reg     pending_input_hsync;
    reg     pending_input_href;

    window_3x3 #(.IMAGE_WIDTH(5)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .gray_data(gray_data),
        .in_vsync(in_vsync),
        .in_hsync(in_hsync),
        .in_href(in_href),
        .p00(p00), .p01(p01), .p02(p02),
        .p10(p10), .p11(p11), .p12(p12),
        .p20(p20), .p21(p21), .p22(p22),
        .out_vsync(out_vsync),
        .out_hsync(out_hsync),
        .out_href(out_href),
        .window_valid(window_valid)
    );

    always #5 clk = ~clk;

    task check_window;
        input integer index;
        begin
            case (index)
                0: begin
                    if ((p00 !== 1) || (p01 !== 2) || (p02 !== 3) ||
                        (p10 !== 6) || (p11 !== 7) || (p12 !== 8) ||
                        (p20 !== 11) || (p21 !== 12) || (p22 !== 13)) begin
                        $display("FAIL window 1"); errors = errors + 1;
                    end else $display("PASS window 1: 1..3 / 6..8 / 11..13");
                end
                1: begin
                    if ((p00 !== 2) || (p01 !== 3) || (p02 !== 4) ||
                        (p10 !== 7) || (p11 !== 8) || (p12 !== 9) ||
                        (p20 !== 12) || (p21 !== 13) || (p22 !== 14)) begin
                        $display("FAIL window 2"); errors = errors + 1;
                    end else $display("PASS window 2: 2..4 / 7..9 / 12..14");
                end
                2: begin
                    if ((p00 !== 3) || (p01 !== 4) || (p02 !== 5) ||
                        (p10 !== 8) || (p11 !== 9) || (p12 !== 10) ||
                        (p20 !== 13) || (p21 !== 14) || (p22 !== 15)) begin
                        $display("FAIL window 3"); errors = errors + 1;
                    end else $display("PASS window 3: 3..5 / 8..10 / 13..15");
                end
                3: begin
                    if ((p00 !== 6) || (p01 !== 7) || (p02 !== 8) ||
                        (p10 !== 11) || (p11 !== 12) || (p12 !== 13) ||
                        (p20 !== 16) || (p21 !== 17) || (p22 !== 18)) begin
                        $display("FAIL window 4"); errors = errors + 1;
                    end else $display("PASS requested window 3: 6..8 / 11..13 / 16..18");
                end
                8: begin
                    if ((p00 !== 13) || (p01 !== 14) || (p02 !== 15) ||
                        (p10 !== 18) || (p11 !== 19) || (p12 !== 20) ||
                        (p20 !== 23) || (p21 !== 24) || (p22 !== 25)) begin
                        $display("FAIL last window"); errors = errors + 1;
                    end else $display("PASS last window: 13..15 / 18..20 / 23..25");
                end
                default: begin
                    $display("PASS window %0d valid", index + 1);
                end
            endcase
        end
    endtask

    // Check every input cycle, including the boundary cycles before a full window.
    always @(posedge clk) begin
        #1;
        if (!rst_n) begin
            sampled_row = 0;
            sampled_col = 0;
            sampled_previous_href = 1'b0;
            pending_row = 0;
            pending_col = 0;
            pending_input_active = 1'b0;
            pending_input_vsync = 1'b0;
            pending_input_hsync = 1'b0;
            pending_input_href = 1'b0;
        end else if (!in_vsync) begin
            sampled_row = 0;
            sampled_col = 0;
            sampled_previous_href = 1'b0;
            pending_row = 0;
            pending_col = 0;
            pending_input_active = 1'b0;
            pending_input_vsync = 1'b0;
            pending_input_hsync = 1'b0;
            pending_input_href = 1'b0;
            if (window_valid !== 1'b0) begin
                $display("FAIL frame sync boundary: window_valid was high");
                errors = errors + 1;
            end
        end else begin
            // The DUT has one synchronous line-buffer read cycle of latency.
            if (out_vsync !== pending_input_vsync) begin
                $display("FAIL out_vsync delay: got %0d expected %0d",
                         out_vsync, pending_input_vsync);
                errors = errors + 1;
            end
            if (out_hsync !== pending_input_hsync) begin
                $display("FAIL out_hsync delay: got %0d expected %0d",
                         out_hsync, pending_input_hsync);
                errors = errors + 1;
            end
            if (out_href !== pending_input_href) begin
                $display("FAIL out_href delay: got %0d expected %0d",
                         out_href, pending_input_href);
                errors = errors + 1;
            end

            if (pending_input_active) begin
                if (window_valid !== ((pending_row >= 2) && (pending_col >= 2))) begin
                    $display("FAIL boundary row=%0d col=%0d valid=%0d",
                             pending_row, pending_col, window_valid);
                    errors = errors + 1;
                end
                if (window_valid) begin
                    check_window(valid_count);
                    valid_count = valid_count + 1;
                end
            end else if (window_valid !== 1'b0) begin
                $display("FAIL delayed inactive cycle: window_valid was high");
                errors = errors + 1;
            end

            // Capture the current input coordinates for the next output cycle.
            pending_input_vsync = in_vsync;
            pending_input_hsync = in_hsync;
            pending_input_href  = in_href;
            if (in_href) begin
                pending_input_active = 1'b1;
                pending_row = sampled_row;
                pending_col = sampled_col;
                sampled_col = sampled_col + 1;
                sampled_previous_href = 1'b1;
            end else begin
                pending_input_active = 1'b0;
                if (sampled_previous_href) begin
                    sampled_row = sampled_row + 1;
                    sampled_col = 0;
                end
                sampled_previous_href = 1'b0;
            end
        end
    end

    task send_pixel;
        input [7:0] pixel;
        begin
            gray_data = pixel;
            @(negedge clk);
        end
    endtask

    task send_row;
        input [7:0] a;
        input [7:0] b;
        input [7:0] c;
        input [7:0] d;
        input [7:0] e;
        begin
            in_hsync = 1'b1;
            in_href  = 1'b1;
            send_pixel(a); send_pixel(b); send_pixel(c); send_pixel(d); send_pixel(e);
            in_href  = 1'b0;
            in_hsync = 1'b0;
            gray_data = 0;
            @(negedge clk);
        end
    endtask

    initial begin
        $dumpfile("simulation/build/window_3x3.vcd");
        $dumpvars(0, window_3x3_tb);

        clk = 1'b0;
        rst_n = 1'b0;
        gray_data = 0;
        in_vsync = 1'b1;
        in_hsync = 1'b0;
        in_href = 1'b0;
        errors = 0;
        valid_count = 0;
        sampled_row = 0;
        sampled_col = 0;
        sampled_previous_href = 1'b0;
        pending_row = 0;
        pending_col = 0;
        pending_input_active = 1'b0;
        pending_input_vsync = 1'b0;
        pending_input_hsync = 1'b0;
        pending_input_href = 1'b0;

        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        // A separate frame-sync cycle resets the line buffers and counters.
        in_vsync = 1'b0;
        @(negedge clk);
        in_vsync = 1'b1;

        send_row(1, 2, 3, 4, 5);
        send_row(6, 7, 8, 9, 10);
        send_row(11, 12, 13, 14, 15);
        send_row(16, 17, 18, 19, 20);
        send_row(21, 22, 23, 24, 25);

        repeat (2) @(negedge clk);
        if (valid_count !== 9) begin
            $display("FAIL valid window count: got %0d expected 9", valid_count);
            errors = errors + 1;
        end else begin
            $display("PASS valid window count: 9");
        end

        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TESTS FAILED: %0d error(s)", errors);
        $finish;
    end

endmodule
