`timescale 1ns/1ps
// Pixel-level fixtures: unlike the old test these do not fill entire blocks.
module tb_shape_simple_thin;
 parameter W=192, H=128, B=4;
 parameter RX0=0, RX1=W-1, RY0=0, RY1=H-1;
 reg clk=0; always #5 clk=~clk;
 reg rst_n=0,vs=0,href=0,ev=0; reg [7:0] ed=0;
 wire rv,done,busy; wire [2:0] shape; wire [7:0] conf;
 wire [10:0] x0,x1,y0,y1; wire [11:0] cells;
 shape_simple_recognizer #(.IMAGE_WIDTH(W),.IMAGE_HEIGHT(H),.BLOCK(B),
  .ROI_X_MIN(RX0),.ROI_X_MAX(RX1),.ROI_Y_MIN(RY0),.ROI_Y_MAX(RY1)) dut(
  .clk(clk),.rst_n(rst_n),.in_vsync(vs),.in_href(href),.edge_valid(ev),.edge_data(ed),
  .result_valid(rv),.result_shape(shape),.result_confidence(conf),
  .result_x_min(x0),.result_x_max(x1),.result_y_min(y0),.result_y_max(y1),
  .result_edge_cells(cells),.analysis_done(done),.busy(busy));
 reg pixels[0:W*H-1];
 reg [1023:0] fixture; integer expected,x,y,seen=0;
 always @(posedge clk) if(rv) begin
  seen=seen+1;
  $display("shape=%0d expected=%0d box=%0d,%0d..%0d,%0d cells=%0d sides=%0d/%0d/%0d/%0d corners=%0d",shape,expected,x0,y0,x1,y1,cells,dut.top_hits,dut.bottom_hits,dut.left_hits,dut.right_hits,dut.corner_hits);
  if(shape!==expected) $fatal(1,"shape mismatch");
 end
 initial begin
  if(!$value$plusargs("fixture=%s",fixture)) $fatal(1,"missing fixture");
  if(!$value$plusargs("expected=%d",expected)) $fatal(1,"missing expected");
  $readmemb(fixture,pixels);
  repeat(3) @(negedge clk); rst_n=1;
  repeat(2) @(negedge clk); vs=1;
  repeat(2) @(negedge clk);
  for(y=0;y<H;y=y+1) begin
   href=1;
   for(x=0;x<W;x=x+1) begin
    ev=1; ed=pixels[y*W+x]?255:0; @(negedge clk);
   end
   href=0;ev=0;ed=0;repeat(4) @(negedge clk);
  end
  vs=0;href=0;
  repeat(((W+B-1)/B)*((H+B-1)/B)*6+2000) @(negedge clk);
  if(seen!=1) $fatal(1,"expected exactly one result");
  $display("PASS thin-pixel fixture"); $finish;
 end
endmodule
