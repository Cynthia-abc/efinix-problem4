 
 
 
module shape_simple_overlay #(
 parameter integer ROI_X_MIN=560, parameter integer ROI_X_MAX=1359,
 parameter integer ROI_Y_MIN=240, parameter integer ROI_Y_MAX=839
)(
 input clk,input rst_n,
 input in_vsync,input in_hsync,input in_href,
 input [7:0] in_r,in_g,in_b,
 input [2:0] runtime_mode,
 input result_valid,input [2:0] result_shape,input [7:0] result_confidence,
 input [10:0] result_x_min,result_x_max,result_y_min,result_y_max,
 input [11:0] result_edge_cells,
 output reg [7:0] out_r,out_g,out_b,
 output reg out_vsync,out_hsync,out_href
);
 reg pending,display_valid,display_box;
 reg [2:0] pending_shape,display_shape;
 reg [7:0] pending_confidence,display_confidence;
 reg [10:0] pending_x0,pending_x1,pending_y0,pending_y1;
 reg [11:0] pending_edges;
 reg [10:0] bx0,bx1,by0,by1;reg [11:0] edges;
 reg [10:0] x,y;reg href_d;
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
   pending<=0;display_valid<=0;display_box<=0;pending_shape<=0;display_shape<=0;
   pending_confidence<=0;display_confidence<=0;pending_x0<=0;pending_x1<=0;
   pending_y0<=0;pending_y1<=0;pending_edges<=0;bx0<=0;bx1<=0;by0<=0;by1<=0;edges<=0;
   x<=0;y<=0;href_d<=0;out_r<=0;out_g<=0;out_b<=0;out_vsync<=0;out_hsync<=0;out_href<=0;
  end else begin
   href_d<=in_href;
   if(result_valid) begin
    pending<=1;pending_shape<=result_shape;pending_confidence<=result_confidence;
    pending_x0<=result_x_min;pending_x1<=result_x_max;
    pending_y0<=result_y_min;pending_y1<=result_y_max;pending_edges<=result_edge_cells;
   end
   if(pending && !in_vsync) begin
    pending<=0;display_valid<=1;display_shape<=pending_shape;display_confidence<=pending_confidence;
    bx0<=pending_x0;bx1<=pending_x1;by0<=pending_y0;by1<=pending_y1;edges<=pending_edges;
    display_box<=(pending_edges!=0) && ((pending_x1>pending_x0)||(pending_y1>pending_y0));
   end
   if(!in_vsync) begin x<=0;y<=0;end
   else if(in_href) begin if(x==11'd1919)x<=0;else x<=x+1'b1;end
   else if(href_d) begin x<=0;if(y==11'd1079)y<=0;else y<=y+1'b1;end
   out_vsync<=in_vsync;out_hsync<=in_hsync;out_href<=in_href;
   if(runtime_mode==3'd4 && in_vsync && in_href) begin
    out_r<=draw_r;out_g<=draw_g;out_b<=draw_b;
   end else begin out_r<=in_r;out_g<=in_g;out_b<=in_b;end
  end
 end

 function [34:0] glyph;
  input [7:0] ch;
  begin case(ch)
   "A":glyph=35'b01110_10001_10001_11111_10001_10001_10001;
   "C":glyph=35'b01110_10001_10000_10000_10000_10001_01110;
   "E":glyph=35'b11111_10000_10000_11110_10000_10000_11111;
   "H":glyph=35'b10001_10001_10001_11111_10001_10001_10001;
   "I":glyph=35'b01110_00100_00100_00100_00100_00100_01110;
   "K":glyph=35'b10001_10010_10100_11000_10100_10010_10001;
   "L":glyph=35'b10000_10000_10000_10000_10000_10000_11111;
   "N":glyph=35'b10001_11001_10101_10011_10001_10001_10001;
   "O":glyph=35'b01110_10001_10001_10001_10001_10001_01110;
   "P":glyph=35'b11110_10001_10001_11110_10000_10000_10000;
   "R":glyph=35'b11110_10001_10001_11110_10100_10010_10001;
   "S":glyph=35'b01111_10000_10000_01110_00001_00001_11110;
   "T":glyph=35'b11111_00100_00100_00100_00100_00100_00100;
   "U":glyph=35'b10001_10001_10001_10001_10001_10001_01110;
   "W":glyph=35'b10001_10001_10001_10101_10101_10101_01010;
   "-":glyph=35'b00000_00000_00000_11111_00000_00000_00000;
   ":":glyph=35'b00000_00100_00100_00000_00100_00100_00000;
   default:glyph=0;
  endcase end
 endfunction
 reg [7:0] character;reg [34:0] bits;reg text_pixel;
 reg [7:0] draw_r,draw_g,draw_b;reg [10:0] tx,ty;reg [6:0] col;reg [4:0] row;
 reg box_pixel,guide_pixel,panel;
 always @* begin
  tx=x-11'd16;ty=y-11'd16;col=tx[10:3];row=ty[4:1];character=" ";
  if(col==2)character="S";else if(col==3)character="H";else if(col==4)character="A";
  else if(col==5)character="P";else if(col==6)character="E";else if(col==7)character=":";
  else if(display_shape==1) begin
   case(col)9:character="C";10:character="I";11:character="R";12:character="C";13:character="L";14:character="E";endcase
  end else if(display_shape==2) begin
   case(col)9:character="R";10:character="E";11:character="C";12:character="T";endcase
  end else begin
   case(col)9:character="U";10:character="N";11:character="K";12:character="N";13:character="O";14:character="W";15:character="N";endcase
  end
  bits=glyph(character);text_pixel=(x>=16&&x<560&&y>=16&&y<48&&tx[2:0]<5&&row<7&&bits[34-(row*5+tx[2:0])]);
  box_pixel=display_valid&&display_box&&((x==bx0)||(x==bx1)||(y==by0)||(y==by1))&&x>=bx0&&x<=bx1&&y>=by0&&y<=by1;
   
   
  guide_pixel=(x==ROI_X_MIN || x==ROI_X_MAX || y==ROI_Y_MIN || y==ROI_Y_MAX) &&
              x>=ROI_X_MIN && x<=ROI_X_MAX && y>=ROI_Y_MIN && y<=ROI_Y_MAX;
  panel=(x>=16&&x<560&&y>=16&&y<48);
  draw_r=in_r;draw_g=in_g;draw_b=in_b;
  if(panel)begin draw_r=8'd10;draw_g=8'd10;draw_b=8'd10;end
  if(guide_pixel && runtime_mode==3'd4)begin draw_r=8'd32;draw_g=8'd128;draw_b=8'd255;end
  if(text_pixel||box_pixel)begin
   if(display_shape==1)begin draw_r=0;draw_g=255;draw_b=0;end
   else if(display_shape==2)begin draw_r=0;draw_g=255;draw_b=255;end
   else begin draw_r=255;draw_g=220;draw_b=0;end
  end
 end
endmodule
