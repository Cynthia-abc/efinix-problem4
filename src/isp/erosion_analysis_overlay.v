 
 
module erosion_analysis_overlay #(
 parameter IMAGE_WIDTH=1920,
  
  
  
 parameter integer STABILITY_TOL=16
)(
 input clk,rst_n,in_vsync,in_hsync,in_href,
 input [7:0] in_r,in_g,in_b,
 input [2:0] runtime_mode,
 input [1:0] display_slots,
 input feature_valid,input [1:0] feature_index,
 input [31:0] feature_edges,feature_steps,
 input [10:0] feature_x0,feature_x1,feature_y0,feature_y1,
 input [15:0] feature_aspect,input [1:0] feature_status,
 input analysis_done,analysis_error,
 output reg [7:0] out_r,out_g,out_b,
 output reg out_vsync,out_hsync,out_href
);
 reg [2:0] raw_valid,cv_valid,display_valid,full_display_valid;
 reg [10:0] rx0[0:2],rx1[0:2],ry0[0:2],ry1[0:2];
 reg [31:0] re[0:2],rs[0:2];reg [15:0] ra[0:2];reg [1:0] rst[0:2];
 reg [10:0] cx0[0:2],cx1[0:2],cy0[0:2],cy1[0:2];
 reg [31:0] ce[0:2],cs[0:2];reg [15:0] ca[0:2];reg [1:0] cst[0:2];
 reg [10:0] bx0[0:2],bx1[0:2],by0[0:2],by1[0:2];
 reg [1:0] bst[0:2];
 reg [27:0] de[0:2],pe[0:2];reg [23:0] ds[0:2],ps[0:2];
 reg [15:0] dw[0:2],dh[0:2],pw[0:2],ph[0:2];
 reg [19:0] da[0:2],pa[0:2];
 reg [2:0] stable_last_valid;
 reg [10:0] stable_x0[0:2],stable_x1[0:2],stable_y0[0:2],stable_y1[0:2];
 reg stable_have_display;
 reg [1:0] stable_count;
 reg pending,converting,load_value;
 reg [1:0] target;reg [2:0] field;
 reg [31:0] bin;reg [39:0] bcd,adjusted;
 reg [5:0] remaining;
 integer j,k;
 wire [2:0] slot_mask=(display_slots==2'd1)?3'b001:
                      (display_slots==2'd2)?3'b011:3'b111;
 reg stable_batch;
 integer sd;
 always @* begin
   stable_batch=(cv_valid==stable_last_valid);
   for(sd=0;sd<3;sd=sd+1) begin
     if(cv_valid[sd]) begin
       if((cv_valid[sd] != stable_last_valid[sd]) ||
          ((cv_valid[sd] && ((cx0[sd]>stable_x0[sd] ? cx0[sd]-stable_x0[sd] : stable_x0[sd]-cx0[sd])>STABILITY_TOL ||
                             (cx1[sd]>stable_x1[sd] ? cx1[sd]-stable_x1[sd] : stable_x1[sd]-cx1[sd])>STABILITY_TOL ||
                             (cy0[sd]>stable_y0[sd] ? cy0[sd]-stable_y0[sd] : stable_y0[sd]-cy0[sd])>STABILITY_TOL ||
                             (cy1[sd]>stable_y1[sd] ? cy1[sd]-stable_y1[sd] : stable_y1[sd]-cy1[sd])>STABILITY_TOL))))
         stable_batch=0;
     end
   end
 end
 always @* begin
    adjusted=bcd;
    for(k=0;k<10;k=k+1)
        if(bcd[k*4 +:4]>=5) adjusted[k*4 +:4]=bcd[k*4 +:4]+4'd3;
 end
 reg display_error,cv_error;
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    raw_valid<=0;cv_valid<=0;display_valid<=0;full_display_valid<=0;pending<=0;converting<=0;
    load_value<=0;target<=0;field<=0;bin<=0;bcd<=0;remaining<=0;
    cv_error<=0;display_error<=0;
    stable_last_valid<=0;stable_have_display<=0;stable_count<=0;
    for(j=0;j<3;j=j+1) begin
      rx0[j]<=0;rx1[j]<=0;ry0[j]<=0;ry1[j]<=0;re[j]<=0;rs[j]<=0;ra[j]<=0;rst[j]<=0;
      cx0[j]<=0;cx1[j]<=0;cy0[j]<=0;cy1[j]<=0;ce[j]<=0;cs[j]<=0;ca[j]<=0;cst[j]<=0;
      bx0[j]<=0;bx1[j]<=0;by0[j]<=0;by1[j]<=0;bst[j]<=0;
      de[j]<=0;ds[j]<=0;dw[j]<=0;dh[j]<=0;da[j]<=0;
      pe[j]<=0;ps[j]<=0;pw[j]<=0;ph[j]<=0;pa[j]<=0;
      stable_x0[j]<=0;stable_x1[j]<=0;stable_y0[j]<=0;stable_y1[j]<=0;
    end
  end else begin
    if(feature_valid && feature_index<3) begin
      raw_valid[feature_index]<=1;
      rx0[feature_index]<=feature_x0;rx1[feature_index]<=feature_x1;
      ry0[feature_index]<=feature_y0;ry1[feature_index]<=feature_y1;
      re[feature_index]<=feature_edges;rs[feature_index]<=feature_steps;
      ra[feature_index]<=feature_aspect;rst[feature_index]<=feature_status;
    end
    if(analysis_done) begin
       
       
      raw_valid<=0;cv_valid<=analysis_error?3'b000:raw_valid;cv_error<=analysis_error;
      for(j=0;j<3;j=j+1) begin
        cx0[j]<=rx0[j];cx1[j]<=rx1[j];cy0[j]<=ry0[j];cy1[j]<=ry1[j];
        ce[j]<=re[j];cs[j]<=rs[j];ca[j]<=ra[j];cst[j]<=rst[j];
      end
      converting<=1;load_value<=1;target<=0;field<=0;pending<=0;
    end else if(converting) begin
      if(load_value) begin
        load_value<=0;bcd<=0;remaining<=32;
        case(field)
          0: bin<=ce[target];
          1: bin<=cx1[target]-cx0[target]+11'd1;
          2: bin<=cy1[target]-cy0[target]+11'd1;
          3: bin<={16'd0,ca[target]};
          default: bin<=cs[target];
        endcase
      end else if(remaining!=0) begin
        bcd<={adjusted[38:0],bin[31]};bin<=bin<<1;remaining<=remaining-1'b1;
      end else begin
        case(field)
          0:pe[target]<=bcd[27:0];1:pw[target]<=bcd[15:0];
          2:ph[target]<=bcd[15:0];3:pa[target]<=bcd[19:0];
          4:ps[target]<=bcd[23:0];
        endcase
        load_value<=1;
        if(field==4) begin
          field<=0;
          if(target==2) begin
            converting<=0;pending<=1;
             
             
             
            if(stable_batch) begin
              if(stable_count<3) stable_count<=stable_count+1'b1;
            end else begin
              stable_count<=1;
              stable_last_valid<=cv_valid;
              for(j=0;j<3;j=j+1) begin
                stable_x0[j]<=cx0[j];stable_x1[j]<=cx1[j];
                stable_y0[j]<=cy0[j];stable_y1[j]<=cy1[j];
              end
            end
          end
          else target<=target+1'b1;
        end else field<=field+1'b1;
      end
    end
    if(pending && !in_vsync) begin
      pending<=0;
       
       
       
       
      if(!stable_have_display || stable_count>=2) begin
        full_display_valid<=cv_valid;
        display_valid<=cv_valid & slot_mask;display_error<=cv_error;
        stable_have_display<=1;
      end
      if(!stable_have_display || stable_count>=2) begin
      for(j=0;j<3;j=j+1) begin
        bx0[j]<=cx0[j];bx1[j]<=cx1[j];by0[j]<=cy0[j];by1[j]<=cy1[j];bst[j]<=cst[j];
        de[j]<=pe[j];dw[j]<=pw[j];dh[j]<=ph[j];da[j]<=pa[j];ds[j]<=ps[j];
      end
      end
    end
     
     
    if(!in_vsync && !pending)
      display_valid<=full_display_valid & slot_mask;
  end
 end

  
 function [34:0] glyph;
  input [7:0] ch;
  begin case(ch)
    "0":glyph=35'b01110_10001_10011_10101_11001_10001_01110;
    "1":glyph=35'b00100_01100_00100_00100_00100_00100_01110;
    "2":glyph=35'b01110_10001_00001_00010_00100_01000_11111;
    "3":glyph=35'b11110_00001_00001_01110_00001_00001_11110;
    "4":glyph=35'b00010_00110_01010_10010_11111_00010_00010;
    "5":glyph=35'b11111_10000_10000_11110_00001_00001_11110;
    "6":glyph=35'b01110_10000_10000_11110_10001_10001_01110;
    "7":glyph=35'b11111_00001_00010_00100_01000_01000_01000;
    "8":glyph=35'b01110_10001_10001_01110_10001_10001_01110;
    "9":glyph=35'b01110_10001_10001_01111_00001_00001_01110;
    "A":glyph=35'b01110_10001_10001_11111_10001_10001_10001;
    "E":glyph=35'b11111_10000_10000_11110_10000_10000_11111;
    "W":glyph=35'b10001_10001_10001_10101_10101_10101_01010;
    "H":glyph=35'b10001_10001_10001_11111_10001_10001_10001;
    "R":glyph=35'b11110_10001_10001_11110_10100_10010_10001;
    "S":glyph=35'b01111_10000_10000_01110_00001_00001_11110;
    "O":glyph=35'b01110_10001_10001_10001_10001_10001_01110;
    "K":glyph=35'b10001_10010_10100_11000_10100_10010_10001;
    "I":glyph=35'b01110_00100_00100_00100_00100_00100_01110;
    "L":glyph=35'b10000_10000_10000_10000_10000_10000_11111;
    "M":glyph=35'b10001_11011_10101_10101_10001_10001_10001;
    "F":glyph=35'b11111_10000_10000_11110_10000_10000_10000;
    "U":glyph=35'b10001_10001_10001_10001_10001_10001_01110;
    "N":glyph=35'b10001_11001_10101_10011_10001_10001_10001;
    "C":glyph=35'b01110_10001_10000_10000_10000_10001_01110;
    "D":glyph=35'b11110_10001_10001_10001_10001_10001_11110;
    "T":glyph=35'b11111_00100_00100_00100_00100_00100_00100;
    ":":glyph=35'b00000_00100_00100_00000_00100_00100_00000;
    ".":glyph=35'b00000_00000_00000_00000_00000_00100_00100;
    "-":glyph=35'b00000_00000_00000_11111_00000_00000_00000;
    default:glyph=0;
  endcase end
 endfunction
 reg [10:0] x,y;reg href_d;
 wire [10:0] tx=x-11'd16,ty=y-11'd16;
 wire [6:0] char_col=tx[10:3];
 wire [1:0] text_row=ty[6:5];
 wire panel=x>=16 && x<16+640 && y>=16 && y<16+96;
 reg [7:0] character;
 reg [34:0] bits;
 reg text_pixel;
 reg [1:0] hit_box;
 reg [7:0] cr,cg,cb;
 integer n;
 always @* begin
   character=" ";
   if(text_row<3) begin
     if(char_col==0) character="1"+text_row;
     else if(!display_valid[text_row]) begin
       case(char_col) 2:character=display_error?"E":"-";3:character=display_error?"R":" ";4:character=display_error?"R":" ";endcase
     end else begin
       case(char_col)
         2:character="E";3:character=":";
         12:character="W";13:character=":";
         19:character="H";20:character=":";
         26:character="R";27:character=":";30:character=".";
         35:character="S";36:character=":";
         44:character=bst[text_row]==0?"O":(bst[text_row]==1?"I":"L");
         45:character=bst[text_row]==0?"K":(bst[text_row]==1?"S":"I");
         46:character=bst[text_row]==0?" ":(bst[text_row]==1?"O":"M");
          
         49:character="C";50:character="A";51:character="N";52:character="D";
         default:character=" ";
       endcase
       if(char_col>=4 && char_col<=10) character="0"+((de[text_row]>>((10-char_col)*4))&4'hf);
       if(char_col>=14 && char_col<=17) character="0"+((dw[text_row]>>((17-char_col)*4))&4'hf);
       if(char_col>=21 && char_col<=24) character="0"+((dh[text_row]>>((24-char_col)*4))&4'hf);
       if(char_col==28) character="0"+da[text_row][19:16];
       if(char_col==29) character="0"+da[text_row][15:12];
       if(char_col>=31 && char_col<=33) character="0"+((da[text_row]>>((33-char_col)*4))&4'hf);
       if(char_col>=37 && char_col<=42) character="0"+((ds[text_row]>>((42-char_col)*4))&4'hf);
     end
   end
   bits=glyph(character);
   text_pixel=panel && tx[2:0]<5 && ty[4:1]<7 && bits[34-(ty[4:1]*5+tx[2:0])];
   hit_box=0;
   for(n=2;n>=0;n=n-1) if(display_valid[n] && x>=bx0[n] && x<=bx1[n] && y>=by0[n] && y<=by1[n] &&
       (x==bx0[n] || x==bx1[n] || y==by0[n] || y==by1[n])) hit_box=n+1;
   cr=in_r;cg=in_g;cb=in_b;
   if(runtime_mode==3'd3 && in_vsync && in_href) begin
     if(panel) begin
       cr=8'd12;cg=8'd12;cb=8'd12;
       if(text_pixel) case(text_row)
         0:begin cr=255;cg=240;cb=32;end
         1:begin cr=32;cg=255;cb=64;end
         default:begin cr=32;cg=224;cb=255;end
       endcase
     end else if(hit_box!=0) begin
       case(hit_box)
         1:begin cr=255;cg=240;cb=32;end
         2:begin cr=32;cg=255;cb=64;end
         3:begin cr=32;cg=224;cb=255;end
       endcase
     end
   end
 end
 always @(posedge clk or negedge rst_n) begin
   if(!rst_n) begin
     x<=0;y<=0;href_d<=0;out_r<=0;out_g<=0;out_b<=0;
     out_vsync<=0;out_hsync<=0;out_href<=0;
   end else begin
     href_d<=in_href;
     if(!in_vsync) begin x<=0;y<=0;end
     else if(in_href) begin if(x==IMAGE_WIDTH-1)x<=0;else x<=x+1'b1;end
     else if(href_d) begin x<=0;y<=y+1'b1;end
     out_r<=cr;out_g<=cg;out_b<=cb;
     out_vsync<=in_vsync;out_hsync<=in_hsync;out_href<=in_href;
   end
 end
endmodule
