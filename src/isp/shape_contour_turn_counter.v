 
 
 
 
 
 
module shape_contour_turn_counter #(
    parameter integer ACCUM_THRESHOLD = 2
) (
    input             clk,
    input             rst_n,
    input             contour_start,
    input             contour_step_valid,
    input      [2:0]  contour_direction,
    input             contour_clockwise,
    input             contour_done,
    output reg        turn_valid,
    output reg [1:0]  turn_type,
    output reg [31:0] vertex_count,
    output reg [31:0] convex_turns,
    output reg [31:0] concave_turns
);
    reg have_previous;
    reg [2:0] previous_direction;
    reg signed [5:0] turn_accum;
    integer signed_delta;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            have_previous <= 1'b0;
            previous_direction <= 3'd0;
            turn_accum <= 6'sd0;
            turn_valid <= 1'b0;
            turn_type <= 2'b00;
            vertex_count <= 32'd0;
            convex_turns <= 32'd0;
            concave_turns <= 32'd0;
        end else begin
            turn_valid <= 1'b0;
            turn_type <= 2'b00;

            if (contour_start) begin
                have_previous <= 1'b0;
                previous_direction <= contour_direction;
                turn_accum <= 6'sd0;
                vertex_count <= 32'd0;
                convex_turns <= 32'd0;
                concave_turns <= 32'd0;
            end

            if (contour_step_valid) begin
                if (!have_previous) begin
                    have_previous <= 1'b1;
                    previous_direction <= contour_direction;
                end else if (contour_direction != previous_direction) begin
                     
                    signed_delta = contour_direction - previous_direction;
                    if (signed_delta > 4) signed_delta = signed_delta - 8;
                    if (signed_delta < -4) signed_delta = signed_delta + 8;
                    previous_direction <= contour_direction;
                    if (contour_clockwise)
                        signed_delta = -signed_delta;
                    turn_accum <= turn_accum + signed_delta;

                    if ((turn_accum + signed_delta) >= ACCUM_THRESHOLD) begin
                        turn_valid <= 1'b1;
                        turn_type <= 2'b01;
                        vertex_count <= vertex_count + 1'b1;
                        convex_turns <= convex_turns + 1'b1;
                        turn_accum <= 6'sd0;
                    end else if ((turn_accum + signed_delta) <= -ACCUM_THRESHOLD) begin
                        turn_valid <= 1'b1;
                        turn_type <= 2'b10;
                        vertex_count <= vertex_count + 1'b1;
                        concave_turns <= concave_turns + 1'b1;
                        turn_accum <= 6'sd0;
                    end
                end
            end

            if (contour_done) begin
                have_previous <= 1'b0;
                turn_accum <= 6'sd0;
            end
        end
    end
endmodule
