 
 
 
 
 
 
 
 
module shape_geometry_classifier #(
    parameter integer MIN_EDGE_COUNT       = 128,
    parameter integer MIN_CONTOUR_LENGTH  = 32,
    parameter integer RECT_MIN_VERTICES   = 3,
    parameter integer RECT_MAX_VERTICES   = 6,
    parameter integer TRI_MIN_VERTICES    = 2,
    parameter integer TRI_MAX_VERTICES    = 4,
    parameter integer STAR_MIN_CONVEX    = 4,
    parameter integer STAR_MIN_CONCAVE   = 3,
    parameter integer CIRCLE_MAX_VERTICES = 2,
    parameter integer RECT_ORTHO_PERCENT  = 55,
    parameter integer CIRCLE_RADIAL_ERROR_PERMILLE = 180,
    parameter integer CIRCLE_ASPECT_TOL_PERMILLE   = 180,
    parameter integer STABLE_FRAMES       = 2,
    parameter integer BBOX_TOLERANCE      = 24,
    parameter integer X_WIDTH             = 11,
    parameter integer Y_WIDTH             = 11
) (
    input                    clk,
    input                    rst_n,
    input                    feature_valid,
    input                    feature_component_valid,
    input      [31:0]        edge_count,
    input      [31:0]        direction_total,
    input      [31:0]        orthogonal_count,
    input      [31:0]        vertex_count,
    input      [31:0]        convex_turns,
    input      [31:0]        concave_turns,
    input      [31:0]        contour_length,
    input                    contour_closed,
     
     
    input                    radial_valid,
    input      [31:0]        radial_error_permille,
    input      [X_WIDTH-1:0] bbox_x_min,
    input      [X_WIDTH-1:0] bbox_x_max,
    input      [Y_WIDTH-1:0] bbox_y_min,
    input      [Y_WIDTH-1:0] bbox_y_max,
    output reg               result_valid,
    output reg [2:0]         result_shape,
    output reg [7:0]         result_confidence,
    output reg [X_WIDTH-1:0] result_x_min,
    output reg [X_WIDTH-1:0] result_x_max,
    output reg [Y_WIDTH-1:0] result_y_min,
    output reg [Y_WIDTH-1:0] result_y_max
);
    localparam [2:0] SHAPE_UNKNOWN  = 3'd0;
    localparam [2:0] SHAPE_CIRCLE   = 3'd1;
    localparam [2:0] SHAPE_RECT     = 3'd2;
    localparam [2:0] SHAPE_TRIANGLE = 3'd3;
    localparam [2:0] SHAPE_STAR     = 3'd4;

    reg [2:0] pending_shape;
    reg pending_valid;
    reg [7:0] stable_count;
    reg [X_WIDTH-1:0] pending_x_min, pending_x_max;
    reg [Y_WIDTH-1:0] pending_y_min, pending_y_max;

    wire [X_WIDTH:0] bbox_width = {1'b0, bbox_x_max} -
                                   {1'b0, bbox_x_min} + 1'b1;
    wire [Y_WIDTH:0] bbox_height = {1'b0, bbox_y_max} -
                                    {1'b0, bbox_y_min} + 1'b1;
    wire [31:0] bbox_w32 = bbox_width;
    wire [31:0] bbox_h32 = bbox_height;
    wire [31:0] bbox_diff = (bbox_w32 >= bbox_h32) ?
                             (bbox_w32 - bbox_h32) : (bbox_h32 - bbox_w32);
    wire [31:0] bbox_max = (bbox_w32 >= bbox_h32) ? bbox_w32 : bbox_h32;

     
     
     
    wire aspect_ok = (bbox_max != 0) &&
                     ((bbox_diff << 1) <= bbox_max);
    wire enough_data = feature_component_valid &&
                       (edge_count >= MIN_EDGE_COUNT) &&
                       (contour_length >= MIN_CONTOUR_LENGTH) &&
                       contour_closed;
     
     
     
     
    wire direction_ok = (direction_total != 0) &&
                        (orthogonal_count >=
                         (direction_total - (direction_total >> 2)));
    wire rect_candidate = enough_data &&
                          (vertex_count >= RECT_MIN_VERTICES) &&
                          (vertex_count <= RECT_MAX_VERTICES) &&
                          (convex_turns >= 3) &&
                          (concave_turns <= 2) && direction_ok;
    wire triangle_candidate = enough_data && !rect_candidate &&
                              (vertex_count >= TRI_MIN_VERTICES) &&
                              (vertex_count <= TRI_MAX_VERTICES) &&
                              (convex_turns >= 2) &&
                              (convex_turns <= 4) &&
                              (concave_turns <= 1);
    wire star_candidate = enough_data && !rect_candidate &&
                          (convex_turns >= STAR_MIN_CONVEX) &&
                          (concave_turns >= STAR_MIN_CONCAVE) &&
                          (vertex_count >= (STAR_MIN_CONVEX + STAR_MIN_CONCAVE));
    wire circle_candidate = enough_data && !rect_candidate &&
                            (vertex_count <= (CIRCLE_MAX_VERTICES + 1)) &&
                            (convex_turns <= 3) && (concave_turns == 0) &&
                            radial_valid &&
                            (radial_error_permille <= CIRCLE_RADIAL_ERROR_PERMILLE) &&
                            aspect_ok;

    reg [2:0] candidate_shape;
    reg [7:0] candidate_confidence;
    always @* begin
        candidate_shape = SHAPE_UNKNOWN;
        candidate_confidence = 8'd0;
        if (rect_candidate) begin
            candidate_shape = SHAPE_RECT;
            candidate_confidence = 8'd88;
        end else if (circle_candidate) begin
            candidate_shape = SHAPE_CIRCLE;
            candidate_confidence = 8'd80;
        end else if (triangle_candidate) begin
            candidate_shape = SHAPE_TRIANGLE;
            candidate_confidence = 8'd84;
        end else if (star_candidate) begin
            candidate_shape = SHAPE_STAR;
            candidate_confidence = 8'd82;
        end
    end

    function automatic [X_WIDTH-1:0] abs_diff_x;
        input [X_WIDTH-1:0] a;
        input [X_WIDTH-1:0] b;
        begin
            abs_diff_x = (a >= b) ? (a - b) : (b - a);
        end
    endfunction
    function automatic [Y_WIDTH-1:0] abs_diff_y;
        input [Y_WIDTH-1:0] a;
        input [Y_WIDTH-1:0] b;
        begin
            abs_diff_y = (a >= b) ? (a - b) : (b - a);
        end
    endfunction

    wire bbox_same = pending_valid &&
        (abs_diff_x(bbox_x_min, pending_x_min) <= BBOX_TOLERANCE) &&
        (abs_diff_x(bbox_x_max, pending_x_max) <= BBOX_TOLERANCE) &&
        (abs_diff_y(bbox_y_min, pending_y_min) <= BBOX_TOLERANCE) &&
        (abs_diff_y(bbox_y_max, pending_y_max) <= BBOX_TOLERANCE);
    wire candidate_same = pending_valid && bbox_same &&
                          (candidate_shape == pending_shape) &&
                          (candidate_shape != SHAPE_UNKNOWN);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pending_shape <= SHAPE_UNKNOWN;
            pending_valid <= 1'b0;
            stable_count <= 8'd0;
            pending_x_min <= {X_WIDTH{1'b0}};
            pending_x_max <= {X_WIDTH{1'b0}};
            pending_y_min <= {Y_WIDTH{1'b0}};
            pending_y_max <= {Y_WIDTH{1'b0}};
            result_valid <= 1'b0;
            result_shape <= SHAPE_UNKNOWN;
            result_confidence <= 8'd0;
            result_x_min <= {X_WIDTH{1'b0}};
            result_x_max <= {X_WIDTH{1'b0}};
            result_y_min <= {Y_WIDTH{1'b0}};
            result_y_max <= {Y_WIDTH{1'b0}};
        end else begin
            result_valid <= 1'b0;
            if (feature_valid) begin
            if (candidate_shape == SHAPE_UNKNOWN) begin
                pending_shape <= SHAPE_UNKNOWN;
                pending_valid <= 1'b0;
                stable_count <= 8'd0;
            end else if (candidate_same) begin
                if (stable_count != 8'hff)
                    stable_count <= stable_count + 1'b1;
                if (stable_count >= STABLE_FRAMES - 1) begin
                    result_valid <= 1'b1;
                    result_shape <= candidate_shape;
                    result_confidence <= candidate_confidence;
                    result_x_min <= bbox_x_min;
                    result_x_max <= bbox_x_max;
                    result_y_min <= bbox_y_min;
                    result_y_max <= bbox_y_max;
                end
                pending_x_min <= bbox_x_min;
                pending_x_max <= bbox_x_max;
                pending_y_min <= bbox_y_min;
                pending_y_max <= bbox_y_max;
            end else begin
                pending_shape <= candidate_shape;
                pending_valid <= 1'b1;
                stable_count <= 8'd1;
                pending_x_min <= bbox_x_min;
                pending_x_max <= bbox_x_max;
                pending_y_min <= bbox_y_min;
                pending_y_max <= bbox_y_max;
            end
            end
        end
    end
endmodule
