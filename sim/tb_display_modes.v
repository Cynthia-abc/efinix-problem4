`timescale 1ns/1ps
module tb_display_modes;
    localparam W=40,H=30,HT=52,VT=36;
    reg clk=0;always #3.36 clk=~clk;
    reg rst_n=0,vs=0,hs=0,de=0;
    reg [7:0] r=0,g=0,b=0,gray=0,ed=0;
    reg ev=0;
    reg [1:0] mode=0;
    wire [7:0] ro,go,bo;
    wire vo,ho,deo;
    color_edge_overlay #(.IMAGE_WIDTH(W),.SPLIT_WIDTH(W/2),
        .INPUTS_ALIGNED(1),.RUNTIME_MODE(1),.TOP_GUARD_LINES(0),
        .SHOW_ROI_GUIDE(1),.ROI_X_MIN(2),.ROI_X_MAX(37),
        .ROI_Y_MIN(2),.ROI_Y_MAX(27)) dut (
        .clk(clk),.rst_n(rst_n),.in_vsync(vs),.in_hsync(hs),.in_href(de),
        .in_r(r),.in_g(g),.in_b(b),.in_gray(gray),.edge_data(ed),.edge_valid(ev),
        .runtime_mode_i(mode),.target_valid(1'b1),.target_shape(3'd2),
        .bbox_x_min(11'd10),.bbox_x_max(11'd30),.bbox_y_min(11'd10),.bbox_y_max(11'd20),
        .out_r(ro),.out_g(go),.out_b(bo),.out_vsync(vo),.out_hsync(ho),.out_href(deo));
    reg [26:0] expected[0:3];
    reg [23:0] rgb;
    integer sx=0,sy=0,i,checked=0;
    // Independent raster-coordinate reference (no internal DUT signals/forces).
    always @(posedge clk) begin
        if(!rst_n) begin
            for(i=0;i<4;i=i+1) expected[i]=0;
            sx=0;sy=0;checked=0;
        end else begin
            rgb={r,g,b};
            case(mode)
                0: rgb={r,g,b};
                1: rgb=sx<W/2 ? {gray,gray,gray}:((ev && ed==255) ? 24'hffffff:24'd0);
                2,3: rgb=(ev && ed==255) ? 24'hff0000:{r,g,b};
            endcase
            if(mode==3) begin
                // ROI is smaller than its 40-pixel corner segment lengths.
                if(((sy==2 || sy==3 || sy==26 || sy==27) && sx>=2 && sx<=37) ||
                   ((sx==2 || sx==3 || sx==36 || sx==37) && sy>=2 && sy<=27))
                    rgb=24'h0080ff;
                if((((sx==10 || sx==11 || sx==29 || sx==30) && sy>=10 && sy<=20) ||
                    ((sy==10 || sy==11 || sy==19 || sy==20) && sx>=10 && sx<=30)) ||
                   ((sy==15 || sy==16) && sx>=12 && sx<=28) ||
                   ((sx==20 || sx==21) && sy>=7 && sy<=23)) rgb=24'h00ffff;
                // Label R at (32,24), first row has columns 0..3 set,
                // second row has columns 0 and 4; bottom lies beyond this frame.
                if(sx>=32 && sx<40 && sy>=24 && sy<28) rgb=24'h00ffff;
                if(sx>=32 && sx<36 && sy>=28 && sy<30) rgb=24'h00ffff;
            end
            for(i=3;i>0;i=i-1) expected[i]=expected[i-1];
            expected[0]={vs,hs,de,rgb};
            #1;
            if({vo,ho,deo}!==expected[3][26:24]) $fatal(1,"sync mismatch");
            if(expected[3][26] && expected[3][24]) begin
                if({ro,go,bo}!==expected[3][23:0])
                    $fatal(1,"mode %0d pixel mismatch got %h expected %h sample %0d",mode,{ro,go,bo},expected[3][23:0],checked);
                checked=checked+1;
            end else if({ro,go,bo}!==0) $fatal(1,"blank RGB");
            // Source coordinates correspond to the negedge raster generator.
            if(de) sx=sx+1;
            if(sx==W) begin sx=0;sy=sy+1;end
            if(!vs) begin sx=0;sy=0;end
        end
    end
    integer frame,x,y;
    initial begin
        repeat(5) @(negedge clk);rst_n=1;
        for(frame=0;frame<8;frame=frame+1) begin
            @(negedge clk);vs=0;de=0;ev=0;
            mode=frame%4;
            repeat(8) @(negedge clk);
            for(y=0;y<VT;y=y+1) begin
                for(x=0;x<HT;x=x+1) begin
                    @(negedge clk);
                    vs=y<H;hs=x<HT-3;de=(y<H && x<W);ev=de && ((x+y)%5!=0);
                    r=x+17;g=y+41;b=x^y;gray=80+(x+y)%40;
                    ed=(x+y)%3==0 ? 255:0;
                end
            end
        end
        @(negedge clk);vs=0;de=0;ev=0;
        repeat(12) @(negedge clk);
        if(checked!=W*H*8) $fatal(1,"dropped first/last pixels %0d",checked);
        $display("PASS display: 4 modes twice, %0d pixels, RGB/gray/edge/ROI/labels/sync/borders",checked);
        $finish;
    end
    initial begin #3000000;$fatal(1,"watchdog");end
endmodule
