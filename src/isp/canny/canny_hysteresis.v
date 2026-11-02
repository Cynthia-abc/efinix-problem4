 
 
 
 
 
 
 
 
module canny_hysteresis #(parameter integer IMAGE_WIDTH=1924) (
    input clk,input rst_n,input pix_valid,input pix_sof,input pix_sol,
    input [9:0] pix_mag,input [9:0] vio_th_high,input [9:0] vio_th_low,
    output reg out_valid,output reg out_sof,output reg out_sol,
    output reg [7:0] out_data
);
    localparam AW=$clog2(IMAGE_WIDTH);
    reg [9:0] frame_high,frame_low;
    wire [9:0] safe_high=(vio_th_high==0) ? 10'd1:vio_th_high;
    wire [9:0] safe_low=(vio_th_low>safe_high) ? safe_high:vio_th_low;
    wire [9:0] high_now=pix_sof ? safe_high:frame_high;
    wire [9:0] low_now=pix_sof ? safe_low:frame_low;
    wire [1:0] pixel_class={pix_mag!=0 && pix_mag>=high_now,
                           pix_mag!=0 && pix_mag>=low_now};
    always @(posedge clk or negedge rst_n)
        if(!rst_n) begin frame_high<=64;frame_low<=24;end
        else if(pix_valid && pix_sof) begin frame_high<=safe_high;frame_low<=safe_low;end
    wire v,f,l,full;
    wire [1:0] p00,p01,p02,p10,p11,p12,p20,p21,p22;
    canny_window_3x3 #(.WIDTH(2),.IMAGE_WIDTH(IMAGE_WIDTH)) u_window (
        .clk(clk),.rst_n(rst_n),.pix_valid(pix_valid),.pix_sof(pix_sof),
        .pix_sol(pix_sol),.pix_data(pixel_class),
        .out_valid(v),.out_sof(f),.out_sol(l),.window_full(full),
        .p00(p00),.p01(p01),.p02(p02),.p10(p10),.p11(p11),
        .p12(p12),.p20(p20),.p21(p21),.p22(p22));
    reg [15:0] next_x,row_y;
    wire [15:0] x=l ? 16'd0:next_x;
    wire [15:0] y=f ? 16'd0:(l ? row_y+16'd1:row_y);
    wire above;
    reg above_recent,above_older,left_accepted;
    reg vd,fd,ld,center_candidate,center_strong,near_strong,full_d;
    reg [15:0] xd,yd;
    reg write_valid,write_data;
    reg [AW-1:0] write_addr;
     
     
    canny_sdp_ram #(.WIDTH(1),.DEPTH(IMAGE_WIDTH)) u_accepted_row (
        .clk(clk),.rst_n(rst_n),.wr_en(write_valid),.wr_addr(write_addr),
        .wr_data(write_data),.rd_en(v),.rd_addr(x[AW-1:0]),.rd_data(above));
    wire use_above=yd>=2;
    wire connected=near_strong || (!ld && left_accepted) ||
        (use_above && ((xd<IMAGE_WIDTH-1 && above) ||
                       (!ld && above_recent) || (xd>=2 && above_older)));
    wire accepted=full_d && (center_strong || (center_candidate && connected));
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            next_x<=0;row_y<=0;vd<=0;fd<=0;ld<=0;xd<=0;yd<=0;
            center_candidate<=0;center_strong<=0;near_strong<=0;full_d<=0;
            above_recent<=0;above_older<=0;left_accepted<=0;
            write_valid<=0;write_addr<=0;write_data<=0;
            out_valid<=0;out_sof<=0;out_sol<=0;out_data<=0;
        end else begin
            vd<=v;fd<=f;ld<=l;xd<=x;yd<=y;full_d<=full;
            center_candidate<=p11[0];center_strong<=p11[1];
            near_strong<=p00[1]|p01[1]|p02[1]|p10[1]|p12[1]|p20[1]|p21[1]|p22[1];
            if(v) begin
                next_x<=(x==IMAGE_WIDTH-1) ? 16'd0:x+16'd1;row_y<=y;
            end
            out_valid<=vd;out_sof<=vd && fd;out_sol<=vd && ld;
            out_data<=(vd && accepted) ? 8'h01:8'h00;
            write_valid<=vd && xd>=1;
            if(vd) begin
                write_addr<=xd[AW-1:0]-1'b1;write_data<=accepted;
                left_accepted<=accepted;
                above_recent<=use_above && xd<IMAGE_WIDTH-1 && above;
                above_older<=ld ? 1'b0:above_recent;
            end
        end
    end
endmodule
