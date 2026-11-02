`timescale 1ns/1ps
module tb_gauss_3x3;
    localparam W=40,H=30,N=W*H*8;
    reg clk=0;always #3.36 clk=~clk;
    reg rst_n=0,v=0,f=0,l=0;reg [7:0] data=0;
    wire ov,of,ol;wire [7:0] value;
    gauss_3x3 #(.IMAGE_WIDTH(W)) dut (
        .clk(clk),.rst_n(rst_n),.pix_valid(v),.pix_sof(f),.pix_sol(l),.pix_gray(data),
        .out_valid(ov),.out_sof(of),.out_sol(ol),.out_data(value));
    reg [11:0] vin[0:N-1],expected[0:N-1];reg [4:0] pv=0,pf=0,pl=0;
    integer i,seen=0;
    always @(posedge clk) if(rst_n) begin
        pv={pv[3:0],v};pf={pf[3:0],v&&f};pl={pl[3:0],v&&l};#1;
        if({ov,of,ol} !== {pv[4],pf[4],pl[4]}) $fatal(1,"Gaussian control");
        if(ov) begin
            if(value !== expected[seen][7:0]) $fatal(1,"Gaussian sample %0d",seen);
            seen=seen+1;
        end
    end
    initial begin
        $readmemh("sim/canny_vectors/input.hex",vin);$readmemh("sim/canny_vectors/gauss.hex",expected);
        repeat(5) @(negedge clk);rst_n=1;
        for(i=0;i<N;i=i+1) begin
            @(negedge clk);v=1;f=i%(W*H)==0;l=i%W==0;data=vin[i][7:0];
            if(i%17==6) begin @(negedge clk);v=0;f=0;l=0;end
        end
        @(negedge clk);v=0;f=0;l=0;repeat(20) @(negedge clk);
        if(seen!=N) $fatal(1,"Gaussian lost pixels");
        $display("PASS standalone Gaussian: %0d independent reference pixels and cycle-aligned controls",N);$finish;
    end
    initial begin #200000;$fatal(1,"Gaussian timeout");end
endmodule
