`timescale 1ns/1ps
module tb_canny_core;
    localparam W=40,H=30,N=W*H*8;
    localparam TOTAL=N+93+2*W*H;
    reg clk=0;always #3.36 clk=~clk;
    reg rst_n=0,v=0,f=0,l=0;reg [7:0] data=0;
    wire ov,of,ol;wire [7:0] edge_value;
    wire [7:0] gauss;wire [9:0] mag,nms;
    canny_top #(.IMAGE_WIDTH(W)) dut (
        .clk(clk),.rst_n(rst_n),.pix_valid(v),.pix_sof(f),.pix_sol(l),.pix_gray(data),
        .out_valid(ov),.out_sof(of),.out_sol(ol),.out_data(edge_value),
        .vio_th_high(10'd64),.vio_th_low(10'd24),
        .probe_pix_valid(),.probe_pix_sof(),.probe_pix_sol(),.probe_gauss_out(gauss),
        .probe_sobel_mag(mag),.probe_nms_mag(nms),.probe_edge_out());
    reg [11:0] vin[0:N-1],vg[0:N-1],vm[0:N-1],vd[0:N-1],vn[0:N-1],ve[0:N-1];
    integer source_index[0:TOTAL-1];
    reg [20:0] pv=0,pf=0,pl=0;
    reg checking=1;
    integer gi=0,mi=0,ni=0,ei=0,i,cycles=0;
    always @(posedge clk) begin
        if(!rst_n) begin pv=0;pf=0;pl=0;gi=0;mi=0;ni=0;ei=0;end
        else begin
            pv={pv[19:0],v};pf={pf[19:0],v && f};pl={pl[19:0],v && l};
            #1;
            if({dut.gv,dut.gf,dut.gl} !== {pv[4],pf[4],pl[4]}) $fatal(1,"Gaussian control latency");
            if({dut.sv,dut.sf,dut.sl} !== {pv[11],pf[11],pl[11]}) $fatal(1,"Sobel control latency");
            if({dut.nv,dut.nf,dut.nl} !== {pv[15],pf[15],pl[15]}) $fatal(1,"NMS control latency");
            if({ov,of,ol} !== {pv[20],pf[20],pl[20]}) $fatal(1,"Hysteresis control latency");
            if(dut.gv && checking) begin
                if(gauss !== vg[source_index[gi]][7:0]) $fatal(1,"Gaussian pixel %0d got %0d expected %0d",gi,gauss,vg[source_index[gi]]);
                gi=gi+1;
            end
            if(dut.sv && checking) begin
                if(mag !== vm[source_index[mi]][9:0]) $fatal(1,"Sobel pixel %0d got %0d expected %0d",mi,mag,vm[source_index[mi]]);
                // Direction is don't-care when the causal window is incomplete.
                if(source_index[mi]%W>=2 && (source_index[mi]/W)%H>=2 && dut.dir !== vd[source_index[mi]][1:0]) $fatal(1,"Direction pixel %0d",mi);
                mi=mi+1;
            end
            if(dut.nv && checking) begin
                if(nms !== vn[source_index[ni]][9:0]) $fatal(1,"NMS pixel %0d got %0d expected %0d",ni,nms,vn[source_index[ni]]);
                ni=ni+1;
            end
            if(ov && checking) begin
                if(edge_value !== {7'd0,ve[source_index[ei]][0]}) $fatal(1,"Hysteresis pixel %0d got %0d expected %0d",ei,edge_value,ve[source_index[ei]]);
                ei=ei+1;
            end
        end
    end
    initial begin
        $readmemh("sim/canny_vectors/input.hex",vin);$readmemh("sim/canny_vectors/gauss.hex",vg);
        $readmemh("sim/canny_vectors/mag.hex",vm);$readmemh("sim/canny_vectors/dir.hex",vd);
        $readmemh("sim/canny_vectors/nms.hex",vn);$readmemh("sim/canny_vectors/edge.hex",ve);
        for(i=0;i<TOTAL;i=i+1) begin
            if(i<N) source_index[i]=i;
            else if(i<N+93) source_index[i]=W*H+i-N;
            else if(i<N+93+W*H) source_index[i]=i-N-93;
            else source_index[i]=2*W*H+i-N-93-W*H;
        end
        repeat(5) @(negedge clk);rst_n=1;
        for(i=0;i<TOTAL;i=i+1) begin
            @(negedge clk);v=1;f=(source_index[i]%(W*H)==0);l=(source_index[i]%W==0);data=vin[source_index[i]][7:0];
            // Different bubbles, including within a row and across SOL/SOF.
            if(i%17==6 || i%113==12) begin
                @(negedge clk);v=0;f=0;l=0;
                if(i%113==12) repeat(3) @(negedge clk);
            end
        end
        @(negedge clk);v=0;f=0;l=0;
        repeat(40) @(negedge clk);
        if(gi!=TOTAL || mi!=TOTAL || ni!=TOTAL || ei!=TOTAL) $fatal(1,"Pixel loss");
        $display("PASS core: %0d samples/stage, reference pixels + direction + cycle flags, valid gaps, contiguous frames, truncated-frame SOF/SOL recovery",TOTAL);
        // Reset while noisy pixels occupy every pipeline stage. Follow with a
        // clean black frame; stale strong/weak/RGB history must not reappear.
        checking=0;
        for(i=0;i<180;i=i+1) begin
            @(negedge clk);v=1;f=i==0;l=i%W==0;data=vin[5*W*H+i][7:0];
        end
        @(negedge clk);rst_n=0;v=0;f=0;l=0;
        repeat(5) @(negedge clk);
        if({ov,of,ol,edge_value}!==11'd0) $fatal(1,"Reset did not clear outputs");
        rst_n=1;checking=1;
        for(i=0;i<W*H;i=i+1) begin
            @(negedge clk);v=1;f=i==0;l=i%W==0;data=0;
        end
        @(negedge clk);v=0;f=0;l=0;repeat(40) @(negedge clk);
        if(gi!=W*H || mi!=W*H || ni!=W*H || ei!=W*H) $fatal(1,"Reset recovery pixel loss");
        $display("PASS core reset while busy: 1200 clean recovery pixels/stage, no stale edges or control flags");
        $finish;
    end
    initial begin #1000000;$fatal(1,"core timeout");end
endmodule
