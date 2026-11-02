 
 
 
module single_shape_recognizer #(
    parameter integer IMAGE_WIDTH       = 1920,
    parameter integer IMAGE_HEIGHT      = 1080,
    parameter integer ROI_X_MIN         = 560,
    parameter integer ROI_X_MAX         = 1359,
    parameter integer ROI_Y_MIN         = 240,
    parameter integer ROI_Y_MAX         = 839,
    parameter integer MIN_EDGE_PIXELS   = 128,
    parameter integer MIN_TARGET_SIZE   = 48,
    parameter integer MAX_TARGET_WIDTH  = 680,
    parameter integer MAX_TARGET_HEIGHT = 480,
    parameter integer ROI_BORDER_MARGIN = 16,
    parameter integer SIDE_BAND         = 4,
    parameter integer BBOX_TOLERANCE    = 10,
    parameter integer STABLE_FRAMES     = 2,
    parameter integer LOST_FRAMES       = 3
) (
    input             clk,
    input             rst_n,
    input             in_vsync,
    input             in_hsync,
    input             in_href,
    input             edge_valid,
    input      [7:0]  edge_data,
    input      [1:0]  edge_dir,
    output reg        frame_done,
    output reg        target_valid,
    output reg [1:0]  target_shape,
    output reg [10:0] bbox_x_min,
    output reg [10:0] bbox_x_max,
    output reg [10:0] bbox_y_min,
    output reg [10:0] bbox_y_max,
    output reg [31:0] target_edge_count,
    output reg [31:0] target_side_hits
);

    localparam [1:0] SHAPE_UNKNOWN = 2'b00;
    localparam [1:0] SHAPE_CIRCLE  = 2'b01;
    localparam [1:0] SHAPE_RECT    = 2'b10;

    reg        prev_vsync;
    reg        previous_href;
    reg [10:0] x_count;
    reg [10:0] y_count;

    reg        have_edge;
    reg [10:0] work_x_min;
    reg [10:0] work_x_max;
    reg [10:0] work_y_min;
    reg [10:0] work_y_max;
    reg [31:0] work_edge_count;
    reg [31:0] work_eval_count;
    reg [31:0] work_side_hits;
    reg [31:0] work_dir_0_count;
    reg [31:0] work_dir_1_count;
    reg [31:0] work_dir_2_count;
    reg [31:0] work_dir_3_count;
    reg [31:0] work_quad_tl_count;
    reg [31:0] work_quad_tr_count;
    reg [31:0] work_quad_bl_count;
    reg [31:0] work_quad_br_count;

    reg        reference_valid;
    reg [10:0] reference_x_min;
    reg [10:0] reference_x_max;
    reg [10:0] reference_y_min;
    reg [10:0] reference_y_max;
    reg [7:0]  stable_count;
    reg [7:0]  lost_count;

    wire strong_edge = edge_valid && (edge_data == 8'hff);
    wire in_roi = (x_count >= ROI_X_MIN) && (x_count <= ROI_X_MAX) &&
                  (y_count >= ROI_Y_MIN) && (y_count <= ROI_Y_MAX);

    wire [11:0] x_ext = {1'b0, x_count};
    wire [11:0] y_ext = {1'b0, y_count};
    wire [11:0] ref_x_min_ext = {1'b0, reference_x_min};
    wire [11:0] ref_x_max_ext = {1'b0, reference_x_max};
    wire [11:0] ref_y_min_ext = {1'b0, reference_y_min};
    wire [11:0] ref_y_max_ext = {1'b0, reference_y_max};
    wire [11:0] ref_center_x_sum = ref_x_min_ext + ref_x_max_ext;
    wire [11:0] ref_center_y_sum = ref_y_min_ext + ref_y_max_ext;
    wire [10:0] ref_center_x = ref_center_x_sum[11:1];
    wire [10:0] ref_center_y = ref_center_y_sum[11:1];

    wire inside_reference = reference_valid &&
        ((x_ext + BBOX_TOLERANCE) >= ref_x_min_ext) &&
        (x_ext <= (ref_x_max_ext + BBOX_TOLERANCE)) &&
        ((y_ext + BBOX_TOLERANCE) >= ref_y_min_ext) &&
        (y_ext <= (ref_y_max_ext + BBOX_TOLERANCE));

    wire near_left   = ((x_ext + SIDE_BAND) >= ref_x_min_ext) &&
                       (x_ext <= (ref_x_min_ext + SIDE_BAND));
    wire near_right  = ((x_ext + SIDE_BAND) >= ref_x_max_ext) &&
                       (x_ext <= (ref_x_max_ext + SIDE_BAND));
    wire near_top    = ((y_ext + SIDE_BAND) >= ref_y_min_ext) &&
                       (y_ext <= (ref_y_min_ext + SIDE_BAND));
    wire near_bottom = ((y_ext + SIDE_BAND) >= ref_y_max_ext) &&
                       (y_ext <= (ref_y_max_ext + SIDE_BAND));
    wire near_box_side = near_left || near_right || near_top || near_bottom;

    function [10:0] abs_diff_11;
        input [10:0] a;
        input [10:0] b;
        begin
            abs_diff_11 = (a >= b) ? (a - b) : (b - a);
        end
    endfunction

    wire [11:0] current_width  = {1'b0, work_x_max} - {1'b0, work_x_min} + 1'b1;
    wire [11:0] current_height = {1'b0, work_y_max} - {1'b0, work_y_min} + 1'b1;
    wire [11:0] size_difference = (current_width >= current_height) ?
                                  (current_width - current_height) :
                                  (current_height - current_width);
    wire [11:0] largest_size = (current_width >= current_height) ?
                               current_width : current_height;

    wire size_valid = (current_width >= MIN_TARGET_SIZE) &&
                      (current_height >= MIN_TARGET_SIZE) &&
                      (current_width <= MAX_TARGET_WIDTH) &&
                      (current_height <= MAX_TARGET_HEIGHT);
    wire clear_of_roi_border =
        (work_x_min >= (ROI_X_MIN + ROI_BORDER_MARGIN)) &&
        (({1'b0, work_x_max} + ROI_BORDER_MARGIN) <= ROI_X_MAX) &&
        (work_y_min >= (ROI_Y_MIN + ROI_BORDER_MARGIN)) &&
        (({1'b0, work_y_max} + ROI_BORDER_MARGIN) <= ROI_Y_MAX);
    wire current_valid = have_edge && (work_edge_count >= MIN_EDGE_PIXELS) &&
                         size_valid && clear_of_roi_border;

    wire bbox_stable = current_valid && reference_valid &&
        (abs_diff_11(work_x_min, reference_x_min) <= BBOX_TOLERANCE) &&
        (abs_diff_11(work_x_max, reference_x_max) <= BBOX_TOLERANCE) &&
        (abs_diff_11(work_y_min, reference_y_min) <= BBOX_TOLERANCE) &&
        (abs_diff_11(work_y_max, reference_y_max) <= BBOX_TOLERANCE);

    wire near_square = ((size_difference << 2) + size_difference) <= largest_size;
    wire [31:0] axis_direction_count = work_dir_0_count + work_dir_1_count;
    wire [31:0] diagonal_direction_count = work_dir_2_count + work_dir_3_count;
    wire [31:0] dominant_direction_pair =
        (axis_direction_count >= diagonal_direction_count) ?
        axis_direction_count : diagonal_direction_count;
     
     
     
    wire rectangle_direction_concentrated =
        (dominant_direction_pair << 2) >=
        (work_eval_count + (work_eval_count << 1));
     
     
    wire quadrants_present =
        (((work_quad_tl_count << 3) + (work_quad_tl_count << 1)) >= work_eval_count) &&
        (((work_quad_tr_count << 3) + (work_quad_tr_count << 1)) >= work_eval_count) &&
        (((work_quad_bl_count << 3) + (work_quad_bl_count << 1)) >= work_eval_count) &&
        (((work_quad_br_count << 3) + (work_quad_br_count << 1)) >= work_eval_count);
    wire measurement_valid = bbox_stable &&
                             (work_eval_count >= MIN_EDGE_PIXELS);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prev_vsync       <= 1'b0;
            previous_href    <= 1'b0;
            x_count          <= 11'd0;
            y_count          <= 11'd0;
            have_edge        <= 1'b0;
            work_x_min       <= IMAGE_WIDTH;
            work_x_max       <= 11'd0;
            work_y_min       <= IMAGE_HEIGHT;
            work_y_max       <= 11'd0;
            work_edge_count  <= 32'd0;
            work_eval_count  <= 32'd0;
            work_side_hits   <= 32'd0;
            work_dir_0_count <= 32'd0;
            work_dir_1_count <= 32'd0;
            work_dir_2_count <= 32'd0;
            work_dir_3_count <= 32'd0;
            work_quad_tl_count <= 32'd0;
            work_quad_tr_count <= 32'd0;
            work_quad_bl_count <= 32'd0;
            work_quad_br_count <= 32'd0;
            reference_valid  <= 1'b0;
            reference_x_min  <= 11'd0;
            reference_x_max  <= 11'd0;
            reference_y_min  <= 11'd0;
            reference_y_max  <= 11'd0;
            stable_count     <= 8'd0;
            lost_count       <= 8'd0;
            frame_done       <= 1'b0;
            target_valid     <= 1'b0;
            target_shape     <= SHAPE_UNKNOWN;
            bbox_x_min       <= 11'd0;
            bbox_x_max       <= 11'd0;
            bbox_y_min       <= 11'd0;
            bbox_y_max       <= 11'd0;
            target_edge_count <= 32'd0;
            target_side_hits  <= 32'd0;
        end else begin
            prev_vsync <= in_vsync;
            frame_done <= 1'b0;

            if (prev_vsync && !in_vsync) begin
                frame_done <= 1'b1;

                if (measurement_valid) begin
                    lost_count <= 8'd0;
                    if (stable_count != 8'hff)
                        stable_count <= stable_count + 1'b1;

                    if (stable_count >= STABLE_FRAMES - 1) begin
                        target_valid      <= 1'b1;
                        bbox_x_min        <= work_x_min;
                        bbox_x_max        <= work_x_max;
                        bbox_y_min        <= work_y_min;
                        bbox_y_max        <= work_y_max;
                        target_edge_count <= work_eval_count;
                        target_side_hits  <= work_side_hits;

                        if (rectangle_direction_concentrated && quadrants_present)
                            target_shape <= SHAPE_RECT;
                        else if (near_square && !rectangle_direction_concentrated &&
                                 quadrants_present)
                            target_shape <= SHAPE_CIRCLE;
                        else
                            target_shape <= SHAPE_UNKNOWN;
                    end
                end else begin
                    stable_count <= 8'd0;
                    if (lost_count != 8'hff)
                        lost_count <= lost_count + 1'b1;
                    if (lost_count >= LOST_FRAMES - 1) begin
                        target_valid      <= 1'b0;
                        target_shape      <= SHAPE_UNKNOWN;
                        target_edge_count <= 32'd0;
                        target_side_hits  <= 32'd0;
                    end
                end

                reference_valid <= current_valid;
                if (current_valid) begin
                    reference_x_min <= work_x_min;
                    reference_x_max <= work_x_max;
                    reference_y_min <= work_y_min;
                    reference_y_max <= work_y_max;
                end

                previous_href   <= 1'b0;
                x_count         <= 11'd0;
                y_count         <= 11'd0;
                have_edge       <= 1'b0;
                work_x_min      <= IMAGE_WIDTH;
                work_x_max      <= 11'd0;
                work_y_min      <= IMAGE_HEIGHT;
                work_y_max      <= 11'd0;
                work_edge_count <= 32'd0;
                work_eval_count <= 32'd0;
                work_side_hits  <= 32'd0;
                work_dir_0_count <= 32'd0;
                work_dir_1_count <= 32'd0;
                work_dir_2_count <= 32'd0;
                work_dir_3_count <= 32'd0;
                work_quad_tl_count <= 32'd0;
                work_quad_tr_count <= 32'd0;
                work_quad_bl_count <= 32'd0;
                work_quad_br_count <= 32'd0;
            end else if (!in_vsync) begin
                previous_href <= 1'b0;
                x_count       <= 11'd0;
                y_count       <= 11'd0;
            end else if (!in_href) begin
                x_count <= 11'd0;
                if (previous_href && (y_count < IMAGE_HEIGHT - 1))
                    y_count <= y_count + 1'b1;
                previous_href <= 1'b0;
            end else begin
                previous_href <= 1'b1;

                if (strong_edge && in_roi) begin
                    have_edge <= 1'b1;
                    if (x_count < work_x_min)
                        work_x_min <= x_count;
                    if (x_count > work_x_max)
                        work_x_max <= x_count;
                    if (y_count < work_y_min)
                        work_y_min <= y_count;
                    if (y_count > work_y_max)
                        work_y_max <= y_count;
                    if (work_edge_count != 32'hffff_ffff)
                        work_edge_count <= work_edge_count + 1'b1;

                    if (inside_reference) begin
                        if (work_eval_count != 32'hffff_ffff)
                            work_eval_count <= work_eval_count + 1'b1;
                        if (near_box_side && (work_side_hits != 32'hffff_ffff))
                            work_side_hits <= work_side_hits + 1'b1;
                        case (edge_dir)
                            2'b00: if (work_dir_0_count != 32'hffff_ffff)
                                work_dir_0_count <= work_dir_0_count + 1'b1;
                            2'b01: if (work_dir_1_count != 32'hffff_ffff)
                                work_dir_1_count <= work_dir_1_count + 1'b1;
                            2'b10: if (work_dir_2_count != 32'hffff_ffff)
                                work_dir_2_count <= work_dir_2_count + 1'b1;
                            2'b11: if (work_dir_3_count != 32'hffff_ffff)
                                work_dir_3_count <= work_dir_3_count + 1'b1;
                        endcase

                        if (x_count <= ref_center_x) begin
                            if (y_count <= ref_center_y) begin
                                if (work_quad_tl_count != 32'hffff_ffff)
                                    work_quad_tl_count <= work_quad_tl_count + 1'b1;
                            end else if (work_quad_bl_count != 32'hffff_ffff) begin
                                work_quad_bl_count <= work_quad_bl_count + 1'b1;
                            end
                        end else begin
                            if (y_count <= ref_center_y) begin
                                if (work_quad_tr_count != 32'hffff_ffff)
                                    work_quad_tr_count <= work_quad_tr_count + 1'b1;
                            end else if (work_quad_br_count != 32'hffff_ffff) begin
                                work_quad_br_count <= work_quad_br_count + 1'b1;
                            end
                        end
                    end
                end

                if (x_count < IMAGE_WIDTH - 1)
                    x_count <= x_count + 1'b1;
                else
                    x_count <= 11'd0;
            end
        end
    end

     
    wire unused_hsync = in_hsync;

endmodule
