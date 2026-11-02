 
 
module edge_frame_stats #(
    parameter integer IMAGE_WIDTH      = 1920,
    parameter integer IMAGE_HEIGHT     = 1080,
    parameter integer MIN_EDGE_PIXELS  = 64,
    parameter integer ROI_X_MIN        = 0,
    parameter integer ROI_Y_MIN        = 0,
    parameter integer ROI_WIDTH        = IMAGE_WIDTH,
    parameter integer ROI_HEIGHT       = IMAGE_HEIGHT
) (
    input             clk,
    input             rst_n,
    input             in_vsync,
    input             in_hsync,
    input             in_href,
    input             edge_valid,
    input      [7:0]  edge_data,
    output reg        frame_done,
    output reg        bbox_valid,
    output reg [10:0] x_min,
    output reg [10:0] x_max,
    output reg [10:0] y_min,
    output reg [10:0] y_max,
    output reg [31:0] edge_count
);

    localparam [10:0] WIDTH_LIMIT  = IMAGE_WIDTH;
    localparam [10:0] HEIGHT_LIMIT = IMAGE_HEIGHT;
    localparam [10:0] ROI_X_MAX = ROI_X_MIN + ROI_WIDTH - 1;
    localparam [10:0] ROI_Y_MAX = ROI_Y_MIN + ROI_HEIGHT - 1;

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

    wire in_roi = (x_count >= ROI_X_MIN) && (x_count <= ROI_X_MAX) &&
                  (y_count >= ROI_Y_MIN) && (y_count <= ROI_Y_MAX);
    wire strong_edge = edge_valid && (edge_data == 8'hff) && in_roi;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prev_vsync      <= 1'b0;
            previous_href   <= 1'b0;
            x_count         <= 11'd0;
            y_count         <= 11'd0;
            have_edge       <= 1'b0;
            work_x_min      <= WIDTH_LIMIT;
            work_x_max      <= 11'd0;
            work_y_min      <= HEIGHT_LIMIT;
            work_y_max      <= 11'd0;
            work_edge_count <= 32'd0;
            frame_done      <= 1'b0;
            bbox_valid      <= 1'b0;
            x_min           <= 11'd0;
            x_max           <= 11'd0;
            y_min           <= 11'd0;
            y_max           <= 11'd0;
            edge_count      <= 32'd0;
        end else begin
            prev_vsync <= in_vsync;
            frame_done <= 1'b0;

             
             
            if (prev_vsync && !in_vsync) begin
                frame_done <= 1'b1;
                bbox_valid <= have_edge && (work_edge_count >= MIN_EDGE_PIXELS);
                x_min      <= have_edge ? work_x_min : 11'd0;
                x_max      <= have_edge ? work_x_max : 11'd0;
                y_min      <= have_edge ? work_y_min : 11'd0;
                y_max      <= have_edge ? work_y_max : 11'd0;
                edge_count <= work_edge_count;

                previous_href   <= 1'b0;
                x_count         <= 11'd0;
                y_count         <= 11'd0;
                have_edge       <= 1'b0;
                work_x_min      <= WIDTH_LIMIT;
                work_x_max      <= 11'd0;
                work_y_min      <= HEIGHT_LIMIT;
                work_y_max      <= 11'd0;
                work_edge_count <= 32'd0;
            end else if (!in_vsync) begin
                previous_href <= 1'b0;
                x_count       <= 11'd0;
                y_count       <= 11'd0;
            end else begin
                if (!in_href) begin
                    x_count <= 11'd0;
                    if (previous_href && (y_count < IMAGE_HEIGHT - 1))
                        y_count <= y_count + 1'b1;
                    previous_href <= 1'b0;
                end else begin
                    previous_href <= 1'b1;

                    if (strong_edge) begin
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
                    end

                    if (x_count < IMAGE_WIDTH - 1)
                        x_count <= x_count + 1'b1;
                    else
                        x_count <= 11'd0;
                end
            end
        end
    end

endmodule
