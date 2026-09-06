`timescale 1ns/1ps

module grayscale_tb;

    reg        clk;
    reg        rst_n;
    reg  [7:0] in_r;
    reg  [7:0] in_g;
    reg  [7:0] in_b;
    reg        in_vsync;
    reg        in_hsync;
    reg        in_href;

    wire [7:0] gray_data;
    wire       out_vsync;
    wire       out_hsync;
    wire       out_href;

    integer errors;

    grayscale dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_r      (in_r),
        .in_g      (in_g),
        .in_b      (in_b),
        .in_vsync  (in_vsync),
        .in_hsync  (in_hsync),
        .in_href   (in_href),
        .gray_data (gray_data),
        .out_vsync (out_vsync),
        .out_hsync (out_hsync),
        .out_href  (out_href)
    );

    always #5 clk = ~clk;

    task check_color;
        input [7:0] color_r;
        input [7:0] color_g;
        input [7:0] color_b;
        input [7:0] expected;
        input [8*12-1:0] name;
        begin
            in_r = color_r;
            in_g = color_g;
            in_b = color_b;
            #1;
            if (gray_data !== expected) begin
                $display("FAIL %s: got %0d, expected %0d", name, gray_data, expected);
                errors = errors + 1;
            end else begin
                $display("PASS %s: gray=%0d", name, gray_data);
            end
            if ((out_vsync !== in_vsync) ||
                (out_hsync !== in_hsync) ||
                (out_href  !== in_href)) begin
                $display("FAIL %s: synchronization signals were not passed through", name);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        clk      = 1'b0;
        rst_n    = 1'b0;
        in_r     = 8'd0;
        in_g     = 8'd0;
        in_b     = 8'd0;
        in_vsync = 1'b1;
        in_hsync = 1'b1;
        in_href  = 1'b1;
        errors   = 0;

        $dumpfile("simulation/build/grayscale.vcd");
        $dumpvars(0, grayscale_tb);

        #2 rst_n = 1'b1;
        check_color(8'd0,   8'd0,   8'd0,   8'd0,   "black");
        check_color(8'd255, 8'd255, 8'd255, 8'd255, "white");
        check_color(8'd255, 8'd0,   8'd0,   8'd76,  "red");
        check_color(8'd0,   8'd255, 8'd0,   8'd149, "green");
        check_color(8'd0,   8'd0,   8'd255, 8'd28,  "blue");

        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TESTS FAILED: %0d error(s)", errors);

        #1 $finish;
    end

endmodule
