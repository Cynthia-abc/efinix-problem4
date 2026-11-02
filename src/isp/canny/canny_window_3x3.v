 
 
 
 
 
module canny_window_3x3 #(
    parameter integer WIDTH=8,IMAGE_WIDTH=1924
) (
    input clk,input rst_n,input pix_valid,input pix_sof,input pix_sol,
    input [WIDTH-1:0] pix_data,
    output reg out_valid,output reg out_sof,output reg out_sol,
    output reg window_full,
    output reg [WIDTH-1:0] p00,p01,p02,p10,p11,p12,p20,p21,p22
);
    wire [WIDTH-1:0] row1,row2;
    reg v0,f0,l0,v1,f1,l1;
    reg [WIDTH-1:0] current0,current1,middle1;
    canny_pixel_delay #(.WIDTH(WIDTH),.DEPTH(IMAGE_WIDTH)) u_line0 (
        .clk(clk),.rst_n(rst_n),.valid(pix_valid),.restart(pix_sol || pix_sof),
        .data(pix_data),.delayed_data(row1));
    canny_pixel_delay #(.WIDTH(WIDTH),.DEPTH(IMAGE_WIDTH)) u_line1 (
        .clk(clk),.rst_n(rst_n),.valid(v0),.restart(l0 || f0),
        .data(row1),.delayed_data(row2));
     
     
    reg [15:0] next_x,row_y;
    wire [15:0] x=l1 ? 16'd0:next_x;
    wire [15:0] y=f1 ? 16'd0:(l1 ? row_y+16'd1:row_y);
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            v0<=0;f0<=0;l0<=0;v1<=0;f1<=0;l1<=0;
            current0<=0;current1<=0;middle1<=0;
            next_x<=0;row_y<=0;out_valid<=0;out_sof<=0;out_sol<=0;window_full<=0;
            p00<=0;p01<=0;p02<=0;p10<=0;p11<=0;p12<=0;p20<=0;p21<=0;p22<=0;
        end else begin
            v0<=pix_valid;f0<=pix_valid && pix_sof;l0<=pix_valid && pix_sol;
            v1<=v0;f1<=f0;l1<=l0;
            current0<=pix_data;current1<=current0;middle1<=row1;
            out_valid<=v1;out_sof<=v1 && f1;out_sol<=v1 && l1;
            window_full<=v1 && x>=2 && y>=2;
            if(v1) begin
                next_x<=(x==IMAGE_WIDTH-1) ? 16'd0:x+16'd1;
                row_y<=y;
                if(l1) begin
                    p00<=0;p01<=0;p02<=row2;
                    p10<=0;p11<=0;p12<=middle1;
                    p20<=0;p21<=0;p22<=current1;
                end else begin
                    p00<=p01;p01<=p02;p02<=row2;
                    p10<=p11;p11<=p12;p12<=middle1;
                    p20<=p21;p21<=p22;p22<=current1;
                end
            end
        end
    end
endmodule
