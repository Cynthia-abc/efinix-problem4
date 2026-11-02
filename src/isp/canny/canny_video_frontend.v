 
 
 
 
 
 
 
 
module canny_video_frontend #(
    parameter integer IMAGE_WIDTH=1920,IMAGE_HEIGHT=1080,H_TOTAL=2200
) (
    input clk,input rst_n,input [7:0] gray_data,
    input [7:0] in_r,in_g,in_b,
    input in_vsync,input in_hsync,input in_href,
    input [9:0] vio_th_high,input [9:0] vio_th_low,
    output reg [7:0] edge_data,output reg edge_valid,
    output reg [7:0] aligned_r,aligned_g,aligned_b,
    output out_vsync,output out_hsync,output out_href,
    output probe_pix_valid,output probe_pix_sof,output probe_pix_sol,
    output [7:0] probe_gauss_out,output [9:0] probe_sobel_mag,
    output [9:0] probe_nms_mag,output probe_edge_out,
    output reg [15:0] probe_frame_id
);
    localparam integer PAD=4,CORE_LATENCY=20;
    localparam integer PAD_WIDTH=IMAGE_WIDTH+PAD;
    localparam integer RGB_PIXEL_DELAY=PAD*PAD_WIDTH+PAD;
    localparam integer VIDEO_DELAY=PAD*H_TOTAL+PAD+CORE_LATENCY+1;
    reg frame_seen,envelope_active;
    reg [15:0] phase,row;
    wire source_valid=in_vsync && in_href;
    wire source_sof=source_valid && !frame_seen;
    wire [15:0] ex=source_sof ? 16'd0:phase;
    wire [15:0] ey=source_sof ? 16'd0:row;
    wire envelope_valid=(source_sof || envelope_active) && ex<PAD_WIDTH &&
        (ey>=IMAGE_HEIGHT || ex>=IMAGE_WIDTH || source_valid);
    wire envelope_sof=envelope_valid && source_sof;
    wire envelope_sol=envelope_valid && ex==0;
    wire [7:0] envelope_gray=(source_valid && ey<IMAGE_HEIGHT && ex<IMAGE_WIDTH)
                            ? gray_data:8'd0;
    wire [23:0] envelope_rgb=(source_valid && ey<IMAGE_HEIGHT && ex<IMAGE_WIDTH)
                            ? {in_r,in_g,in_b}:24'd0;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin frame_seen<=0;envelope_active<=0;phase<=0;row<=0;end
        else begin
            if(!in_vsync) frame_seen<=0;
            else if(source_valid) frame_seen<=1;
            if(source_sof) begin envelope_active<=1;phase<=1;row<=0;end
            else if(envelope_active) begin
                if(phase==H_TOTAL-1) begin
                    phase<=0;
                    if(row==IMAGE_HEIGHT+PAD-1) envelope_active<=0;
                    else row<=row+1'b1;
                end else phase<=phase+1'b1;
            end
        end
    end
    wire cv,cf,cl;wire [7:0] binary_edge;
    canny_top #(.IMAGE_WIDTH(PAD_WIDTH)) u_canny (
        .clk(clk),.rst_n(rst_n),.pix_valid(envelope_valid),.pix_sof(envelope_sof),
        .pix_sol(envelope_sol),.pix_gray(envelope_gray),
        .out_valid(cv),.out_sof(cf),.out_sol(cl),.out_data(binary_edge),
        .vio_th_high(vio_th_high),.vio_th_low(vio_th_low),
        .probe_pix_valid(probe_pix_valid),.probe_pix_sof(probe_pix_sof),
        .probe_pix_sol(probe_pix_sol),.probe_gauss_out(probe_gauss_out),
        .probe_sobel_mag(probe_sobel_mag),.probe_nms_mag(probe_nms_mag),
        .probe_edge_out(probe_edge_out));
    wire [23:0] delayed_rgb;
    canny_pixel_delay #(.WIDTH(24),.DEPTH(RGB_PIXEL_DELAY)) u_rgb_lines (
        .clk(clk),.rst_n(rst_n),.valid(envelope_valid),.restart(1'b0),.data(envelope_rgb),
        .delayed_data(delayed_rgb));
     
    reg [23:0] rgb_pipe[0:CORE_LATENCY-1];
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            for(i=0;i<CORE_LATENCY;i=i+1) rgb_pipe[i]<=0;
        end else begin
            rgb_pipe[0]<=delayed_rgb;
            for(i=1;i<CORE_LATENCY;i=i+1) rgb_pipe[i]<=rgb_pipe[i-1];
        end
    end
    reg [15:0] next_x,core_y;
    wire [15:0] cx=cl ? 16'd0:next_x;
    wire [15:0] cy=cf ? 16'd0:(cl ? core_y+16'd1:core_y);
    wire crop=cv && cx>=PAD && cx<IMAGE_WIDTH+PAD &&
                         cy>=PAD && cy<IMAGE_HEIGHT+PAD;
     
     
     
    wire edge_interior=cx>=2*PAD && cx<IMAGE_WIDTH && cy>=2*PAD && cy<IMAGE_HEIGHT;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            next_x<=0;core_y<=0;edge_data<=0;edge_valid<=0;
            aligned_r<=0;aligned_g<=0;aligned_b<=0;probe_frame_id<=0;
        end else begin
            if(cv) begin next_x<=(cx==PAD_WIDTH-1) ? 16'd0:cx+16'd1;core_y<=cy;end
            edge_valid<=crop;
             
            edge_data<=(crop && edge_interior && binary_edge[0]) ? 8'hff:8'h00;
            {aligned_r,aligned_g,aligned_b}<=crop ? rgb_pipe[CORE_LATENCY-1]:24'd0;
            if(crop && cx==PAD && cy==PAD) probe_frame_id<=probe_frame_id+1'b1;
        end
    end
    wire [2:0] delayed_sync;
    canny_pixel_delay #(.WIDTH(3),.DEPTH(VIDEO_DELAY)) u_sync_delay (
        .clk(clk),.rst_n(rst_n),.valid(1'b1),.restart(1'b0),.data({in_vsync,in_hsync,in_href}),
        .delayed_data(delayed_sync));
    reg [$clog2(VIDEO_DELAY+1)-1:0] sync_fill;
    always @(posedge clk or negedge rst_n)
        if(!rst_n) sync_fill<=0;
        else if(sync_fill<VIDEO_DELAY) sync_fill<=sync_fill+1'b1;
    assign {out_vsync,out_hsync,out_href}=(sync_fill==VIDEO_DELAY) ? delayed_sync:3'b000;
`ifndef SYNTHESIS
    initial begin
        if(H_TOTAL<IMAGE_WIDTH+PAD || IMAGE_WIDTH<8 || IMAGE_HEIGHT<8)
            $fatal(1,"Invalid Canny video dimensions/blanking");
    end
`endif
endmodule
