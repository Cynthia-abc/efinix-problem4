`timescale 1ns/1ps
module tb_multi_reference;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,gv=0;reg [4:0] weight=0;reg [3:0] gx=0,gy=0;
wire fv,done,err,busy;wire [1:0] idx,status;wire [31:0] edges,steps,cycles;wire [3:0] x0,x1,y0,y1;wire [15:0] aspect;
erosion_run_analyzer #(.W(16),.H(12),.LB(8),.MIN_EDGES(1),.MAX_WALK(1000)) dut(
.clk(clk),.rst_n(rst_n),.grid_valid(gv),.grid_weight(weight),.grid_x(gx),.grid_y(gy),
.feature_valid(fv),.feature_index(idx),.feature_edges(edges),.feature_x0(x0),.feature_x1(x1),.feature_y0(y0),.feature_y1(y1),
.feature_aspect(aspect),.feature_steps(steps),.feature_walk_status(status),.analysis_done(done),.analysis_error(err),.busy(busy),.processing_cycles(cycles));
reg [4:0] samples[0:59*192-1];integer f,x,y,timeout;
always @(posedge clk) if(fv) $display("R %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",f,idx,edges,x0,x1,y0,y1,aspect,steps,status);
initial begin
$readmemh("sim/multi_weights.hex",samples);
repeat(3) @(negedge clk);rst_n=1;
for(f=0;f<59;f=f+1) begin
 for(y=0;y<12;y=y+1) for(x=0;x<16;x=x+1) begin
  @(negedge clk);gv=1;gx=x;gy=y;weight=samples[f*192+y*16+x];
  @(negedge clk);gv=0;repeat(3) @(negedge clk);
 end
 timeout=0;while(!done && timeout<150000) begin @(negedge clk);timeout=timeout+1;end
 if(!done || err) begin $display("FAIL f=%0d state=%0d err=%b",f,dut.state,err);$fatal;end
 $display("DONE %0d %0d",f,cycles);
 repeat(5) @(negedge clk);
end
$display("PASS RTL frames=59");$finish;
end
endmodule
