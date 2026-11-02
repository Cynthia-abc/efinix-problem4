 
 
 
 
 
 
 
module canny_top #(parameter integer IMAGE_WIDTH=1924) (
    input clk,input rst_n,input pix_valid,input pix_sof,input pix_sol,
    input [7:0] pix_gray,
    output out_valid,output out_sof,output out_sol,output [7:0] out_data,
    input [9:0] vio_th_high,input [9:0] vio_th_low,
    output probe_pix_valid,output probe_pix_sof,output probe_pix_sol,
    output [7:0] probe_gauss_out,output [9:0] probe_sobel_mag,
    output [9:0] probe_nms_mag,output probe_edge_out
);
    wire gv,gf,gl,sv,sf,sl,nv,nf,nl;
    wire [7:0] gray,unused_sobel_data,unused_nms_data;
    wire [9:0] mag,nms_mag;wire [1:0] dir;
    gauss_3x3 #(.IMAGE_WIDTH(IMAGE_WIDTH)) u_gauss (
        .clk(clk),.rst_n(rst_n),.pix_valid(pix_valid),.pix_sof(pix_sof),
        .pix_sol(pix_sol),.pix_gray(pix_gray),.out_valid(gv),.out_sof(gf),
        .out_sol(gl),.out_data(gray));
    sobel_3x3 #(.IMAGE_WIDTH(IMAGE_WIDTH)) u_sobel (
        .clk(clk),.rst_n(rst_n),.pix_valid(gv),.pix_sof(gf),.pix_sol(gl),
        .pix_gray(gray),.out_valid(sv),.out_sof(sf),.out_sol(sl),
        .out_data(unused_sobel_data),.out_mag(mag),.out_dir(dir));
    canny_nms #(.IMAGE_WIDTH(IMAGE_WIDTH)) u_nms (
        .clk(clk),.rst_n(rst_n),.pix_valid(sv),.pix_sof(sf),.pix_sol(sl),
        .pix_mag(mag),.pix_dir(dir),.out_valid(nv),.out_sof(nf),.out_sol(nl),
        .out_data(unused_nms_data),.out_mag(nms_mag));
    canny_hysteresis #(.IMAGE_WIDTH(IMAGE_WIDTH)) u_hysteresis (
        .clk(clk),.rst_n(rst_n),.pix_valid(nv),.pix_sof(nf),.pix_sol(nl),
        .pix_mag(nms_mag),.vio_th_high(vio_th_high),.vio_th_low(vio_th_low),
        .out_valid(out_valid),.out_sof(out_sof),.out_sol(out_sol),.out_data(out_data));
    assign probe_pix_valid=pix_valid;assign probe_pix_sof=pix_sof;assign probe_pix_sol=pix_sol;
    assign probe_gauss_out=gray;assign probe_sobel_mag=mag;assign probe_nms_mag=nms_mag;
    assign probe_edge_out=out_valid && out_data[0];
endmodule
