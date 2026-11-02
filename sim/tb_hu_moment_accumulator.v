`timescale 1ns/1ps
module tb_hu_moment_accumulator;
    localparam integer W = 64;
    localparam integer H = 48;
    reg clk = 1'b0; always #5 clk = ~clk;
    reg rst_n = 1'b0, in_vsync = 1'b0, in_href = 1'b0;
    reg pixel_valid = 1'b0, component_selected = 1'b0;
    reg [10:0] pixel_x = 0, pixel_y = 0;
    wire feature_valid, feature_component_valid;
    wire [63:0] m00,m10,m01,m20,m11,m02,m30,m21,m12,m03;
    wire [31:0] pixel_count;
    wire [10:0] x_min,x_max,y_min,y_max;

    shape_hu_moment_accumulator #(
        .ROI_X_MIN(0), .ROI_Y_MIN(0), .ROI_WIDTH(W), .ROI_HEIGHT(H)
    ) dut (
        .clk(clk), .rst_n(rst_n), .in_vsync(in_vsync), .in_href(in_href),
        .pixel_valid(pixel_valid), .component_selected(component_selected),
        .pixel_x(pixel_x), .pixel_y(pixel_y),
        .feature_valid(feature_valid),
        .feature_component_valid(feature_component_valid),
        .feature_m00(m00), .feature_m10(m10), .feature_m01(m01),
        .feature_m20(m20), .feature_m11(m11), .feature_m02(m02),
        .feature_m30(m30), .feature_m21(m21), .feature_m12(m12),
        .feature_m03(m03), .feature_pixel_count(pixel_count),
        .feature_x_min(x_min), .feature_x_max(x_max),
        .feature_y_min(y_min), .feature_y_max(y_max)
    );

    integer x,y;
    task send_frame;
        begin
            @(negedge clk); in_vsync=1;
            for (y=0; y<H; y=y+1) begin
                for (x=0; x<W; x=x+1) begin
                    @(negedge clk);
                    in_href=1; pixel_valid=1;
                    pixel_x=x; pixel_y=y;
                    component_selected = ((x==16 || x==47) && y>=10 && y<=37) ||
                                         ((y==10 || y==37) && x>=16 && x<=47);
                end
                @(negedge clk); in_href=0; pixel_valid=0;
                component_selected=0;
            end
            @(negedge clk); in_vsync=0; in_href=0; pixel_valid=0;
            component_selected=0;
            repeat(10) @(negedge clk);
        end
    endtask

    always @(posedge clk) if (feature_valid) begin
        $display("HU raw count=%0d m00=%0d m10=%0d m01=%0d bbox=(%0d,%0d)-(%0d,%0d)",
                 pixel_count,m00,m10,m01,x_min,y_min,x_max,y_max);
        if (!feature_component_valid || pixel_count != 116 || m00 != 116 ||
            x_min != 16 || x_max != 47 || y_min != 10 || y_max != 37)
            $display("FAIL Hu accumulator rectangle summary");
        else
            $display("PASS Hu accumulator rectangle summary");
        $finish;
    end

    initial begin
        #12 rst_n=1;
        send_frame();
        repeat(20) @(negedge clk);
        $display("FAIL no feature");
        $finish;
    end
endmodule
