 
 
 
module canny_nms #(parameter integer IMAGE_WIDTH=1924) (
    input clk,input rst_n,input pix_valid,input pix_sof,input pix_sol,
    input [9:0] pix_mag,input [1:0] pix_dir,
    output reg out_valid,output reg out_sof,output reg out_sol,
    output [7:0] out_data,output reg [9:0] out_mag
);
    wire v,f,l,full;
    wire [11:0] p00,p01,p02,p10,p11,p12,p20,p21,p22;
    reg [9:0] neighbor0,neighbor1;
    canny_window_3x3 #(.WIDTH(12),.IMAGE_WIDTH(IMAGE_WIDTH)) u_window (
        .clk(clk),.rst_n(rst_n),.pix_valid(pix_valid),.pix_sof(pix_sof),
        .pix_sol(pix_sol),.pix_data({pix_dir,pix_mag}),
        .out_valid(v),.out_sof(f),.out_sol(l),.window_full(full),
        .p00(p00),.p01(p01),.p02(p02),.p10(p10),.p11(p11),
        .p12(p12),.p20(p20),.p21(p21),.p22(p22));
    always @* begin
        case(p11[11:10])
            0:begin neighbor0=p10[9:0];neighbor1=p12[9:0];end
            1:begin neighbor0=p00[9:0];neighbor1=p22[9:0];end
            2:begin neighbor0=p01[9:0];neighbor1=p21[9:0];end
            default:begin neighbor0=p02[9:0];neighbor1=p20[9:0];end
        endcase
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin out_valid<=0;out_sof<=0;out_sol<=0;out_mag<=0;end
        else begin
            out_valid<=v;out_sof<=f;out_sol<=l;
            out_mag<=(v && full && p11[9:0]>=neighbor0 && p11[9:0]>=neighbor1)
                     ? p11[9:0]:10'd0;
        end
    end
    assign out_data=out_mag[9:2];
endmodule
