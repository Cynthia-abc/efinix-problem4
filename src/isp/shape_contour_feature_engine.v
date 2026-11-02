 
 
 
 
 
 
module shape_contour_feature_engine #(
    parameter integer X_WIDTH = 11,
    parameter integer Y_WIDTH = 11,
    parameter integer MAX_CONTOUR_STEPS = 65536,
    parameter integer RADIAL_MIN_POINTS = 32
) (
    input                    clk,
    input                    rst_n,
    input                    replay_start,
    input                    replay_valid,
    input                    replay_edge,
    input      [X_WIDTH-1:0] replay_x,
    input      [Y_WIDTH-1:0] replay_y,
    input                    replay_done,
    output                   random_read_req,
    output [X_WIDTH-1:0]     random_read_x,
    output [Y_WIDTH-1:0]     random_read_y,
    input                    random_read_valid,
    input                    random_read_data,
    input      [X_WIDTH-1:0] bbox_x_min,
    input      [X_WIDTH-1:0] bbox_x_max,
    input      [Y_WIDTH-1:0] bbox_y_min,
    input      [Y_WIDTH-1:0] bbox_y_max,
    output reg               feature_valid,
    output reg               contour_valid,
    output reg [31:0]        contour_steps,
    output reg [31:0]        direction_total,
    output reg [31:0]        orthogonal_count,
    output reg [31:0]        vertex_count,
    output reg [31:0]        convex_turns,
    output reg [31:0]        concave_turns,
    output reg               radial_valid,
    output reg [31:0]        radial_error_permille
);
    wire contour_start;
    wire contour_step_valid;
    wire [X_WIDTH-1:0] contour_point_x;
    wire [Y_WIDTH-1:0] contour_point_y;
    wire [2:0] contour_direction;
    wire contour_done;
    wire tracker_contour_valid;
    wire [31:0] tracker_contour_steps;

    shape_moore_contour_tracker #(
        .X_WIDTH(X_WIDTH), .Y_WIDTH(Y_WIDTH),
        .MAX_CONTOUR_STEPS(MAX_CONTOUR_STEPS)
    ) u_tracker (
        .clk(clk), .rst_n(rst_n), .replay_start(replay_start),
        .replay_valid(replay_valid), .replay_edge(replay_edge),
        .replay_x(replay_x), .replay_y(replay_y), .replay_done(replay_done),
        .random_read_req(random_read_req), .random_read_x(random_read_x),
        .random_read_y(random_read_y), .random_read_valid(random_read_valid),
        .random_read_data(random_read_data), .contour_start(contour_start),
        .contour_step_valid(contour_step_valid),
        .contour_point_x(contour_point_x), .contour_point_y(contour_point_y),
        .contour_direction(contour_direction), .contour_done(contour_done),
        .contour_valid(tracker_contour_valid), .contour_steps(tracker_contour_steps)
    );

    wire turn_valid;
    wire [1:0] turn_type;
    wire [31:0] turn_vertex_count;
    wire [31:0] turn_convex_count;
    wire [31:0] turn_concave_count;
    shape_contour_turn_counter u_turns (
        .clk(clk), .rst_n(rst_n), .contour_start(contour_start),
        .contour_step_valid(contour_step_valid),
        .contour_direction(contour_direction), .contour_clockwise(1'b0),
        .contour_done(contour_done), .turn_valid(turn_valid),
        .turn_type(turn_type), .vertex_count(turn_vertex_count),
        .convex_turns(turn_convex_count), .concave_turns(turn_concave_count)
    );

    wire [X_WIDTH:0] center_x = ({1'b0, bbox_x_min} +
                                  {1'b0, bbox_x_max}) >> 1;
    wire [Y_WIDTH:0] center_y = ({1'b0, bbox_y_min} +
                                  {1'b0, bbox_y_max}) >> 1;
    wire signed [X_WIDTH:0] delta_x = $signed({1'b0, contour_point_x}) -
                                       $signed(center_x);
    wire signed [Y_WIDTH:0] delta_y = $signed({1'b0, contour_point_y}) -
                                       $signed(center_y);
    wire [31:0] radius_squared = (delta_x * delta_x) + (delta_y * delta_y);
    wire radial_result_valid;
    wire [31:0] radial_result_error;
    shape_radial_consistency #(.MIN_POINTS(RADIAL_MIN_POINTS)) u_radial (
        .clk(clk), .rst_n(rst_n), .contour_start(contour_start),
        .contour_point_valid(contour_step_valid),
        .radius_squared(radius_squared), .contour_done(contour_done),
        .radial_valid(radial_result_valid),
        .radial_error_permille(radial_result_error),
        .radius_min(), .radius_max(), .radius_count()
    );

    reg [31:0] direction_count0, direction_count1;
    reg [31:0] direction_count2, direction_count3;
    wire [31:0] direction_total_work = direction_count0 + direction_count1 +
                                       direction_count2 + direction_count3;
    wire [31:0] orthogonal_work_a = direction_count0 + direction_count2;
    wire [31:0] orthogonal_work_b = direction_count1 + direction_count3;

    reg publish_pending;
    reg publish_valid_pending;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            publish_pending <= 1'b0;
            publish_valid_pending <= 1'b0;
            feature_valid <= 1'b0;
            contour_valid <= 1'b0;
            contour_steps <= 32'd0;
            direction_total <= 32'd0;
            orthogonal_count <= 32'd0;
            vertex_count <= 0;
            convex_turns <= 0;
            concave_turns <= 0;
            radial_valid <= 1'b0;
            radial_error_permille <= 32'hffff_ffff;
            direction_count0 <= 0;
            direction_count1 <= 0;
            direction_count2 <= 0;
            direction_count3 <= 0;
        end else begin
            feature_valid <= 1'b0;
            if (contour_start) begin
                direction_count0 <= 0;
                direction_count1 <= 0;
                direction_count2 <= 0;
                direction_count3 <= 0;
            end
            if (contour_step_valid) begin
                case (contour_direction)
                    3'd0, 3'd4: direction_count0 <= direction_count0 + 1'b1;
                    3'd1, 3'd5: direction_count1 <= direction_count1 + 1'b1;
                    3'd2, 3'd6: direction_count2 <= direction_count2 + 1'b1;
                    default: direction_count3 <= direction_count3 + 1'b1;
                endcase
            end
            if (publish_pending) begin
                feature_valid <= 1'b1;
                contour_valid <= publish_valid_pending;
                contour_steps <= tracker_contour_steps;
                direction_total <= direction_total_work;
                orthogonal_count <= (orthogonal_work_a >= orthogonal_work_b) ?
                                     orthogonal_work_a : orthogonal_work_b;
                vertex_count <= turn_vertex_count;
                convex_turns <= turn_convex_count;
                concave_turns <= turn_concave_count;
                radial_valid <= radial_result_valid;
                radial_error_permille <= radial_result_error;
                publish_pending <= 1'b0;
            end
            if (contour_done) begin
                publish_pending <= 1'b1;
                publish_valid_pending <= tracker_contour_valid;
            end
        end
    end
endmodule
