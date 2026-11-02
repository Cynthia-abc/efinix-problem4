 
 
 
module gauss_3x3 #(parameter integer IMAGE_WIDTH=1924) (
    input clk,input rst_n,input pix_valid,input pix_sof,input pix_sol,
    input [7:0] pix_gray,
    output reg out_valid,output reg out_sof,output reg out_sol,output reg [7:0] out_data
);
    wire v,f,l,full;
    wire [7:0] p00,p01,p02,p10,p11,p12,p20,p21,p22;
    canny_window_3x3 #(.WIDTH(8),.IMAGE_WIDTH(IMAGE_WIDTH)) u_window (
        .clk(clk),.rst_n(rst_n),.pix_valid(pix_valid),.pix_sof(pix_sof),
        .pix_sol(pix_sol),.pix_data(pix_gray),.out_valid(v),.out_sof(f),.out_sol(l),
        .window_full(full),.p00(p00),.p01(p01),.p02(p02),.p10(p10),.p11(p11),
        .p12(p12),.p20(p20),.p21(p21),.p22(p22));
    reg [9:0] h0,h1,h2;
    reg vd,fd,ld,full_d;
    wire [11:0] weighted={2'b0,h0}+{1'b0,h1,1'b0}+{2'b0,h2};
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            h0<=0;h1<=0;h2<=0;vd<=0;fd<=0;ld<=0;full_d<=0;
            out_valid<=0;out_sof<=0;out_sol<=0;out_data<=0;
        end else begin
            vd<=v;fd<=f;ld<=l;full_d<=full;
            h0<={2'b0,p00}+{1'b0,p01,1'b0}+{2'b0,p02};
            h1<={2'b0,p10}+{1'b0,p11,1'b0}+{2'b0,p12};
            h2<={2'b0,p20}+{1'b0,p21,1'b0}+{2'b0,p22};
            out_valid<=vd;out_sof<=fd;out_sol<=ld;
            out_data<=(vd && full_d) ? weighted[11:4]:8'd0;
        end
    end
endmodule
