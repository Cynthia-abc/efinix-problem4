 
 
 
 
 
module shape_multi_bbox_overlay #(
    parameter integer IMAGE_WIDTH = 1920
) (
    input                    clk,
    input                    rst_n,
    input                    in_vsync,
    input                    in_hsync,
    input                    in_href,
    input      [7:0]         in_r,
    input      [7:0]         in_g,
    input      [7:0]         in_b,
    input      [1:0]         runtime_mode,
    input      [2:0]         box_valid,
    input      [32:0]        box_x_min,
    input      [32:0]        box_x_max,
    input      [32:0]        box_y_min,
    input      [32:0]        box_y_max,
    output reg [7:0]         out_r,
    output reg [7:0]         out_g,
    output reg [7:0]         out_b,
    output reg               out_vsync,
    output reg               out_hsync,
    output reg               out_href
);
    reg [10:0] x_count, y_count;
    reg href_d;
    wire [10:0] x0_min = box_x_min[10:0];
    wire [10:0] x1_min = box_x_min[21:11];
    wire [10:0] x2_min = box_x_min[32:22];
    wire [10:0] x0_max = box_x_max[10:0];
    wire [10:0] x1_max = box_x_max[21:11];
    wire [10:0] x2_max = box_x_max[32:22];
    wire [10:0] y0_min = box_y_min[10:0];
    wire [10:0] y1_min = box_y_min[21:11];
    wire [10:0] y2_min = box_y_min[32:22];
    wire [10:0] y0_max = box_y_max[10:0];
    wire [10:0] y1_max = box_y_max[21:11];
    wire [10:0] y2_max = box_y_max[32:22];

    function automatic box_line;
        input [10:0] px;
        input [10:0] py;
        input [10:0] xmin;
        input [10:0] xmax;
        input [10:0] ymin;
        input [10:0] ymax;
        reg inside_x, inside_y;
        begin
            inside_x = (px >= xmin) && (px <= xmax);
            inside_y = (py >= ymin) && (py <= ymax);
            box_line = inside_x && inside_y &&
                       (((px == xmin) || (px == xmax)) ||
                        ((py == ymin) || (py == ymax)));
        end
    endfunction

    reg box0_pixel, box1_pixel, box2_pixel;
    always @* begin
        box0_pixel = box_valid[0] && box_line(x_count,y_count,x0_min,x0_max,y0_min,y0_max);
        box1_pixel = box_valid[1] && box_line(x_count,y_count,x1_min,x1_max,y1_min,y1_max);
        box2_pixel = box_valid[2] && box_line(x_count,y_count,x2_min,x2_max,y2_min,y2_max);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_count <= 0; y_count <= 0;
            href_d <= 1'b0;
            out_r <= 0; out_g <= 0; out_b <= 0;
            out_vsync <= 0; out_hsync <= 0; out_href <= 0;
        end else begin
            out_vsync <= in_vsync;
            out_hsync <= in_hsync;
            out_href <= in_href;
            href_d <= in_href;
            if (!in_vsync) begin
                x_count <= 0; y_count <= 0;
            end else if (in_href) begin
                if (x_count == IMAGE_WIDTH-1) x_count <= 0;
                else x_count <= x_count + 1'b1;
            end else if (href_d) begin
                x_count <= 0;
                if (y_count < 11'd2047) y_count <= y_count + 1'b1;
            end

            if (box0_pixel) begin
                out_r <= 8'hff; out_g <= 8'h20; out_b <= 8'h20;
            end else if (box1_pixel) begin
                out_r <= 8'h20; out_g <= 8'hff; out_b <= 8'h20;
            end else if (box2_pixel) begin
                out_r <= 8'h20; out_g <= 8'h80; out_b <= 8'hff;
            end else begin
                out_r <= in_r; out_g <= in_g; out_b <= in_b;
            end
        end
    end
endmodule
