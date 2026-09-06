`timescale 1ns/1ps

module sobel_core_tb;

    reg  [7:0] p00;
    reg  [7:0] p01;
    reg  [7:0] p02;
    reg  [7:0] p10;
    reg  [7:0] p11;
    reg  [7:0] p12;
    reg  [7:0] p20;
    reg  [7:0] p21;
    reg  [7:0] p22;
    reg        window_valid;
    wire [7:0] edge_data;
    wire       edge_valid;
    integer    errors;

    sobel_core dut (
        .p00(p00), .p01(p01), .p02(p02),
        .p10(p10), .p11(p11), .p12(p12),
        .p20(p20), .p21(p21), .p22(p22),
        .window_valid(window_valid),
        .edge_data(edge_data),
        .edge_valid(edge_valid)
    );

    task check_result;
        input [7:0] expected_edge;
        input       expected_valid;
        input [255:0] test_name;
        begin
            #1;
            if ((edge_data !== expected_edge) || (edge_valid !== expected_valid)) begin
                $display("FAIL %0s: edge=%0d valid=%0d expected edge=%0d valid=%0d",
                         test_name, edge_data, edge_valid, expected_edge, expected_valid);
                errors = errors + 1;
            end else begin
                $display("PASS %0s: edge=%0d valid=%0d", test_name, edge_data, edge_valid);
            end
        end
    endtask

    initial begin
        $dumpfile("simulation/build/sobel_core.vcd");
        $dumpvars(0, sobel_core_tb);
        errors = 0;

        // Uniform window: all gradients are zero.
        p00 = 8'd100; p01 = 8'd100; p02 = 8'd100;
        p10 = 8'd100; p11 = 8'd100; p12 = 8'd100;
        p20 = 8'd100; p21 = 8'd100; p22 = 8'd100;
        window_valid = 1'b1;
        check_result(8'd0, 1'b1, "uniform window");

        // Right side is bright: horizontal gradient saturates.
        p00 = 8'd0; p01 = 8'd0; p02 = 8'd255;
        p10 = 8'd0; p11 = 8'd0; p12 = 8'd255;
        p20 = 8'd0; p21 = 8'd0; p22 = 8'd255;
        window_valid = 1'b1;
        check_result(8'd255, 1'b1, "left zero right 255");

        // Bottom side is bright: vertical gradient saturates.
        p00 = 8'd0; p01 = 8'd0; p02 = 8'd0;
        p10 = 8'd0; p11 = 8'd0; p12 = 8'd0;
        p20 = 8'd255; p21 = 8'd255; p22 = 8'd255;
        window_valid = 1'b1;
        check_result(8'd255, 1'b1, "top zero bottom 255");

        // Invalid window must suppress the output-valid indication.
        window_valid = 1'b0;
        check_result(8'd0, 1'b0, "invalid window");

        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TESTS FAILED: %0d error(s)", errors);
        $finish;
    end

endmodule
