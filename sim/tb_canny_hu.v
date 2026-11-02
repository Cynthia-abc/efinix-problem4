`timescale 1ns/1ps
// Real Canny -> UNMODIFIED hu_video_adapter/CCL/Hu -> real overlay.
// Small raster/ROI reduces runtime; clock ratio is still 148.8 MHz / 32 MHz.
module tb_canny_hu;
    localparam W=200,H=160,HT=260,VT=1000,FRAMES=6;
    reg clk=0;always #3.36 clk=~clk;
    reg process_clk=0;always #15.625 process_clk=~process_clk;
    reg rst_n=0,vs=0,hs=0,de=0;reg [7:0] gray=0;
    wire ov,oh,od,ev;wire [7:0] ar,ag,ab,ed;
    canny_video_frontend #(.IMAGE_WIDTH(W),.IMAGE_HEIGHT(H),.H_TOTAL(HT)) frontend (
        .clk(clk),.rst_n(rst_n),.gray_data(gray),.in_r(gray),.in_g(gray),.in_b(gray),
        .in_vsync(vs),.in_hsync(hs),.in_href(de),.vio_th_high(10'd64),.vio_th_low(10'd24),
        .edge_data(ed),.edge_valid(ev),.aligned_r(ar),.aligned_g(ag),.aligned_b(ab),
        .out_vsync(ov),.out_hsync(oh),.out_href(od),.probe_pix_valid(),.probe_pix_sof(),
        .probe_pix_sol(),.probe_gauss_out(),.probe_sobel_mag(),.probe_nms_mag(),
        .probe_edge_out(),.probe_frame_id());
    wire result_event,result_valid,display_valid;
    wire [2:0] shape,display_shape;
    wire [15:0] result_id,display_id;
    wire [31:0] dropped,malformed;
    wire [10:0] x0,x1,y0,y1;
    hu_video_adapter #(.IMAGE_WIDTH(W),.IMAGE_HEIGHT(H),.RECOG_X_MIN(20),.RECOG_Y_MIN(20),
        .RECOG_WIDTH(160),.RECOG_HEIGHT(120),.MIN_AREA(16)) backend (
        .clk(clk),.rst_n(rst_n),.process_clk(process_clk),.process_rst_n(rst_n),
        .in_vsync(ov),.in_href(od),.edge_valid(ev),.edge_data(ed),
        .result_event(result_event),.result_valid(result_valid),.result_shape(shape),
        .result_frame_id(result_id),.input_frame_id(),.dropped_frames(dropped),
        .malformed_frames(malformed),.last_processing_cycles(),.last_hu_det(),.bank_locked(),
        .display_valid(display_valid),.display_shape(display_shape),.display_x_min(x0),
        .display_x_max(x1),.display_y_min(y0),.display_y_max(y1),.display_frame_id(display_id));
    wire [7:0] dr,dg,db;
    color_edge_overlay #(.IMAGE_WIDTH(W),.INPUTS_ALIGNED(1'b1),.SHOW_ROI_GUIDE(1'b0)) overlay (
        .clk(clk),.rst_n(rst_n),.in_vsync(ov),.in_hsync(oh),.in_href(od),
        .in_r(ar),.in_g(ag),.in_b(ab),.in_gray(ag),.edge_data(ed),.edge_valid(ev),
        .target_valid(display_valid),.target_shape(display_shape),.bbox_x_min(x0),.bbox_x_max(x1),
        .bbox_y_min(y0),.bbox_y_max(y1),.out_r(dr),.out_g(dg),.out_b(db),
        .out_vsync(),.out_hsync(),.out_href());
    integer results=0,rectangle_ink=0,circle_ink=0;
    always @(posedge clk) if(rst_n) begin
        #1;
        if(result_event) begin
            results=results+1;
            $display("Canny/Hu result id=%0d valid=%0d shape=%0d",result_id,result_valid,shape);
            $fflush();
            if(result_id!=results) $fatal(1,"Canny/Hu frame ID mismatch");
            if(results<=4) begin
                if(!result_valid || shape!=((results<=2)?2:1)) $fatal(1,"Canny/Hu shape mismatch");
            end else if(result_valid) $fatal(1,"Blank scene must reject");
        end
        if(display_valid && display_shape==2 && {dr,dg,db}==24'h00ffff) rectangle_ink=rectangle_ink+1;
        if(display_valid && display_shape==1 && {dr,dg,db}==24'h00ff00) circle_ink=circle_ink+1;
    end
    integer frame,x,y;
    initial begin
        repeat(10) @(negedge clk);rst_n=1;
        for(frame=0;frame<FRAMES;frame=frame+1) begin
            for(y=0;y<H+12;y=y+1) for(x=0;x<HT;x=x+1) begin
                @(negedge clk);vs=(y<H+8);hs=(x<HT-4);de=(y<H && x<W);
                if(frame<2) gray=(x>=60 && x<140 && y>=52 && y<108) ? 220:20;
                else if(frame<4) gray=((x-100)*(x-100)+(y-80)*(y-80)<=32*32) ? 220:20;
                else gray=20;
            end
            wait(results==frame+1);
            repeat(20) @(negedge clk);
            $display("Canny/Hu source frame %0d complete",frame);
            $fflush();
        end
        @(negedge clk);vs=0;de=0;hs=0;
        repeat(HT*10) @(negedge clk);
        if(results!=FRAMES || dropped!=0 || malformed!=0)
            $fatal(1,"Canny/Hu loss results=%0d dropped=%0d malformed=%0d",results,dropped,malformed);
        if(rectangle_ink==0 || circle_ink==0) $fatal(1,"Canny/Hu labels/bboxes missing");
        if(display_valid) $fatal(1,"Stale target after empty scene");
        $display("PASS Canny -> unchanged CCL/Hu -> overlay: RECT,RECT,CIRCLE,CIRCLE,reject,reject; frame IDs, zero drops/malformed, both label colors, stale clearing");
        $finish;
    end
    initial begin #(6.72*(HT*VT*FRAMES+HT*30));$fatal(1,"Canny/Hu timeout");end
endmodule
