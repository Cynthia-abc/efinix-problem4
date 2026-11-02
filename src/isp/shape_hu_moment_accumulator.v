 
 
 
 
 
 
 
 
 
 
 
 
 
module shape_hu_moment_accumulator #(
    parameter integer ROI_X_MIN = 640,
    parameter integer ROI_Y_MIN = 320,
    parameter integer ROI_WIDTH  = 640,
    parameter integer ROI_HEIGHT = 440,
    parameter integer X_WIDTH = 11,
    parameter integer Y_WIDTH = 11
) (
    input                    clk,
    input                    rst_n,
    input                    in_vsync,
    input                    in_href,
    input                    pixel_valid,
    input                    component_selected,
    input      [X_WIDTH-1:0] pixel_x,
    input      [Y_WIDTH-1:0] pixel_y,
    output reg               feature_valid,
    output reg               feature_component_valid,
    output reg [63:0]        feature_m00,
    output reg [63:0]        feature_m10,
    output reg [63:0]        feature_m01,
    output reg [63:0]        feature_m20,
    output reg [63:0]        feature_m11,
    output reg [63:0]        feature_m02,
    output reg [63:0]        feature_m30,
    output reg [63:0]        feature_m21,
    output reg [63:0]        feature_m12,
    output reg [63:0]        feature_m03,
    output reg [31:0]        feature_pixel_count,
    output reg [X_WIDTH-1:0] feature_x_min,
    output reg [X_WIDTH-1:0] feature_x_max,
    output reg [Y_WIDTH-1:0] feature_y_min,
    output reg [Y_WIDTH-1:0] feature_y_max
);
    reg previous_vsync;
    reg have_component;
    reg [63:0] m00, m10, m01, m20, m11, m02;
    reg [63:0] m30, m21, m12, m03;
    reg [31:0] pixel_count;
    reg [X_WIDTH-1:0] x_min, x_max;
    reg [Y_WIDTH-1:0] y_min, y_max;

    wire frame_end = previous_vsync && !in_vsync;
    wire pixel_in_window = (pixel_x >= ROI_X_MIN) &&
                           (pixel_x < ROI_X_MIN + ROI_WIDTH) &&
                           (pixel_y >= ROI_Y_MIN) &&
                           (pixel_y < ROI_Y_MIN + ROI_HEIGHT);
    wire selected_pixel = in_vsync && in_href && pixel_valid &&
                          component_selected && pixel_in_window;

     
     
    wire [X_WIDTH-1:0] x_local = pixel_x - ROI_X_MIN;
    wire [Y_WIDTH-1:0] y_local = pixel_y - ROI_Y_MIN;
    wire [2*X_WIDTH-1:0] x2 = x_local * x_local;
    wire [2*Y_WIDTH-1:0] y2 = y_local * y_local;
    wire [X_WIDTH+Y_WIDTH-1:0] xy = x_local * y_local;
    wire [3*X_WIDTH-1:0] x3 = x2 * x_local;
    wire [2*X_WIDTH+Y_WIDTH-1:0] x2y = x2 * y_local;
    wire [X_WIDTH+2*Y_WIDTH-1:0] xy2 = x_local * y2;
    wire [3*Y_WIDTH-1:0] y3 = y2 * y_local;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            previous_vsync <= 1'b0;
            have_component <= 1'b0;
            m00 <= 64'd0; m10 <= 64'd0; m01 <= 64'd0;
            m20 <= 64'd0; m11 <= 64'd0; m02 <= 64'd0;
            m30 <= 64'd0; m21 <= 64'd0; m12 <= 64'd0; m03 <= 64'd0;
            pixel_count <= 32'd0;
            x_min <= {X_WIDTH{1'b1}}; x_max <= {X_WIDTH{1'b0}};
            y_min <= {Y_WIDTH{1'b1}}; y_max <= {Y_WIDTH{1'b0}};
            feature_valid <= 1'b0;
            feature_component_valid <= 1'b0;
            feature_m00 <= 64'd0; feature_m10 <= 64'd0; feature_m01 <= 64'd0;
            feature_m20 <= 64'd0; feature_m11 <= 64'd0; feature_m02 <= 64'd0;
            feature_m30 <= 64'd0; feature_m21 <= 64'd0; feature_m12 <= 64'd0;
            feature_m03 <= 64'd0;
            feature_pixel_count <= 32'd0;
            feature_x_min <= {X_WIDTH{1'b0}}; feature_x_max <= {X_WIDTH{1'b0}};
            feature_y_min <= {Y_WIDTH{1'b0}}; feature_y_max <= {Y_WIDTH{1'b0}};
        end else begin
            previous_vsync <= in_vsync;
            feature_valid <= 1'b0;

            if (selected_pixel) begin
                have_component <= 1'b1;
                if (pixel_count != 32'hffff_ffff)
                    pixel_count <= pixel_count + 1'b1;
                m00 <= m00 + 64'd1;
                m10 <= m10 + {{(64-X_WIDTH){1'b0}}, x_local};
                m01 <= m01 + {{(64-Y_WIDTH){1'b0}}, y_local};
                m20 <= m20 + {{(64-2*X_WIDTH){1'b0}}, x2};
                m11 <= m11 + {{(64-X_WIDTH-Y_WIDTH){1'b0}}, xy};
                m02 <= m02 + {{(64-2*Y_WIDTH){1'b0}}, y2};
                m30 <= m30 + {{(64-3*X_WIDTH){1'b0}}, x3};
                m21 <= m21 + {{(64-2*X_WIDTH-Y_WIDTH){1'b0}}, x2y};
                m12 <= m12 + {{(64-X_WIDTH-2*Y_WIDTH){1'b0}}, xy2};
                m03 <= m03 + {{(64-3*Y_WIDTH){1'b0}}, y3};
                if (pixel_x < x_min) x_min <= pixel_x;
                if (pixel_x > x_max) x_max <= pixel_x;
                if (pixel_y < y_min) y_min <= pixel_y;
                if (pixel_y > y_max) y_max <= pixel_y;
            end

            if (frame_end) begin
                feature_valid <= 1'b1;
                feature_component_valid <= have_component;
                feature_m00 <= m00; feature_m10 <= m10; feature_m01 <= m01;
                feature_m20 <= m20; feature_m11 <= m11; feature_m02 <= m02;
                feature_m30 <= m30; feature_m21 <= m21; feature_m12 <= m12;
                feature_m03 <= m03;
                feature_pixel_count <= pixel_count;
                feature_x_min <= x_min; feature_x_max <= x_max;
                feature_y_min <= y_min; feature_y_max <= y_max;

                have_component <= 1'b0;
                m00 <= 64'd0; m10 <= 64'd0; m01 <= 64'd0;
                m20 <= 64'd0; m11 <= 64'd0; m02 <= 64'd0;
                m30 <= 64'd0; m21 <= 64'd0; m12 <= 64'd0; m03 <= 64'd0;
                pixel_count <= 32'd0;
                x_min <= {X_WIDTH{1'b1}}; x_max <= {X_WIDTH{1'b0}};
                y_min <= {Y_WIDTH{1'b1}}; y_max <= {Y_WIDTH{1'b0}};
            end
        end
    end
endmodule
