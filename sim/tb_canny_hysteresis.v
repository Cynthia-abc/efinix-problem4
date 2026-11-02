`timescale 1ns/1ps
module tb_canny_hysteresis;
    localparam W=40,H=16,N=W*H*10;
    reg clk=0;always #3.36 clk=~clk;
    reg rst_n=0,v=0,f=0,l=0;reg [9:0] mag=0,high=64,low=24;
    wire ov,of,ol;wire [7:0] value;
    canny_hysteresis #(.IMAGE_WIDTH(W)) dut (
        .clk(clk),.rst_n(rst_n),.pix_valid(v),.pix_sof(f),.pix_sol(l),.pix_mag(mag),
        .vio_th_high(high),.vio_th_low(low),.out_valid(ov),.out_sof(of),.out_sol(ol),.out_data(value));
    reg [9:0] data[0:N-1],highs[0:N-1],lows[0:N-1];
    reg [11:0] expected[0:N-1];
    reg [4:0] pv=0,pf=0,pl=0;
    integer i,seen=0;
    always @(posedge clk) if(rst_n) begin
        pv={pv[3:0],v};pf={pf[3:0],v&&f};pl={pl[3:0],v&&l};
        #1;
        if({ov,of,ol} !== {pv[4],pf[4],pl[4]}) $fatal(1,"Hysteresis control");
        if(ov) begin
            if(value !== {7'b0,expected[seen][0]}) $fatal(1,"Hysteresis directed sample %0d got %0d expected %0d",seen,value,expected[seen]);
            seen=seen+1;
        end
    end
    initial begin
        $readmemh("sim/canny_vectors/hyst_input.hex",data);$readmemh("sim/canny_vectors/hyst_edge.hex",expected);
        $readmemh("sim/canny_vectors/hyst_high.hex",highs);$readmemh("sim/canny_vectors/hyst_low.hex",lows);
        repeat(5) @(negedge clk);rst_n=1;
        for(i=0;i<N;i=i+1) begin
            @(negedge clk);v=1;f=i%(W*H)==0;l=i%W==0;mag=data[i];high=highs[i];low=lows[i];
            if(i%13==8) begin @(negedge clk);v=0;f=0;l=0;end
        end
        @(negedge clk);v=0;f=0;l=0;
        repeat(20) @(negedge clk);
        if(seen!=N) $fatal(1,"Hysteresis lost pixels");
        $display("PASS directed hysteresis: isolated weak suppression, horizontal/vertical/diagonal weak promotion, bounded reverse reach, frame reset, threshold clamping and frame-latched changes");
        $finish;
    end
    initial begin #200000;$fatal(1,"hysteresis timeout");end
endmodule
