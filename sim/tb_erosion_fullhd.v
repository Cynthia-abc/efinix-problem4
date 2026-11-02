`timescale 1ns/1ps
// Full-size raster input; tests the actual 1920x1080 / 480x270 parameters.
module tb_erosion_fullhd;
 reg clk=0; always #5 clk=~clk;
 reg rst_n=0,vs=0,href=0,ev=0; reg [7:0] data=0;
 wire fv,done,err,busy; wire [1:0] idx,status;
 wire [31:0] edges,ratio,steps,cycles;
 wire [10:0] x0,x1,y0,y1;
 shape_erosion_multi_candidate_top dut(
 .clk(clk),.rst_n(rst_n),.in_vsync(vs),.in_href(href),.edge_valid(ev),.edge_data(data),
 .feature_valid(fv),.feature_last(),.feature_index(idx),.feature_edge_count(edges),
 .feature_x_min(x0),.feature_x_max(x1),.feature_y_min(y0),.feature_y_max(y1),
 .feature_aspect_ratio_x1000(ratio),.feature_contour_steps_grid(steps),
 .feature_contour_valid(),.feature_walk_status(status),.analysis_done(done),
 .analysis_overrun(err),.analysis_busy(busy),.processing_cycles(cycles));
 integer x,y,gx,gy,stage=0,seen=0,finished=0,timeout;
 reg edge_on;
 always @(posedge clk) begin
   if(fv) begin
     if(status!=0 || idx!=seen) $fatal(1,"walk status or ranking invalid");
     case(stage)
       0: case(seen)
         0: if(edges!=2176 || x0!=1800 || x1!=1919 || y0!=920 || y1!=1079 || ratio!=1333 || steps!=136)
              $fatal(1,"bottom/right border target mismatch");
         1: if(edges!=1536 || x0!=0 || x1!=119 || y0!=0 || y1!=79 || ratio!=1500 || steps!=96)
              $fatal(1,"top/left border target mismatch");
         2: if(edges!=1536 || x0!=800 || x1!=959 || y0!=400 || y1!=439 || ratio!=4000 || steps!=96)
              $fatal(1,"interior target mismatch");
         default: $fatal(1,"too many targets");
       endcase
       1: $fatal(1,"empty frame emitted stale target");
       2: if(seen!=0 || edges!=2073600 || x0!=0 || x1!=1919 || y0!=0 || y1!=1079 || ratio!=1777 || steps!=1496)
            $fatal(1,"full white frame count/size/walk mismatch");
     endcase
     $display("FEATURE stage=%0d idx=%0d E=%0d bbox=%0d,%0d..%0d,%0d R=%0d S=%0d",stage,idx,edges,x0,y0,x1,y1,ratio,steps);
     seen=seen+1;
   end
   if(done) begin
     if(err) $fatal(1,"unexpected analysis error");
     $display("DONE stage=%0d analysis_cycles_excluding_capture=%0d",stage,cycles);
     finished=finished+1;
   end
 end
 task frame;
   input integer kind;
   begin
     @(negedge clk);vs=1;
     for(y=0;y<1080;y=y+1) begin
       href=1;
       for(x=0;x<1920;x=x+1) begin
         gx=x/4;gy=y/4;
         edge_on=(kind==2) || (kind==0 && (
           (gx<=29 && gy<=19 && (gx==0 || gx==29 || gy==0 || gy==19)) ||
           (gx>=450 && gy>=230 && (gx==450 || gx==479 || gy==230 || gy==269)) ||
           (gx>=200 && gx<=239 && gy>=100 && gy<=109 && (gx==200 || gx==239 || gy==100 || gy==109)) ||
           (gy==180 && gx>=100 && gx<=102)));
         ev=1;data=edge_on?8'hff:0;
         @(negedge clk);
       end
       href=0;ev=0;data=0;repeat(280) @(negedge clk);
     end
     vs=0;repeat(100) @(negedge clk);
   end
 endtask
 task wait_finish;
   input integer n;
   begin
     timeout=0;
     while(finished<n && timeout<15000000) begin @(negedge clk);timeout=timeout+1;end
     if(finished!=n) $fatal(1,"full-resolution timeout or unexpected extra capture");
     repeat(5) @(negedge clk);
   end
 endtask
 initial begin
   repeat(4) @(negedge clk);rst_n=1;
   frame(0);frame(1); // The entire second frame must be skipped while busy.
   wait_finish(1);if(seen!=3) $fatal(1,"missing top-three target");
   stage=1;seen=0;frame(1);wait_finish(2);
   if(seen!=0) $fatal(1,"empty frame retained targets");
   stage=2;seen=0;frame(2);wait_finish(3);
   if(seen!=1) $fatal(1,"full frame must be one component");
   $display("PASS tb_erosion_fullhd: weighted pooling, borders, top3, busy skip, empty clear, 2073600 count");
   $finish;
 end
endmodule
