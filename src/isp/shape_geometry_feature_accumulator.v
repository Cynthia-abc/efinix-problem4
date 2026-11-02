 
 
 
 
 
 
module shape_geometry_feature_accumulator #(
    parameter integer IMAGE_WIDTH  = 1920,
    parameter integer IMAGE_HEIGHT = 1080,
    parameter integer X_WIDTH = 11,
    parameter integer Y_WIDTH = 11
) (
    input                   clk,
    input                   rst_n,
    input                   in_vsync,
    input                   in_href,
    input                   pixel_valid,
    input                   component_selected,
    input      [X_WIDTH-1:0] pixel_x,
    input      [Y_WIDTH-1:0] pixel_y,
     
    input      [1:0]        direction_bin,
     
    input      [1:0]        turn_type,
    input                   contour_closed,
    output reg              feature_valid,
    output reg              feature_component_valid,
    output reg [31:0]       feature_edge_count,
    output reg [31:0]       feature_direction_total,
    output reg [31:0]       feature_orthogonal_count,
    output reg [31:0]       feature_vertex_count,
    output reg [31:0]       feature_convex_turns,
    output reg [31:0]       feature_concave_turns,
    output reg [31:0]       feature_contour_length,
    output reg              feature_contour_closed,
    output reg [X_WIDTH-1:0] feature_x_min,
    output reg [X_WIDTH-1:0] feature_x_max,
    output reg [Y_WIDTH-1:0] feature_y_min,
    output reg [Y_WIDTH-1:0] feature_y_max,
    output reg [31:0]       feature_dir_bin0,
    output reg [31:0]       feature_dir_bin1,
    output reg [31:0]       feature_dir_bin2,
    output reg [31:0]       feature_dir_bin3
);
    reg previous_vsync;
    reg have_component;
    reg [31:0] edge_count;
    reg [31:0] direction_total;
    reg [31:0] dir_bin0, dir_bin1, dir_bin2, dir_bin3;
    reg [31:0] vertex_count;
    reg [31:0] convex_turns;
    reg [31:0] concave_turns;
    reg [31:0] contour_length;
    reg contour_closed_seen;
    reg [X_WIDTH-1:0] x_min, x_max;
    reg [Y_WIDTH-1:0] y_min, y_max;

    wire frame_end = previous_vsync && !in_vsync;
    wire selected_pixel = in_vsync && in_href && pixel_valid &&
                          component_selected;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            previous_vsync <= 1'b0;
            have_component <= 1'b0;
            edge_count <= 32'd0;
            direction_total <= 32'd0;
            dir_bin0 <= 32'd0;
            dir_bin1 <= 32'd0;
            dir_bin2 <= 32'd0;
            dir_bin3 <= 32'd0;
            vertex_count <= 32'd0;
            convex_turns <= 32'd0;
            concave_turns <= 32'd0;
            contour_length <= 32'd0;
            contour_closed_seen <= 1'b0;
            x_min <= {X_WIDTH{1'b1}};
            x_max <= {X_WIDTH{1'b0}};
            y_min <= {Y_WIDTH{1'b1}};
            y_max <= {Y_WIDTH{1'b0}};
            feature_valid <= 1'b0;
            feature_component_valid <= 1'b0;
            feature_edge_count <= 32'd0;
            feature_direction_total <= 32'd0;
            feature_orthogonal_count <= 32'd0;
            feature_vertex_count <= 32'd0;
            feature_convex_turns <= 32'd0;
            feature_concave_turns <= 32'd0;
            feature_contour_length <= 32'd0;
            feature_contour_closed <= 1'b0;
            feature_x_min <= {X_WIDTH{1'b0}};
            feature_x_max <= {X_WIDTH{1'b0}};
            feature_y_min <= {Y_WIDTH{1'b0}};
            feature_y_max <= {Y_WIDTH{1'b0}};
            feature_dir_bin0 <= 32'd0;
            feature_dir_bin1 <= 32'd0;
            feature_dir_bin2 <= 32'd0;
            feature_dir_bin3 <= 32'd0;
        end else begin
            previous_vsync <= in_vsync;
            feature_valid <= 1'b0;

            if (selected_pixel) begin
                have_component <= 1'b1;
                if (edge_count != 32'hffff_ffff)
                    edge_count <= edge_count + 1'b1;
                if (direction_total != 32'hffff_ffff)
                    direction_total <= direction_total + 1'b1;
                case (direction_bin)
                    2'd0: if (dir_bin0 != 32'hffff_ffff) dir_bin0 <= dir_bin0 + 1'b1;
                    2'd1: if (dir_bin1 != 32'hffff_ffff) dir_bin1 <= dir_bin1 + 1'b1;
                    2'd2: if (dir_bin2 != 32'hffff_ffff) dir_bin2 <= dir_bin2 + 1'b1;
                    default: if (dir_bin3 != 32'hffff_ffff) dir_bin3 <= dir_bin3 + 1'b1;
                endcase
                if (turn_type == 2'b01) begin
                    if (convex_turns != 32'hffff_ffff) convex_turns <= convex_turns + 1'b1;
                    if (vertex_count != 32'hffff_ffff) vertex_count <= vertex_count + 1'b1;
                end else if (turn_type == 2'b10) begin
                    if (concave_turns != 32'hffff_ffff) concave_turns <= concave_turns + 1'b1;
                    if (vertex_count != 32'hffff_ffff) vertex_count <= vertex_count + 1'b1;
                end
                if (contour_closed)
                    contour_closed_seen <= 1'b1;
                if (contour_length != 32'hffff_ffff)
                    contour_length <= contour_length + 1'b1;
                if (pixel_x < x_min) x_min <= pixel_x;
                if (pixel_x > x_max) x_max <= pixel_x;
                if (pixel_y < y_min) y_min <= pixel_y;
                if (pixel_y > y_max) y_max <= pixel_y;
            end

            if (frame_end) begin
                feature_valid <= 1'b1;
                feature_component_valid <= have_component;
                feature_edge_count <= edge_count;
                feature_direction_total <= direction_total;
                 
                feature_orthogonal_count <=
                    ((dir_bin0 + dir_bin2) >= (dir_bin1 + dir_bin3)) ?
                    (dir_bin0 + dir_bin2) : (dir_bin1 + dir_bin3);
                feature_vertex_count <= vertex_count;
                feature_convex_turns <= convex_turns;
                feature_concave_turns <= concave_turns;
                feature_contour_length <= contour_length;
                feature_contour_closed <= contour_closed_seen;
                feature_x_min <= x_min;
                feature_x_max <= x_max;
                feature_y_min <= y_min;
                feature_y_max <= y_max;
                feature_dir_bin0 <= dir_bin0;
                feature_dir_bin1 <= dir_bin1;
                feature_dir_bin2 <= dir_bin2;
                feature_dir_bin3 <= dir_bin3;

                have_component <= 1'b0;
                edge_count <= 32'd0;
                direction_total <= 32'd0;
                dir_bin0 <= 32'd0;
                dir_bin1 <= 32'd0;
                dir_bin2 <= 32'd0;
                dir_bin3 <= 32'd0;
                vertex_count <= 32'd0;
                convex_turns <= 32'd0;
                concave_turns <= 32'd0;
                contour_length <= 32'd0;
                contour_closed_seen <= 1'b0;
                x_min <= {X_WIDTH{1'b1}};
                x_max <= {X_WIDTH{1'b0}};
                y_min <= {Y_WIDTH{1'b1}};
                y_max <= {Y_WIDTH{1'b0}};
            end
        end
    end
endmodule
