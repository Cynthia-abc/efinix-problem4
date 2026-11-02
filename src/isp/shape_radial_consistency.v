 
 
 
 
 
 
 
 
 
 
 
 
module shape_radial_consistency #(
    parameter integer MIN_POINTS = 32,
    parameter integer MAX_ERROR_PERMILLE = 180
) (
    input             clk,
    input             rst_n,
    input             contour_start,
    input             contour_point_valid,
    input      [31:0] radius_squared,
    input             contour_done,
    output reg        radial_valid,
    output reg [31:0] radial_error_permille,
    output reg [31:0] radius_min,
    output reg [31:0] radius_max,
    output reg [31:0] radius_count
);
    reg [31:0] work_min, work_max, work_count;
    reg have_point;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            work_min <= 32'hffff_ffff;
            work_max <= 32'd0;
            work_count <= 32'd0;
            have_point <= 1'b0;
            radial_valid <= 1'b0;
            radial_error_permille <= 32'd0;
            radius_min <= 32'd0;
            radius_max <= 32'd0;
            radius_count <= 32'd0;
        end else begin
            radial_valid <= 1'b0;
            if (contour_start) begin
                work_min <= 32'hffff_ffff;
                work_max <= 32'd0;
                work_count <= 32'd0;
                have_point <= 1'b0;
            end
            if (contour_point_valid) begin
                have_point <= 1'b1;
                work_count <= work_count + 1'b1;
                if (radius_squared < work_min) work_min <= radius_squared;
                if (radius_squared > work_max) work_max <= radius_squared;
            end
            if (contour_done) begin
                radius_min <= work_min;
                radius_max <= work_max;
                radius_count <= work_count;
                if (have_point && (work_count >= MIN_POINTS) &&
                    (work_max != 0)) begin
                     
                     
                     
                    if ((work_max - work_min) <= (work_max >> 2))
                        radial_error_permille <= 32'd0;
                    else
                        radial_error_permille <= MAX_ERROR_PERMILLE + 1;
                    radial_valid <= 1'b1;
                end else begin
                    radial_error_permille <= 32'hffff_ffff;
                end
            end
        end
    end
endmodule
