`timescale 1ns/1ps
module tb_canny_video;
    parameter W=40,H=30,HT=60,VT=44,FRAMES=5;
    parameter H_OFFSET=3,V_OFFSET=2;
    parameter FLAT_ONLY=0;
    localparam D=4*HT+25;
    reg clk=0;always #3.36 clk=~clk;
    reg rst_n=0,vs=0,hs=0,de=0;
    reg [7:0] r=0,g=0,b=0,gray=0;
    wire ov,oh,od,ev;wire [7:0] ar,ag,ab,ed;
    wire display_v,display_h,display_de;wire [7:0] dr,dg,db;
    wire [15:0] fid;
    canny_video_frontend #(.IMAGE_WIDTH(W),.IMAGE_HEIGHT(H),.H_TOTAL(HT)) dut (
        .clk(clk),.rst_n(rst_n),.gray_data(gray),.in_r(r),.in_g(g),.in_b(b),
        .in_vsync(vs),.in_hsync(hs),.in_href(de),.vio_th_high(10'd64),.vio_th_low(10'd24),
        .edge_data(ed),.edge_valid(ev),.aligned_r(ar),.aligned_g(ag),.aligned_b(ab),
        .out_vsync(ov),.out_hsync(oh),.out_href(od),
        .probe_pix_valid(),.probe_pix_sof(),.probe_pix_sol(),.probe_gauss_out(),
        .probe_sobel_mag(),.probe_nms_mag(),.probe_edge_out(),.probe_frame_id(fid));
    color_edge_overlay #(.IMAGE_WIDTH(W),.INPUTS_ALIGNED(1'b1),
        .SHOW_ROI_GUIDE(1'b0),.TOP_GUARD_LINES(0)) overlay (
        .clk(clk),.rst_n(rst_n),.in_vsync(ov),.in_hsync(oh),.in_href(od),
        .in_r(ar),.in_g(ag),.in_b(ab),.in_gray(ag),.edge_data(ed),.edge_valid(ev),
        .target_valid(1'b0),.target_shape(3'd0),.bbox_x_min(11'd0),.bbox_x_max(11'd0),
        .bbox_y_min(11'd0),.bbox_y_max(11'd0),.out_r(dr),.out_g(dg),.out_b(db),
        .out_vsync(display_v),.out_hsync(display_h),.out_href(display_de));
    reg [26:0] overlay_history[0:3];
    integer j;
    always @(posedge clk) begin
        if(!rst_n) begin for(j=0;j<4;j=j+1) overlay_history[j]=0;end
        else begin
            for(j=3;j>0;j=j-1) overlay_history[j]=overlay_history[j-1];
            overlay_history[0]={ov,oh,od,(ev && ed==8'hff) ? 24'hff0000:{ar,ag,ab}};
            #1;
            if({display_v,display_h,display_de} !== overlay_history[3][26:24])
                $fatal(1,"Overlay sync alignment");
            if(overlay_history[3][26] && overlay_history[3][24]) begin
                if({dr,dg,db} !== overlay_history[3][23:0])
                    $fatal(1,"Overlay RGB/edge alignment got %h expected %h",{dr,dg,db},overlay_history[3][23:0]);
            end else if({dr,dg,db} !== 24'd0) $fatal(1,"Overlay blanking");
        end
    end
    reg [26:0] history[0:D];
    reg [26:0] expected;
    reg [11:0] reference_edge[0:W*H-1];
    integer pos=0,ticks=0,pixels=0,edges=0;
    always @(posedge clk) begin
        if(!rst_n) begin pos=0;ticks=0;pixels=0;edges=0;end
        else begin
            history[pos]={vs,hs,de,r,g,b};
            if(pos==D) pos=0;else pos=pos+1;
            expected=(ticks>=D) ? history[pos]:27'd0;
            ticks=ticks+1;
            #1;
            if({ov,oh,od} !== expected[26:24])
                $fatal(1,"Video sync mismatch tick %0d got %b expected %b",ticks,{ov,oh,od},expected[26:24]);
            if(ev !== (expected[26] && expected[24]))
                $fatal(1,"Video crop/valid mismatch tick %0d got %b expected %b phase=%0d row=%0d cx=%0d cy=%0d",ticks,ev,expected[26]&&expected[24],dut.phase,dut.row,dut.cx,dut.cy);
            if(ev) begin
                if({ar,ag,ab} !== expected[23:0])
                    $fatal(1,"RGB/frame mismatch pixel %0d got %h expected %h",pixels,{ar,ag,ab},expected[23:0]);
                if(ed!==8'h00 && ed!==8'hff) $fatal(1,"Legacy edge encoding");
                if(W==40 && H==30 && !FLAT_ONLY && pixels/(W*H)!=4 &&
                   ed !== (reference_edge[pixels%(W*H)][0] ? 8'hff:8'h00))
                    $fatal(1,"Video edge/RGB spatial reference mismatch at pixel %0d",pixels);
                if((FLAT_ONLY || pixels/(W*H)==4) && ed!==0) $fatal(1,"Flat white scene produced edges");
                pixels=pixels+1;if(ed==8'hff) edges=edges+1;
            end else if({ar,ag,ab} !== 24'd0) $fatal(1,"Nonzero RGB outside valid");
        end
    end
    integer frame,x,y,source_tag;
    initial begin
        if(W==40 && H==30) $readmemh("sim/canny_vectors/video_edge.hex",reference_edge);
        repeat(6) @(negedge clk);rst_n=1;
        repeat(20) @(negedge clk);
        for(frame=0;frame<FRAMES;frame=frame+1) begin
            for(y=0;y<VT;y=y+1) begin
                for(x=0;x<HT;x=x+1) begin
                    @(negedge clk);
                    source_tag=(frame==2) ? 1:(frame==3 ? 0:frame);
                    vs=(y<VT-3);hs=(x<HT-4);
                    de=(x>=H_OFFSET && x<H_OFFSET+W && y>=V_OFFSET && y<V_OFFSET+H);
                    r=(x-H_OFFSET+17*source_tag)%256;g=(3*(y-V_OFFSET)+source_tag)%256;
                    b=((x-H_OFFSET)^(y-V_OFFSET)^source_tag)%256;
                    gray=(x-H_OFFSET>W/4 && x-H_OFFSET<3*W/4 &&
                          y-V_OFFSET>H/4 && y-V_OFFSET<3*H/4) ? 8'd220:8'd20;
                    if(FLAT_ONLY || frame==4) gray=255;
                    if(FLAT_ONLY) begin r=255;g=255;b=255;end
                end
            end
            $display("video source frame %0d complete",frame);
            $fflush();
        end
        @(negedge clk);vs=0;hs=0;de=0;r=0;g=0;b=0;gray=0;
        repeat(D+50) @(negedge clk);
        if(pixels!=W*H*FRAMES || fid!=FRAMES) $fatal(1,"Frame/pixel loss %0d frame %0d",pixels,fid);
        if(edges==0 && !FLAT_ONLY) $fatal(1,"No edges from rectangle");
        $display("PASS video: %0dx%0d, %0d frames, %0d RGB pixels, %0d edges; exact fixed %0d clock delay, full borders",W,H,FRAMES,pixels,edges,D);
        $finish;
    end
    initial begin #(6.72*(HT*VT*FRAMES+D+2000));$fatal(1,"video timeout");end
endmodule
