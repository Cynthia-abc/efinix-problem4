 
 
 
module single_shape_recognizer_orientation #(
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
    parameter integer BBOX_TOLERANCE    = 20,
    parameter integer ANALYSIS_MARGIN   = 8,
    parameter [13:0] GRADIENT_MIN       = 14'd96
) (
    input                     clk,
    input                     rst_n,
    input                     in_vsync,
    input                     in_href,
    input                     gradient_valid,
    input signed [12:0]       gradient_x,
    input signed [12:0]       gradient_y,
    output reg                frame_done,
    output reg                target_valid,
    output reg [1:0]          target_shape,
    output reg [10:0]         bbox_x_min,
    output reg [10:0]         bbox_x_max,
    output reg [10:0]         bbox_y_min,
    output reg [10:0]         bbox_y_max,
    output reg [31:0]         target_edge_count,
    output reg [3:0]          dominant_bin
);
    localparam [1:0] SHAPE_UNKNOWN = 2'b00;
    localparam [1:0] SHAPE_CIRCLE  = 2'b01;
    localparam [1:0] SHAPE_RECT    = 2'b10;

    reg previous_vsync;
    reg previous_href;
    reg frame_vsync_d, line_href_d, gradient_valid_d;
    reg signed [12:0] gradient_x_d, gradient_y_d;
    reg [10:0] pixel_x, pixel_y;
    reg have_edge;
    reg [10:0] work_x_min, work_x_max, work_y_min, work_y_max;
    reg [31:0] work_edge_count;
    reg reference_valid;
    reg [10:0] reference_x_min, reference_x_max;
    reg [10:0] reference_y_min, reference_y_max;

    reg [31:0] orientation_counts [0:7];
    reg [31:0] analysis_count;
    reg [31:0] quad_tl, quad_tr, quad_bl, quad_br;
    reg pending_valid, pending_stable;
    reg [10:0] pending_x_min, pending_x_max;
    reg [10:0] pending_y_min, pending_y_max;
    reg [31:0] pending_edge_count, pending_analysis_count;
    reg [31:0] pending_quad_tl, pending_quad_tr;
    reg [31:0] pending_quad_bl, pending_quad_br;
    reg finalizing;
    reg classifying;
    reg [2:0] scan_bin;
    reg [31:0] best_pair;
    reg [2:0] best_bin;

    function [10:0] abs_diff_11;
        input [10:0] a, b;
        begin
            abs_diff_11 = (a >= b) ? a - b : b - a;
        end
    endfunction

    wire [12:0] abs_x = gradient_x_d[12] ? -gradient_x_d : gradient_x_d;
    wire [12:0] abs_y = gradient_y_d[12] ? -gradient_y_d : gradient_y_d;
    wire [13:0] strength = {1'b0, abs_x} + {1'b0, abs_y};
    wire [12:0] min_abs = (abs_x < abs_y) ? abs_x : abs_y;
    wire [12:0] max_abs = (abs_x < abs_y) ? abs_y : abs_x;
    wire [15:0] min_x5 = ({3'd0, min_abs} << 2) + {3'd0, min_abs};
    wire [15:0] min_x3 = ({3'd0, min_abs} << 1) + {3'd0, min_abs};
    wire [15:0] max_x2 = {2'd0, max_abs, 1'b0};
    reg [2:0] acute_bin;
    always @* begin
        if (min_x5 < {3'd0, max_abs})
            acute_bin = 3'd0;
        else if (min_x5 < max_x2)
            acute_bin = 3'd1;
        else if (min_x3 < max_x2)
            acute_bin = 3'd2;
        else
            acute_bin = 3'd3;
    end
    wire low_half = ((abs_x >= abs_y) ==
                     (gradient_x_d[12] == gradient_y_d[12]));
    wire [2:0] orientation_bin = low_half ? acute_bin : (3'd7 - acute_bin);

    wire sample_edge = frame_vsync_d && line_href_d && gradient_valid_d &&
                       (strength >= GRADIENT_MIN);
    wire in_roi = (pixel_x >= ROI_X_MIN) && (pixel_x <= ROI_X_MAX) &&
                  (pixel_y >= ROI_Y_MIN) && (pixel_y <= ROI_Y_MAX);
    wire in_reference = reference_valid &&
        (pixel_x + ANALYSIS_MARGIN >= reference_x_min) &&
        (pixel_x <= reference_x_max + ANALYSIS_MARGIN) &&
        (pixel_y + ANALYSIS_MARGIN >= reference_y_min) &&
        (pixel_y <= reference_y_max + ANALYSIS_MARGIN);
    wire [10:0] center_x = ({1'b0, reference_x_min} +
                            {1'b0, reference_x_max}) >> 1;
    wire [10:0] center_y = ({1'b0, reference_y_min} +
                            {1'b0, reference_y_max}) >> 1;

    wire [11:0] work_width = {1'b0, work_x_max} -
                             {1'b0, work_x_min} + 1'b1;
    wire [11:0] work_height = {1'b0, work_y_max} -
                              {1'b0, work_y_min} + 1'b1;
    wire current_valid = have_edge &&
        (work_edge_count >= MIN_EDGE_PIXELS) &&
        (work_width >= MIN_TARGET_SIZE) &&
        (work_height >= MIN_TARGET_SIZE) &&
        (work_width <= MAX_TARGET_WIDTH) &&
        (work_height <= MAX_TARGET_HEIGHT) &&
        (work_x_min >= ROI_X_MIN + ROI_BORDER_MARGIN) &&
        (work_x_max + ROI_BORDER_MARGIN <= ROI_X_MAX) &&
        (work_y_min >= ROI_Y_MIN + ROI_BORDER_MARGIN) &&
        (work_y_max + ROI_BORDER_MARGIN <= ROI_Y_MAX);
    wire current_stable = current_valid && reference_valid &&
        (abs_diff_11(work_x_min, reference_x_min) <= BBOX_TOLERANCE) &&
        (abs_diff_11(work_x_max, reference_x_max) <= BBOX_TOLERANCE) &&
        (abs_diff_11(work_y_min, reference_y_min) <= BBOX_TOLERANCE) &&
        (abs_diff_11(work_y_max, reference_y_max) <= BBOX_TOLERANCE);

    wire [2:0] next_bin = scan_bin + 3'd1;
    wire [2:0] third_bin = scan_bin + 3'd2;
    wire [2:0] fourth_bin = scan_bin + 3'd3;
    wire [31:0] window_count =
        (orientation_counts[scan_bin] + orientation_counts[next_bin]) +
        (orientation_counts[third_bin] + orientation_counts[fourth_bin]);
    wire [31:0] peak_count = (window_count > best_pair) ? window_count : best_pair;
    wire [2:0] peak_bin = (window_count > best_pair) ? scan_bin : best_bin;
    wire quadrants_present =
        (pending_quad_tl * 10 >= pending_analysis_count) &&
        (pending_quad_tr * 10 >= pending_analysis_count) &&
        (pending_quad_bl * 10 >= pending_analysis_count) &&
        (pending_quad_br * 10 >= pending_analysis_count);
    wire rectangular_directions =
        ((best_pair * 10) >= (pending_analysis_count * 7));

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            previous_vsync <= 1'b0;
            previous_href <= 1'b0;
            frame_vsync_d <= 1'b0;
            line_href_d <= 1'b0;
            gradient_valid_d <= 1'b0;
            gradient_x_d <= 13'sd0;
            gradient_y_d <= 13'sd0;
            pixel_x <= 11'd0;
            pixel_y <= 11'd0;
            have_edge <= 1'b0;
            work_x_min <= IMAGE_WIDTH;
            work_x_max <= 11'd0;
            work_y_min <= IMAGE_HEIGHT;
            work_y_max <= 11'd0;
            work_edge_count <= 32'd0;
            reference_valid <= 1'b0;
            reference_x_min <= 11'd0;
            reference_x_max <= 11'd0;
            reference_y_min <= 11'd0;
            reference_y_max <= 11'd0;
            analysis_count <= 32'd0;
            quad_tl <= 32'd0;
            quad_tr <= 32'd0;
            quad_bl <= 32'd0;
            quad_br <= 32'd0;
            pending_valid <= 1'b0;
            pending_stable <= 1'b0;
            pending_x_min <= 11'd0;
            pending_x_max <= 11'd0;
            pending_y_min <= 11'd0;
            pending_y_max <= 11'd0;
            pending_edge_count <= 32'd0;
            pending_analysis_count <= 32'd0;
            pending_quad_tl <= 32'd0;
            pending_quad_tr <= 32'd0;
            pending_quad_bl <= 32'd0;
            pending_quad_br <= 32'd0;
            finalizing <= 1'b0;
            classifying <= 1'b0;
            scan_bin <= 3'd0;
            best_pair <= 32'd0;
            best_bin <= 3'd0;
            frame_done <= 1'b0;
            target_valid <= 1'b0;
            target_shape <= SHAPE_UNKNOWN;
            bbox_x_min <= 11'd0;
            bbox_x_max <= 11'd0;
            bbox_y_min <= 11'd0;
            bbox_y_max <= 11'd0;
            target_edge_count <= 32'd0;
            dominant_bin <= 4'd0;
            for (i = 0; i < 8; i = i + 1)
                orientation_counts[i] <= 32'd0;
        end else begin
            frame_vsync_d <= in_vsync;
            line_href_d <= in_href;
            gradient_valid_d <= gradient_valid;
            gradient_x_d <= gradient_x;
            gradient_y_d <= gradient_y;
            previous_vsync <= frame_vsync_d;
            frame_done <= 1'b0;

            if (previous_vsync && !frame_vsync_d) begin
                pending_valid <= current_valid;
                pending_stable <= current_stable;
                pending_x_min <= work_x_min;
                pending_x_max <= work_x_max;
                pending_y_min <= work_y_min;
                pending_y_max <= work_y_max;
                pending_edge_count <= work_edge_count;
                pending_analysis_count <= analysis_count;
                pending_quad_tl <= quad_tl;
                pending_quad_tr <= quad_tr;
                pending_quad_bl <= quad_bl;
                pending_quad_br <= quad_br;
                reference_valid <= current_valid;
                reference_x_min <= work_x_min;
                reference_x_max <= work_x_max;
                reference_y_min <= work_y_min;
                reference_y_max <= work_y_max;
                work_x_min <= IMAGE_WIDTH;
                work_x_max <= 11'd0;
                work_y_min <= IMAGE_HEIGHT;
                work_y_max <= 11'd0;
                work_edge_count <= 32'd0;
                have_edge <= 1'b0;
                previous_href <= 1'b0;
                pixel_x <= 11'd0;
                pixel_y <= 11'd0;
                finalizing <= 1'b1;
                classifying <= 1'b0;
                scan_bin <= 3'd0;
                best_pair <= 32'd0;
                best_bin <= 3'd0;
            end else if (finalizing) begin
                best_pair <= peak_count;
                best_bin <= peak_bin;
                if (scan_bin == 3'd7) begin
                    finalizing <= 1'b0;
                    classifying <= 1'b1;
                end else begin
                    scan_bin <= scan_bin + 1'b1;
                end
            end else if (classifying) begin
                classifying <= 1'b0;
                frame_done <= 1'b1;
                target_valid <= pending_stable && quadrants_present &&
                                (pending_analysis_count >= MIN_EDGE_PIXELS);
                if (pending_stable && quadrants_present &&
                    (pending_analysis_count >= MIN_EDGE_PIXELS)) begin
                    target_shape <= rectangular_directions ?
                                    SHAPE_RECT : SHAPE_CIRCLE;
                    bbox_x_min <= pending_x_min;
                    bbox_x_max <= pending_x_max;
                    bbox_y_min <= pending_y_min;
                    bbox_y_max <= pending_y_max;
                    target_edge_count <= pending_edge_count;
                    dominant_bin <= {1'b0, best_bin};
                end else begin
                    target_shape <= SHAPE_UNKNOWN;
                    target_edge_count <= 32'd0;
                    dominant_bin <= 4'd0;
                end
                analysis_count <= 32'd0;
                quad_tl <= 32'd0;
                quad_tr <= 32'd0;
                quad_bl <= 32'd0;
                quad_br <= 32'd0;
                for (i = 0; i < 8; i = i + 1)
                    orientation_counts[i] <= 32'd0;
            end else if (!frame_vsync_d) begin
                previous_href <= 1'b0;
                pixel_x <= 11'd0;
                pixel_y <= 11'd0;
            end else if (!line_href_d) begin
                pixel_x <= 11'd0;
                if (previous_href && pixel_y < IMAGE_HEIGHT - 1)
                    pixel_y <= pixel_y + 1'b1;
                previous_href <= 1'b0;
            end else begin
                previous_href <= 1'b1;
                if (sample_edge && in_roi) begin
                    have_edge <= 1'b1;
                    if (pixel_x < work_x_min) work_x_min <= pixel_x;
                    if (pixel_x > work_x_max) work_x_max <= pixel_x;
                    if (pixel_y < work_y_min) work_y_min <= pixel_y;
                    if (pixel_y > work_y_max) work_y_max <= pixel_y;
                    work_edge_count <= work_edge_count + 1'b1;
                    if (in_reference) begin
                        orientation_counts[orientation_bin] <=
                            orientation_counts[orientation_bin] + 1'b1;
                        analysis_count <= analysis_count + 1'b1;
                        if (pixel_x <= center_x) begin
                            if (pixel_y <= center_y)
                                quad_tl <= quad_tl + 1'b1;
                            else
                                quad_bl <= quad_bl + 1'b1;
                        end else begin
                            if (pixel_y <= center_y)
                                quad_tr <= quad_tr + 1'b1;
                            else
                                quad_br <= quad_br + 1'b1;
                        end
                    end
                end
                if (pixel_x < IMAGE_WIDTH - 1)
                    pixel_x <= pixel_x + 1'b1;
                else
                    pixel_x <= 11'd0;
            end
        end
    end
endmodule
