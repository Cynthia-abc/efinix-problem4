`timescale 1ns/1ps

module tb_harris_corner_stream;
    localparam WIDTH = 24;
    localparam HEIGHT = 24;

    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg rst_n = 1'b0;
    reg signed [12:0] gradient_x = 13'sd0;
    reg signed [12:0] gradient_y = 13'sd0;
    reg gradient_valid = 1'b0;
    reg in_vsync = 1'b0;
    reg in_hsync = 1'b0;
    reg in_href = 1'b0;
    wire response_valid;
    wire corner;
    wire [42:0] response;
    wire [10:0] corner_x;
    wire [10:0] corner_y;
    wire frame_done;

    integer x;
    integer y;
    integer hits;
    reg [42:0] peak_response;

    harris_corner_stream #(
        .IMAGE_WIDTH(WIDTH),
        .ENERGY_MIN(20'd4000),
        .HARRIS_MIN(43'd50000000)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .gradient_x(gradient_x), .gradient_y(gradient_y),
        .gradient_valid(gradient_valid),
        .in_vsync(in_vsync), .in_hsync(in_hsync), .in_href(in_href),
        .response_valid(response_valid), .corner(corner),
        .response(response), .corner_x(corner_x), .corner_y(corner_y),
        .frame_done(frame_done)
    );

    always @(posedge clk) begin
        if (response_valid && response > peak_response)
            peak_response <= response;
        if (corner)
            hits <= hits + 1;
    end

    task automatic drive_gradient;
        input integer pattern;
        input integer px;
        input integer py;
        integer dx;
        integer dy;
        integer d2;
        begin
            gradient_x = 13'sd0;
            gradient_y = 13'sd0;
            gradient_valid = 1'b1;
            dx = px - 12;
            dy = py - 12;
            d2 = dx * dx + dy * dy;
            case (pattern)
                // An axis-aligned L corner: orthogonal edge gradients meet.
                1: begin
                    if ((px == 12) && (py >= 8))
                        gradient_x = 13'sd800;
                    if ((py == 12) && (px >= 8))
                        gradient_y = 13'sd800;
                end
                // Two diagonal edge normals form a rotated corner.
                2: begin
                    if ((px + py == 24) && (px >= 8)) begin
                        gradient_x = 13'sd720;
                        gradient_y = 13'sd720;
                    end
                    if ((px - py == 0) && (px >= 8)) begin
                        gradient_x = 13'sd720;
                        gradient_y = -13'sd720;
                    end
                end
                // A straight vertical edge has rank-one structure tensor.
                3: begin
                    if (px == 12)
                        gradient_x = 13'sd800;
                end
                // A gently turning arc. Local gradient direction changes only
                // slightly and must remain below the corner threshold.
                4: begin
                    if ((d2 >= 94) && (d2 <= 106) && (py <= 12)) begin
                        gradient_x = dx * 64;
                        gradient_y = dy * 64;
                    end
                end
                // Low-level deterministic texture/noise.
                5: begin
                    gradient_x = ((px * 17 + py * 11) % 41) - 20;
                    gradient_y = ((px * 7 + py * 19) % 37) - 18;
                end
            endcase
        end
    endtask

    task automatic send_pattern;
        input integer pattern;
        begin
            hits = 0;
            peak_response = 43'd0;
            @(negedge clk);
            in_vsync = 1'b1;
            for (y = 0; y < HEIGHT; y = y + 1) begin
                in_href = 1'b1;
                in_hsync = 1'b1;
                for (x = 0; x < WIDTH; x = x + 1) begin
                    drive_gradient(pattern, x, y);
                    @(posedge clk);
                    @(negedge clk);
                end
                in_href = 1'b0;
                in_hsync = 1'b0;
                gradient_valid = 1'b0;
                gradient_x = 13'sd0;
                gradient_y = 13'sd0;
                repeat (2) begin
                    @(posedge clk);
                    @(negedge clk);
                end
            end
            in_vsync = 1'b0;
            in_href = 1'b0;
            gradient_valid = 1'b0;
            repeat (8) begin
                @(posedge clk);
                @(negedge clk);
            end
            $display("pattern=%0d hits=%0d peak=%0d", pattern, hits,
                     peak_response);
        end
    endtask

    initial begin
        repeat (4) @(posedge clk);
        rst_n = 1'b1;

        send_pattern(1);
        if (hits != 1) begin
            $display("FAIL axis-aligned corner expected 1 event, got %0d", hits);
            $finish(1);
        end

        send_pattern(2);
        if (hits != 1) begin
            $display("FAIL rotated corner expected 1 event, got %0d", hits);
            $finish(1);
        end

        send_pattern(3);
        if (hits != 0) begin
            $display("FAIL straight edge produced %0d corners", hits);
            $finish(1);
        end

        send_pattern(4);
        if (hits != 0) begin
            $display("FAIL circular arc produced %0d corners", hits);
            $finish(1);
        end

        send_pattern(5);
        if (hits != 0) begin
            $display("FAIL weak noise produced %0d corners", hits);
            $finish(1);
        end

        $display("PASS Harris corner/edge/arc/noise separation");
        $finish(0);
    end
endmodule
