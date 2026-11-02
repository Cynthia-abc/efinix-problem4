 
 
module hu_video_adapter #(
    parameter integer IMAGE_WIDTH=1920,IMAGE_HEIGHT=1080,
    parameter integer RECOG_X_MIN=640,RECOG_Y_MIN=320,
    parameter integer RECOG_WIDTH=640,RECOG_HEIGHT=440,
    parameter integer MIN_AREA=64, STABLE_FRAMES=2, LABEL_TTL=4
) (
    input clk,input rst_n,input process_clk,input process_rst_n,
    input in_vsync,input in_href,input edge_valid,input [7:0] edge_data,
    output result_event,output result_valid,output [2:0] result_shape,
    output [15:0] result_frame_id,output [15:0] input_frame_id,
    output [31:0] dropped_frames,malformed_frames,last_processing_cycles,
    output [31:0] last_hu_det,output [1:0] bank_locked,
    output reg display_valid,output reg [2:0] display_shape,
    output reg [10:0] display_x_min,display_x_max,display_y_min,display_y_max,
    output reg [15:0] display_frame_id
);
    localparam W=RECOG_WIDTH/4,H=RECOG_HEIGHT/4;
    reg [10:0] x,y;
    reg vsync_d,href_d;
    reg [15:0] frame_counter;
    wire frame_start=in_vsync && !vsync_d;
    wire frame_end=!in_vsync && vsync_d;
    assign input_frame_id=frame_counter;
    wire inside_roi=in_vsync && in_href && x>=RECOG_X_MIN &&
        x<RECOG_X_MIN+RECOG_WIDTH && y>=RECOG_Y_MIN && y<RECOG_Y_MIN+RECOG_HEIGHT;
    wire [10:0] rx=x-RECOG_X_MIN,ry=y-RECOG_Y_MIN;
    wire [$clog2(W)-1:0] column=rx>>2;
    reg horizontal_or;
    reg [W-1:0] vertical_or;
    reg pooled_valid,pooled_data;
    wire edge_bit=edge_valid && edge_data==8'hff;
    wire horizontal_value=horizontal_or || edge_bit;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            x<=0;y<=0;vsync_d<=0;href_d<=0;frame_counter<=0;
            horizontal_or<=0;vertical_or<=0;pooled_valid<=0;pooled_data<=0;
        end else begin
            vsync_d<=in_vsync;href_d<=in_href;pooled_valid<=0;
            if(frame_start) frame_counter<=frame_counter+1'b1;
            if(!in_vsync) begin x<=0;y<=0;horizontal_or<=0;end
            else if(in_href) begin
                if(x==IMAGE_WIDTH-1) x<=0;else x<=x+1'b1;
            end else if(href_d) begin x<=0;if(y==IMAGE_HEIGHT-1)y<=0;else y<=y+1'b1;end
            if(inside_roi) begin
                if(rx[1:0]==0) horizontal_or<=edge_bit;
                else horizontal_or<=horizontal_value;
                if(rx[1:0]==3) begin
                    horizontal_or<=0;
                    if(ry[1:0]==0) vertical_or[column]<=horizontal_value;
                    else vertical_or[column]<=vertical_or[column] || horizontal_value;
                    if(ry[1:0]==3) begin
                        pooled_valid<=1;pooled_data<=vertical_or[column] || horizontal_value;
                    end
                end
            end
        end
    end
    wire [7:0] bx0,bx1,by0,by1;
    hu_roi_pingpong #(.WIDTH(W),.HEIGHT(H),.MIN_AREA(MIN_AREA)) u_pingpong (
        .video_clk(clk),.video_rst_n(rst_n),.capture_start(frame_start),
        .sample_valid(pooled_valid),.sample_data(pooled_data),.capture_end(frame_end),
        .capture_frame_id(frame_counter+16'd1),.process_clk(process_clk),.process_rst_n(process_rst_n),
        .result_event(result_event),.result_valid(result_valid),.result_shape(result_shape),
        .result_frame_id(result_frame_id),.result_x_min(bx0),.result_x_max(bx1),
        .result_y_min(by0),.result_y_max(by1),.result_cycles(last_processing_cycles),
        .result_hu_det(last_hu_det),.dropped_frames(dropped_frames),.malformed_frames(malformed_frames),
        .bank_locked(bank_locked),.processing_busy()
    );
    reg pending,pending_valid;
    reg [2:0] pending_shape,previous_shape;
    reg [15:0] pending_tag;
    reg [7:0] px0,px1,py0,py1;
    reg [7:0] confirmations,age;
     
     
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            pending<=0;pending_valid<=0;pending_shape<=0;pending_tag<=0;
            px0<=0;px1<=0;py0<=0;py1<=0;previous_shape<=0;confirmations<=0;age<=0;
            display_valid<=0;display_shape<=0;display_frame_id<=0;
            display_x_min<=0;display_x_max<=0;display_y_min<=0;display_y_max<=0;
        end else begin
            if(frame_start) begin
                if(age<LABEL_TTL) age<=age+1'b1;
                if(age>=LABEL_TTL-1) begin display_valid<=0;confirmations<=0;previous_shape<=0;end
            end
            if(pending && !in_vsync) begin
                pending<=0;age<=0;display_frame_id<=pending_tag;
                if(!pending_valid) begin display_valid<=0;display_shape<=0;confirmations<=0;previous_shape<=0;end
                else begin
                    previous_shape<=pending_shape;
                    if(previous_shape==pending_shape && confirmations!=0) begin
                        if(confirmations<STABLE_FRAMES) confirmations<=confirmations+1'b1;
                        display_valid<=(confirmations>=STABLE_FRAMES-1);
                    end else begin confirmations<=1;display_valid<=(STABLE_FRAMES==1);end
                    display_shape<=pending_shape;
                    display_x_min<=RECOG_X_MIN+{bx_pad(px0),2'b00};
                    display_x_max<=RECOG_X_MIN+{bx_pad(px1),2'b11};
                    display_y_min<=RECOG_Y_MIN+{bx_pad(py0),2'b00};
                    display_y_max<=RECOG_Y_MIN+{bx_pad(py1),2'b11};
                end
            end
            if(result_event) begin
                pending<=1;pending_valid<=result_valid;pending_shape<=result_shape;pending_tag<=result_frame_id;
                px0<=bx0;px1<=bx1;py0<=by0;py1<=by1;
            end
        end
    end
    function [8:0] bx_pad;
        input [7:0] value;
        begin bx_pad={1'b0,value};end
    endfunction
endmodule
