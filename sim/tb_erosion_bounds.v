`timescale 1ns/1ps
module tb_erosion_bounds;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,gv=0;reg [4:0] weight=0;reg [3:0] gx=0,gy=0;
 wire fv,done,err,busy;wire [1:0] idx,status;
 wire [31:0] edges,steps,cycles;wire [3:0] x0,x1,y0,y1;wire [15:0] aspect;
 erosion_run_analyzer #(.W(16),.H(12),.LB(3),.MIN_EDGES(1),.MAX_WALK(4)) dut(
 .clk(clk),.rst_n(rst_n),.grid_valid(gv),.grid_weight(weight),.grid_x(gx),.grid_y(gy),
 .feature_valid(fv),.feature_index(idx),.feature_edges(edges),
 .feature_x0(x0),.feature_x1(x1),.feature_y0(y0),.feature_y1(y1),
 .feature_aspect(aspect),.feature_steps(steps),.feature_walk_status(status),
 .analysis_done(done),.analysis_error(err),.busy(busy),.processing_cycles(cycles));
 integer x,y,seen=0,stage=0,finishes=0,timeout;
 always @(posedge clk) begin
   if(fv) begin
     seen=seen+1;
     if(stage==0 && (edges!=192 || steps!=4 || status!=2)) $fatal(1,"snapshot changed or missing limit");
     if(stage!=0) $fatal(1,"invalid frame emitted feature");
   end
   if(done) finishes=finishes+1;
 end
 task frame;
   input integer kind;
   begin
     for(y=0;y<12;y=y+1) for(x=0;x<16;x=x+1) begin
       @(negedge clk);gv=1;gx=x;gy=y;
       weight=(kind==1)?1:((kind==2 && x%3==0 && y%3==0)?1:0);
       @(negedge clk);gv=0;repeat(3) @(negedge clk);
     end
   end
 endtask
 task wait_finish;
   input integer expected;
   begin
     timeout=0;
     while(finishes<expected && timeout<50000) begin @(negedge clk);timeout=timeout+1;end
     if(finishes!=expected) $fatal(1,"analysis did not finish");
     repeat(4) @(negedge clk);
   end
 endtask
 initial begin
   repeat(3) @(negedge clk);rst_n=1;
   frame(1);frame(0); // The second full input arrives while the first is analyzed.
   wait_finish(1);
   if(seen!=1 || err) $fatal(1,"busy input corrupted first snapshot");
   stage=1;frame(2);wait_finish(2);
   if(!err) $fatal(1,"label overflow silently accepted");
   stage=2;frame(0);wait_finish(3);
   if(err || seen!=1) $fatal(1,"overflow recovery failed");
   $display("PASS tb_erosion_bounds: busy-frame isolation, walk limit, label overflow and recovery");$finish;
 end
endmodule
