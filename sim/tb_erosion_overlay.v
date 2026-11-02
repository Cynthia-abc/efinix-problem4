`timescale 1ns/1ps
module tb_erosion_overlay;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,vs=0,hs=0,de=0;
 reg [7:0] r=12,g=34,b=56;
 reg [1:0] mode=3,idx=0,status=0;
 reg [1:0] display_slots=3;
 reg fv=0,done=0,err=0;
 reg [31:0] edges=0,steps=0;
 reg [10:0] x0=0,x1=0,y0=0,y1=0;
 reg [15:0] aspect=0;
 wire [7:0] ro,go,bo;wire vo,ho,deo;
 erosion_analysis_overlay #(.IMAGE_WIDTH(1920)) dut(
  .clk(clk),.rst_n(rst_n),.in_vsync(vs),.in_hsync(hs),.in_href(de),
  .in_r(r),.in_g(g),.in_b(b),.runtime_mode(mode),.display_slots(display_slots),
  .feature_valid(fv),.feature_index(idx),.feature_edges(edges),.feature_steps(steps),
  .feature_x0(x0),.feature_x1(x1),.feature_y0(y0),.feature_y1(y1),
  .feature_aspect(aspect),.feature_status(status),.analysis_done(done),.analysis_error(err),
  .out_r(ro),.out_g(go),.out_b(bo),.out_vsync(vo),.out_hsync(ho),.out_href(deo));
 task record;
  input [1:0] slot;
  begin
   @(negedge clk);fv=1;idx=slot;
   edges=1234567+slot;steps=65536-slot;aspect=3125+slot;
   x0=100+slot*100;x1=x0+124;y0=200;y1=239;status=slot;
   @(negedge clk);fv=0;
  end
 endtask
 task finish_batch;
  begin @(negedge clk);done=1;@(negedge clk);done=0;end
 endtask
 integer i;
 initial begin
  repeat(3) @(negedge clk);rst_n=1;vs=1;
  record(0);record(1);record(2);finish_batch;
  repeat(550) @(negedge clk);
  if(dut.display_valid!==0) $fatal(1,"published in active frame");
  vs=0;repeat(3) @(negedge clk);
  if(dut.display_valid!==7) $fatal(1,"missing three records");
  if(dut.de[0]!==28'h1234567 || dut.dw[0]!==16'h0125 || dut.dh[0]!==16'h0040 ||
     dut.da[0]!==20'h03125 || dut.ds[0]!==24'h065536) $fatal(1,"bad decimal conversion");
  // A changed candidate set is held for one batch; repeating it commits the
  // new stable result and clears old slots atomically.
  vs=1;record(0);finish_batch;repeat(550) @(negedge clk);
  vs=1;record(0);finish_batch;repeat(550) @(negedge clk);
  if(dut.display_valid!==7) $fatal(1,"result changed midframe");
  vs=0;repeat(3) @(negedge clk);
  if(dut.display_valid!==1) $fatal(1,"stale target 2 or 3");
  // Two repeated empty batches clear the final old target.
  finish_batch;repeat(550) @(negedge clk);
  finish_batch;repeat(550) @(negedge clk);
  if(dut.display_valid!==0 || dut.display_error) $fatal(1,"empty frame did not clear");
  err=1;finish_batch;repeat(550) @(negedge clk);
  if(dut.display_valid!==0 || !dut.display_error) $fatal(1,"error not shown");
  // Video timing and RGB pass through exactly one register in modes 0..2.
  for(i=0;i<200;i=i+1) begin
   @(negedge clk);mode=i%3;vs=i%2;hs=(i%3==0);de=(i%4!=0);
   r=i;g=i+17;b=i+31;
   @(posedge clk);#1;
   if({ro,go,bo,vo,ho,deo}!=={r,g,b,vs,hs,de}) $fatal(1,"mode bypass or control latency");
  end
  $display("PASS tb_erosion_overlay: decimal, atomic commit, empty/error clear, modes 0/1/2");$finish;
 end
endmodule
