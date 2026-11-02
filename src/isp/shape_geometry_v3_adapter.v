 
 
 
module shape_geometry_v3_adapter #(
    parameter integer IMAGE_WIDTH = 1920,
    parameter integer IMAGE_HEIGHT = 1080,
    parameter integer ROI_X_MIN = 560,
    parameter integer ROI_Y_MIN = 240,
    parameter integer ROI_WIDTH = 800,
    parameter integer ROI_HEIGHT = 600,
     
     
     
     
    parameter integer RECOG_X_MIN = -1,
    parameter integer RECOG_Y_MIN = -1,
    parameter integer RECOG_WIDTH  = -1,
    parameter integer RECOG_HEIGHT = -1,
    parameter integer MIN_EDGE_COUNT = 128,
    parameter integer MIN_CONTOUR_LENGTH = 32,
    parameter integer STABLE_FRAMES = 2
) (
    input                    clk,
    input                    rst_n,
    input                    in_vsync,
    input                    in_href,
    input                    edge_valid,
    input      [7:0]         edge_data,
    output                   result_valid,
    output [2:0]             result_shape,
    output [7:0]             result_confidence,
    output [10:0]            result_x_min,
    output [10:0]            result_x_max,
    output [10:0]            result_y_min,
    output [10:0]            result_y_max,
    output [15:0]            result_frame_id,
    output [15:0]            input_frame_id,
    output [15:0]            processing_frame_id,
    output [1:0]             buffer0_state,
    output [1:0]             buffer1_state,
    output                   recognition_busy,
    output                   input_overrun,
    output [31:0]            last_processing_cycles,
    output                   display_valid,
    output [2:0]             display_shape,
    output [10:0]            display_x_min,
    output [10:0]            display_x_max,
    output [10:0]            display_y_min,
    output [10:0]            display_y_max,
    output [15:0]            display_frame_id
);
    localparam integer ACTIVE_RECOG_X_MIN = (RECOG_X_MIN < 0) ? ROI_X_MIN : RECOG_X_MIN;
    localparam integer ACTIVE_RECOG_Y_MIN = (RECOG_Y_MIN < 0) ? ROI_Y_MIN : RECOG_Y_MIN;
    localparam integer ACTIVE_RECOG_WIDTH  = (RECOG_WIDTH < 0) ? ROI_WIDTH : RECOG_WIDTH;
    localparam integer ACTIVE_RECOG_HEIGHT = (RECOG_HEIGHT < 0) ? ROI_HEIGHT : RECOG_HEIGHT;
    reg [10:0] pixel_x;
    reg [10:0] pixel_y;
    reg href_d;
    reg display_valid_reg;
    reg [2:0] display_shape_reg;
    reg [10:0] display_x_min_reg, display_x_max_reg;
    reg [10:0] display_y_min_reg, display_y_max_reg;
    reg [15:0] display_frame_id_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_x <= 11'd0;
            pixel_y <= 11'd0;
            href_d <= 1'b0;
        end else begin
            href_d <= in_href;
            if (!in_vsync) begin
                pixel_x <= 11'd0;
                pixel_y <= 11'd0;
            end else if (in_href) begin
                if (pixel_x >= IMAGE_WIDTH - 1)
                    pixel_x <= 11'd0;
                else
                    pixel_x <= pixel_x + 1'b1;
            end else if (href_d) begin
                pixel_x <= 11'd0;
                if (pixel_y < IMAGE_HEIGHT - 1)
                    pixel_y <= pixel_y + 1'b1;
                else
                    pixel_y <= 11'd0;
            end
        end
    end

     
     
     
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            display_valid_reg <= 1'b0;
            display_shape_reg <= 3'd0;
            display_x_min_reg <= 11'd0;
            display_x_max_reg <= 11'd0;
            display_y_min_reg <= 11'd0;
            display_y_max_reg <= 11'd0;
            display_frame_id_reg <= 16'd0;
        end else if (result_valid) begin
            display_valid_reg <= 1'b1;
            display_shape_reg <= result_shape;
            display_x_min_reg <= result_x_min;
            display_x_max_reg <= result_x_max;
            display_y_min_reg <= result_y_min;
            display_y_max_reg <= result_y_max;
            display_frame_id_reg <= result_frame_id;
        end
    end

    shape_geometry_pingpong_pipeline #(
        .ROI_X_MIN(ACTIVE_RECOG_X_MIN), .ROI_Y_MIN(ACTIVE_RECOG_Y_MIN),
        .ROI_WIDTH(ACTIVE_RECOG_WIDTH), .ROI_HEIGHT(ACTIVE_RECOG_HEIGHT),
        .X_WIDTH(11), .Y_WIDTH(11), .ADDR_WIDTH(19),
         
         
         
        .MAX_RUNS_PER_ROW(16), .MAX_LABELS(16),
        .MAX_CONTOUR_STEPS(65536), .MIN_EDGE_COUNT(MIN_EDGE_COUNT),
        .MIN_CONTOUR_LENGTH(MIN_CONTOUR_LENGTH), .STABLE_FRAMES(STABLE_FRAMES),
        .FRAME_ID_WIDTH(16)
    ) u_geometry (
        .clk(clk), .rst_n(rst_n),
        .in_vsync(in_vsync), .in_href(in_href),
        .edge_pixel(edge_valid && (edge_data == 8'hff)),
        .pixel_x(pixel_x), .pixel_y(pixel_y),
        .candidate_ready(),
        .result_valid(result_valid), .result_shape(result_shape),
        .result_confidence(result_confidence),
        .result_x_min(result_x_min), .result_x_max(result_x_max),
        .result_y_min(result_y_min), .result_y_max(result_y_max),
        .result_frame_id(result_frame_id), .input_frame_id(input_frame_id),
        .processing_frame_id(processing_frame_id),
        .buffer0_state(buffer0_state), .buffer1_state(buffer1_state),
        .recognition_busy(recognition_busy), .input_overrun(input_overrun),
        .last_processing_cycles(last_processing_cycles)
    );

    assign display_valid = display_valid_reg;
    assign display_shape = display_shape_reg;
    assign display_x_min = display_x_min_reg;
    assign display_x_max = display_x_max_reg;
    assign display_y_min = display_y_min_reg;
    assign display_y_max = display_y_max_reg;
    assign display_frame_id = display_frame_id_reg;
endmodule
