 
 
 
 
 
module hu_shape_frame #(
    parameter integer WIDTH=160, HEIGHT=110, MIN_AREA=64
) (
    input clk, input rst_n,
    input frame_start, input pixel_valid, input foreground, input frame_end,
    input [15:0] frame_id,
    output ready, output busy,
    output done, output target_valid, output [2:0] shape,
    output [15:0] result_frame_id,
    output [7:0] bbox_x_min,bbox_x_max,bbox_y_min,bbox_y_max,
    output [31:0] hu1_q24,hu2_q24,hu_det_q24,match_distance_q24,
    output [31:0] component_cycles,component_count,
    output input_error
);
    wire component_done, component_valid, component_busy, capture_ready;
    wire component_error;
    wire feature_busy,feature_done,feature_valid;
    wire match_valid;
    wire [47:0] m00,m10,m01,m20,m11,m02;
    reg transaction;
    reg protocol_error;
    wire accepted_start=frame_start && ready;
    assign ready=capture_ready && !transaction;
    assign busy=transaction;
    assign input_error=component_error || protocol_error;
    assign target_valid=match_valid && !input_error;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin transaction<=0; protocol_error<=0; end
        else begin
            if(accepted_start) begin transaction<=1; protocol_error<=0; end
            else if(frame_start) protocol_error<=1;
            if(done) transaction<=0;
        end
    end
    hu_component_frame #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.MIN_AREA(MIN_AREA)) u_components (
        .clk(clk),.rst_n(rst_n),.frame_start(accepted_start),
        .pixel_valid(pixel_valid),.foreground(foreground),.frame_end(frame_end),.frame_id(frame_id),
        .capture_ready(capture_ready),.busy(component_busy),.done(component_done),
        .target_valid(component_valid),.input_error(component_error),.result_frame_id(result_frame_id),
        .m00(m00),.m10(m10),.m01(m01),.m20(m20),.m11(m11),.m02(m02),
        .bbox_x_min(bbox_x_min),.bbox_x_max(bbox_x_max),
        .bbox_y_min(bbox_y_min),.bbox_y_max(bbox_y_max),
        .processing_cycles(component_cycles),.component_count(component_count)
    );
     
    hu_features u_features (
        .clk(clk),.rst_n(rst_n),.start(component_done),
        .m00(component_valid?m00:48'd0),.m10(m10),.m01(m01),.m20(m20),.m11(m11),.m02(m02),
        .busy(feature_busy),.done(feature_done),.feature_valid(feature_valid),
        .hu1_q24(hu1_q24),.hu2_q24(hu2_q24),.hu_det_q24(hu_det_q24)
    );
    hu_template_match u_match (
        .clk(clk),.rst_n(rst_n),.feature_done(feature_done),.feature_valid(feature_valid),
        .hu1_q24(hu1_q24),.hu2_q24(hu2_q24),.hu_det_q24(hu_det_q24),
        .done(done),.target_valid(match_valid),.shape(shape),.match_distance_q24(match_distance_q24)
    );
endmodule
