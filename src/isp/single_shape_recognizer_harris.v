 
 
 
module single_shape_recognizer_harris #(
    parameter integer IMAGE_WIDTH       = 1920,
    parameter integer IMAGE_HEIGHT      = 1080,
    parameter integer ROI_X_MIN         = 560,
    parameter integer ROI_X_MAX         = 1359,
    parameter integer ROI_Y_MIN         = 240,
    parameter integer ROI_Y_MAX         = 839,
    parameter integer MIN_EDGE_PIXELS   = 128,
    parameter integer MIN_TARGET_SIZE   = 48,
    parameter integer MAX_TARGET_WIDTH  = 760,
    parameter integer MAX_TARGET_HEIGHT = 560,
    parameter integer ROI_BORDER_MARGIN = 12,
    parameter integer BBOX_TOLERANCE    = 12,
    parameter integer CORNER_MARGIN     = 12,
    parameter integer CORNER_SEPARATION = 12,
    parameter integer MAX_CORNERS       = 8,
    parameter integer STABLE_FRAMES     = 1,
    parameter integer LOST_FRAMES       = 3
) (
    input             clk,
    input             rst_n,
    input             edge_vsync,
    input             edge_hsync,
    input             edge_href,
    input             edge_valid,
    input      [7:0]  edge_data,
    input      [1:0]  edge_dir,
    input             corner_event,
    input      [10:0] corner_x,
    input      [10:0] corner_y,
    input             corner_frame_done,
    output reg        frame_done,
    output reg        target_valid,
    output reg [1:0]  target_shape,
    output reg [10:0] bbox_x_min,
    output reg [10:0] bbox_x_max,
    output reg [10:0] bbox_y_min,
    output reg [10:0] bbox_y_max,
    output reg [31:0] target_edge_count,
    output reg [3:0]  target_corner_count
);

    localparam [1:0] SHAPE_UNKNOWN = 2'b00;
    localparam [1:0] SHAPE_CIRCLE  = 2'b01;
    localparam [1:0] SHAPE_RECT    = 2'b10;

    reg previous_edge_vsync;
    reg previous_edge_href;
    reg [10:0] edge_x;
    reg [10:0] edge_y;
    reg have_edge;
    reg [10:0] work_x_min;
    reg [10:0] work_x_max;
    reg [10:0] work_y_min;
    reg [10:0] work_y_max;
    reg [31:0] work_edge_count;
    reg [31:0] work_eval_count;
    reg [31:0] work_quad_tl;
    reg [31:0] work_quad_tr;
    reg [31:0] work_quad_bl;
    reg [31:0] work_quad_br;
    reg [31:0] work_axis_dir_count;
    reg [31:0] work_diag_dir_count;

    reg reference_valid;
    reg [10:0] reference_x_min;
    reg [10:0] reference_x_max;
    reg [10:0] reference_y_min;
    reg [10:0] reference_y_max;

    reg pending_valid;
    reg pending_stable;
    reg pending_quadrants;
    reg [10:0] pending_x_min;
    reg [10:0] pending_x_max;
    reg [10:0] pending_y_min;
    reg [10:0] pending_y_max;
    reg [31:0] pending_edge_count;
    reg [31:0] pending_eval_count;
    reg pending_direction_concentrated;

    reg [7:0] stable_count;
    reg [7:0] lost_count;

    reg [10:0] distinct_x [0:MAX_CORNERS-1];
    reg [10:0] distinct_y [0:MAX_CORNERS-1];
    reg [MAX_CORNERS-1:0] distinct_valid;
    reg [3:0] distinct_count;

    integer i;
    reg corner_too_close;
    always @* begin
        corner_too_close = 1'b0;
        for (i = 0; i < MAX_CORNERS; i = i + 1) begin
            if (distinct_valid[i] &&
                (corner_x + CORNER_SEPARATION >= distinct_x[i]) &&
                (corner_x <= distinct_x[i] + CORNER_SEPARATION) &&
                (corner_y + CORNER_SEPARATION >= distinct_y[i]) &&
                (corner_y <= distinct_y[i] + CORNER_SEPARATION))
                corner_too_close = 1'b1;
        end
    end

    function [10:0] abs_diff_11;
        input [10:0] a;
        input [10:0] b;
        begin
            abs_diff_11 = (a >= b) ? (a - b) : (b - a);
        end
    endfunction

    wire strong_edge = edge_valid && (edge_data == 8'hff);
    wire edge_in_roi = (edge_x >= ROI_X_MIN) && (edge_x <= ROI_X_MAX) &&
                       (edge_y >= ROI_Y_MIN) && (edge_y <= ROI_Y_MAX);
    wire [11:0] current_width =
        {1'b0, work_x_max} - {1'b0, work_x_min} + 1'b1;
    wire [11:0] current_height =
        {1'b0, work_y_max} - {1'b0, work_y_min} + 1'b1;
    wire size_valid = (current_width >= MIN_TARGET_SIZE) &&
                      (current_height >= MIN_TARGET_SIZE) &&
                      (current_width <= MAX_TARGET_WIDTH) &&
                      (current_height <= MAX_TARGET_HEIGHT);
    wire clear_of_roi_border =
        (work_x_min >= ROI_X_MIN + ROI_BORDER_MARGIN) &&
        (work_x_max + ROI_BORDER_MARGIN <= ROI_X_MAX) &&
        (work_y_min >= ROI_Y_MIN + ROI_BORDER_MARGIN) &&
        (work_y_max + ROI_BORDER_MARGIN <= ROI_Y_MAX);
    wire current_valid = have_edge &&
                         (work_edge_count >= MIN_EDGE_PIXELS) &&
                         size_valid && clear_of_roi_border;
    wire current_stable = current_valid && reference_valid &&
        (abs_diff_11(work_x_min, reference_x_min) <= BBOX_TOLERANCE) &&
        (abs_diff_11(work_x_max, reference_x_max) <= BBOX_TOLERANCE) &&
        (abs_diff_11(work_y_min, reference_y_min) <= BBOX_TOLERANCE) &&
        (abs_diff_11(work_y_max, reference_y_max) <= BBOX_TOLERANCE);

    wire [11:0] ref_center_x_sum =
        {1'b0, reference_x_min} + {1'b0, reference_x_max};
    wire [11:0] ref_center_y_sum =
        {1'b0, reference_y_min} + {1'b0, reference_y_max};
    wire [10:0] ref_center_x = ref_center_x_sum[11:1];
    wire [10:0] ref_center_y = ref_center_y_sum[11:1];
    wire edge_inside_reference = reference_valid &&
        (edge_x + BBOX_TOLERANCE >= reference_x_min) &&
        (edge_x <= reference_x_max + BBOX_TOLERANCE) &&
        (edge_y + BBOX_TOLERANCE >= reference_y_min) &&
        (edge_y <= reference_y_max + BBOX_TOLERANCE);
    wire corner_inside_reference = reference_valid &&
        (corner_x + CORNER_MARGIN >= reference_x_min) &&
        (corner_x <= reference_x_max + CORNER_MARGIN) &&
        (corner_y + CORNER_MARGIN >= reference_y_min) &&
        (corner_y <= reference_y_max + CORNER_MARGIN);

     
     
     
    wire quadrants_present = (work_eval_count >= MIN_EDGE_PIXELS) &&
        (work_quad_tl * 10 >= work_eval_count) &&
        (work_quad_tr * 10 >= work_eval_count) &&
        (work_quad_bl * 10 >= work_eval_count) &&
        (work_quad_br * 10 >= work_eval_count);
    wire [31:0] dominant_direction_count =
        (work_axis_dir_count >= work_diag_dir_count) ?
        work_axis_dir_count : work_diag_dir_count;
     
     
     
    wire direction_concentrated = (work_eval_count >= MIN_EDGE_PIXELS) &&
        ((dominant_direction_count * 10) >= (work_eval_count * 7));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            previous_edge_vsync <= 1'b0;
            previous_edge_href <= 1'b0;
            edge_x <= 11'd0;
            edge_y <= 11'd0;
            have_edge <= 1'b0;
            work_x_min <= IMAGE_WIDTH;
            work_x_max <= 11'd0;
            work_y_min <= IMAGE_HEIGHT;
            work_y_max <= 11'd0;
            work_edge_count <= 32'd0;
            work_eval_count <= 32'd0;
            work_quad_tl <= 32'd0;
            work_quad_tr <= 32'd0;
            work_quad_bl <= 32'd0;
            work_quad_br <= 32'd0;
            work_axis_dir_count <= 32'd0;
            work_diag_dir_count <= 32'd0;
            reference_valid <= 1'b0;
            reference_x_min <= 11'd0;
            reference_x_max <= 11'd0;
            reference_y_min <= 11'd0;
            reference_y_max <= 11'd0;
            pending_valid <= 1'b0;
            pending_stable <= 1'b0;
            pending_quadrants <= 1'b0;
            pending_x_min <= 11'd0;
            pending_x_max <= 11'd0;
            pending_y_min <= 11'd0;
            pending_y_max <= 11'd0;
            pending_edge_count <= 32'd0;
            pending_eval_count <= 32'd0;
            pending_direction_concentrated <= 1'b0;
            stable_count <= 8'd0;
            lost_count <= 8'd0;
            distinct_valid <= {MAX_CORNERS{1'b0}};
            distinct_count <= 4'd0;
            for (i = 0; i < MAX_CORNERS; i = i + 1) begin
                distinct_x[i] <= 11'd0;
                distinct_y[i] <= 11'd0;
            end
            frame_done <= 1'b0;
            target_valid <= 1'b0;
            target_shape <= SHAPE_UNKNOWN;
            bbox_x_min <= 11'd0;
            bbox_x_max <= 11'd0;
            bbox_y_min <= 11'd0;
            bbox_y_max <= 11'd0;
            target_edge_count <= 32'd0;
            target_corner_count <= 4'd0;
        end else begin
            previous_edge_vsync <= edge_vsync;
            frame_done <= 1'b0;

            if (previous_edge_vsync && !edge_vsync) begin
                pending_valid <= current_valid;
                pending_stable <= current_stable;
                pending_quadrants <= quadrants_present;
                pending_x_min <= work_x_min;
                pending_x_max <= work_x_max;
                pending_y_min <= work_y_min;
                pending_y_max <= work_y_max;
                pending_edge_count <= work_edge_count;
                pending_eval_count <= work_eval_count;
                pending_direction_concentrated <= direction_concentrated;
                previous_edge_href <= 1'b0;
                edge_x <= 11'd0;
                edge_y <= 11'd0;
                have_edge <= 1'b0;
                work_x_min <= IMAGE_WIDTH;
                work_x_max <= 11'd0;
                work_y_min <= IMAGE_HEIGHT;
                work_y_max <= 11'd0;
                work_edge_count <= 32'd0;
                work_eval_count <= 32'd0;
                work_quad_tl <= 32'd0;
                work_quad_tr <= 32'd0;
                work_quad_bl <= 32'd0;
                work_quad_br <= 32'd0;
                work_axis_dir_count <= 32'd0;
                work_diag_dir_count <= 32'd0;
            end else if (!edge_vsync) begin
                previous_edge_href <= 1'b0;
                edge_x <= 11'd0;
                edge_y <= 11'd0;
            end else if (!edge_href) begin
                edge_x <= 11'd0;
                if (previous_edge_href && edge_y < IMAGE_HEIGHT - 1)
                    edge_y <= edge_y + 1'b1;
                previous_edge_href <= 1'b0;
            end else begin
                previous_edge_href <= 1'b1;
                if (strong_edge && edge_in_roi) begin
                    have_edge <= 1'b1;
                    if (edge_x < work_x_min) work_x_min <= edge_x;
                    if (edge_x > work_x_max) work_x_max <= edge_x;
                    if (edge_y < work_y_min) work_y_min <= edge_y;
                    if (edge_y > work_y_max) work_y_max <= edge_y;
                    if (work_edge_count != 32'hffff_ffff)
                        work_edge_count <= work_edge_count + 1'b1;
                    if (edge_inside_reference) begin
                        if (work_eval_count != 32'hffff_ffff)
                            work_eval_count <= work_eval_count + 1'b1;
                        if (edge_dir == 2'b00 || edge_dir == 2'b01) begin
                            if (work_axis_dir_count != 32'hffff_ffff)
                                work_axis_dir_count <= work_axis_dir_count + 1'b1;
                        end else begin
                            if (work_diag_dir_count != 32'hffff_ffff)
                                work_diag_dir_count <= work_diag_dir_count + 1'b1;
                        end
                        if (edge_x <= ref_center_x) begin
                            if (edge_y <= ref_center_y)
                                work_quad_tl <= work_quad_tl + 1'b1;
                            else
                                work_quad_bl <= work_quad_bl + 1'b1;
                        end else begin
                            if (edge_y <= ref_center_y)
                                work_quad_tr <= work_quad_tr + 1'b1;
                            else
                                work_quad_br <= work_quad_br + 1'b1;
                        end
                    end
                end
                if (edge_x < IMAGE_WIDTH - 1)
                    edge_x <= edge_x + 1'b1;
                else
                    edge_x <= 11'd0;
            end

            if (corner_event && corner_inside_reference &&
                !corner_too_close && distinct_count < MAX_CORNERS) begin
                distinct_x[distinct_count] <= corner_x;
                distinct_y[distinct_count] <= corner_y;
                distinct_valid[distinct_count] <= 1'b1;
                distinct_count <= distinct_count + 1'b1;
            end

            if (corner_frame_done) begin
                frame_done <= 1'b1;
                distinct_valid <= {MAX_CORNERS{1'b0}};
                distinct_count <= 4'd0;

                if (pending_valid) begin
                    reference_valid <= 1'b1;
                    reference_x_min <= pending_x_min;
                    reference_x_max <= pending_x_max;
                    reference_y_min <= pending_y_min;
                    reference_y_max <= pending_y_max;
                end else begin
                    reference_valid <= 1'b0;
                end

                 
                 
                 
                if (pending_valid) begin
                    lost_count <= 8'd0;
                    target_valid <= 1'b1;
                    target_shape <= SHAPE_UNKNOWN;
                    bbox_x_min <= pending_x_min;
                    bbox_x_max <= pending_x_max;
                    bbox_y_min <= pending_y_min;
                    bbox_y_max <= pending_y_max;
                    target_edge_count <= pending_edge_count;
                    target_corner_count <= distinct_count;

                    if (pending_stable) begin
                        if (stable_count != 8'hff)
                            stable_count <= stable_count + 1'b1;
                    end else begin
                        stable_count <= 8'd0;
                    end

                    if (pending_stable &&
                        (stable_count >= STABLE_FRAMES - 1)) begin
                        if (!pending_quadrants ||
                            (pending_eval_count < MIN_EDGE_PIXELS))
                            target_shape <= SHAPE_UNKNOWN;
                        else if (distinct_count >= 3 && distinct_count <= 6)
                            target_shape <= SHAPE_RECT;
                        else if (distinct_count <= 1) begin
                            if (pending_direction_concentrated)
                                target_shape <= SHAPE_RECT;
                            else
                                target_shape <= SHAPE_CIRCLE;
                        end
                        else
                            target_shape <= SHAPE_UNKNOWN;
                    end
                end else begin
                    stable_count <= 8'd0;
                    if (lost_count != 8'hff)
                        lost_count <= lost_count + 1'b1;
                    if (lost_count >= LOST_FRAMES - 1) begin
                        target_valid <= 1'b0;
                        target_shape <= SHAPE_UNKNOWN;
                        target_edge_count <= 32'd0;
                        target_corner_count <= 4'd0;
                    end
                end
            end
        end
    end

    wire unused_edge_hsync = edge_hsync;

endmodule
