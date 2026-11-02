 
 
 
 
module sobel_3x3 #(parameter integer IMAGE_WIDTH=1924) (
    input clk,input rst_n,input pix_valid,input pix_sof,input pix_sol,
    input [7:0] pix_gray,
    output reg out_valid,output reg out_sof,output reg out_sol,
    output [7:0] out_data,output reg [9:0] out_mag,output reg [1:0] out_dir
);
    wire v,f,l,full;
    wire [7:0] p00,p01,p02,p10,p11,p12,p20,p21,p22;
    canny_window_3x3 #(.WIDTH(8),.IMAGE_WIDTH(IMAGE_WIDTH)) u_window (
        .clk(clk),.rst_n(rst_n),.pix_valid(pix_valid),.pix_sof(pix_sof),
        .pix_sol(pix_sol),.pix_data(pix_gray),.out_valid(v),.out_sof(f),.out_sol(l),
        .window_full(full),.p00(p00),.p01(p01),.p02(p02),.p10(p10),.p11(p11),
        .p12(p12),.p20(p20),.p21(p21),.p22(p22));
    reg [9:0] xp,xn,yp,yn;
    reg signed [10:0] gx,gy;
    reg [9:0] ax,ay;
    reg equal_sign;
    reg [2:0] vp,fp,lp,mp;
    wire [10:0] absx=gx[10] ? -gx:gx;
    wire [10:0] absy=gy[10] ? -gy:gy;
    wire [10:0] magnitude={1'b0,ax}+{1'b0,ay};
     
    wire [17:0] ax106=({8'b0,ax}<<6)+({8'b0,ax}<<5)+
                       ({8'b0,ax}<<3)+({8'b0,ax}<<1);
    wire [17:0] ay106=({8'b0,ay}<<6)+({8'b0,ay}<<5)+
                       ({8'b0,ay}<<3)+({8'b0,ay}<<1);
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            xp<=0;xn<=0;yp<=0;yn<=0;gx<=0;gy<=0;ax<=0;ay<=0;equal_sign<=0;
            vp<=0;fp<=0;lp<=0;mp<=0;
            out_valid<=0;out_sof<=0;out_sol<=0;out_mag<=0;out_dir<=0;
        end else begin
            vp<={vp[1:0],v};fp<={fp[1:0],f};lp<={lp[1:0],l};mp<={mp[1:0],full};
            xp<={2'b0,p02}+{1'b0,p12,1'b0}+{2'b0,p22};
            xn<={2'b0,p00}+{1'b0,p10,1'b0}+{2'b0,p20};
            yp<={2'b0,p20}+{1'b0,p21,1'b0}+{2'b0,p22};
            yn<={2'b0,p00}+{1'b0,p01,1'b0}+{2'b0,p02};
            gx<=$signed({1'b0,xp})-$signed({1'b0,xn});
            gy<=$signed({1'b0,yp})-$signed({1'b0,yn});
            ax<=absx[9:0];ay<=absy[9:0];equal_sign<=(gx[10]==gy[10]);
            out_valid<=vp[2];out_sof<=fp[2];out_sol<=lp[2];
            out_mag<=(vp[2] && mp[2]) ? magnitude[10:1]:10'd0;
            if({ay,8'b0}<=ax106) out_dir<=0;
            else if({ax,8'b0}<=ay106) out_dir<=2;
            else out_dir<=equal_sign ? 2'd1:2'd3;
        end
    end
    assign out_data=out_mag[9:2];
endmodule
