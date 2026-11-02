`timescale 1ns/1ps
module tb_shape_simple_recognizer;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,vs=0,href=0,ev=0;reg [7:0] ed=0;
 wire rv,done,busy;wire [2:0] shape;wire [7:0] conf;wire [10:0] x0,x1,y0,y1;wire [11:0] ec;
 shape_simple_recognizer #(.IMAGE_WIDTH(64),.IMAGE_HEIGHT(64),.BLOCK(4)) dut(
  .clk(clk),.rst_n(rst_n),.in_vsync(vs),.in_href(href),.edge_valid(ev),.edge_data(ed),
  .result_valid(rv),.result_shape(shape),.result_confidence(conf),
  .result_x_min(x0),.result_x_max(x1),.result_y_min(y0),.result_y_max(y1),
  .result_edge_cells(ec),.analysis_done(done),.busy(busy));
 integer x,y,kind,finishes;
 function edge_for;
  input integer bx,by;begin
   if(kind==1) edge_for=((bx>=4&&bx<=11&&(by==4||by==11))||(by>=4&&by<=11&&(bx==4||bx==11)));
   // A closed circular ring. The previous fixture was an open asymmetric
   // arch and did not exercise actual circle geometry.
   else if(kind==2) edge_for=(((2*bx-15)*(2*bx-15)+(2*by-15)*(2*by-15)>=100) &&
                            ((2*bx-15)*(2*bx-15)+(2*by-15)*(2*by-15)<=136));
   else edge_for=0;
  end endfunction
 always @(posedge clk) begin
  if(rv) begin
   $display("kind=%0d shape=%0d bbox=%0d,%0d..%0d,%0d cells=%0d conf=%0d",kind,shape,x0,y0,x1,y1,ec,conf);
   $display("  internals boundary=%0d corners=%0d",dut.boundary_hits,dut.corner_hits);
   if(kind==1 && shape!=2) $fatal(1,"rectangle was not classified");
   if(kind==2 && shape!=1) $fatal(1,"circle was not classified");
  end
  if(done) finishes=finishes+1;
 end
 task frame;
  input integer k;begin
   kind=k; @(negedge clk);vs=1;href=0;repeat(2) @(negedge clk);
   for(y=0;y<64;y=y+1) begin
    href=1;
    for(x=0;x<64;x=x+1) begin
     ev=edge_for(x/4,y/4);ed=ev?8'hff:0;@(negedge clk);
    end
    href=0;ev=0;ed=0;@(negedge clk);
   end
   vs=0;href=0;repeat(10) @(negedge clk);
   repeat(10000) @(negedge clk);
  end
 endtask
 initial begin
  finishes=0;repeat(3) @(negedge clk);rst_n=1;
  frame(1);frame(2);
  repeat(3000) @(negedge clk);
  $display("PASS tb_shape_simple_recognizer");$finish;
 end
endmodule
