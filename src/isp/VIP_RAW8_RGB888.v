/*-----------------------------------------------------------------------
                                 \\\|///
                               \\  - -  //
                                (  @ @  )
+-----------------------------oOOo-(_)-oOOo-----------------------------+
CONFIDENTIAL IN CONFIDENCE
This confidential and proprietary software may be only used as authorized
by a licensing agreement from CrazyBingo (Thereturnofbingo).
In the event of publication, the following notice is applicable:
Copyright (C) 2013-20xx CrazyBingo Corporation
The entire notice above must be reproduced on all authorized copies.
Author              :       CrazyBingo
Technology blogs    :       www.crazyfpga.com
Email Address       :       crazyfpga@vip.qq.com
Filename            :       VIP_YCbCr444_RGB888.v
Date                :       2014-05-03
Description         :       The testbench of VIP_YCbCr444_RGB888.
Modification History    :
Date            By          Version         Change Description
=========================================================================
14/05/03        CrazyBingo  1.0             Original
-------------------------------------------------------------------------
|                                     Oooo                              |
+-------------------------------oooO--(   )-----------------------------+
                               (   )   ) /
                                \ (   (_/
                                 \_)
-----------------------------------------------------------------------*/

`timescale 1ns/1ns
module VIP_RAW8_RGB888
#(
    parameter   [13:0]  IMG_HDISP = 640,     
    parameter   [13:0]  IMG_VDISP = 480
)
(
     
    input               clk,                 
    input               rst_n,               
    
    input       [1:0]   mirror,

     
    input               per_frame_vsync,     
    input               per_frame_href,      
    input               per_frame_hsync, 
    input       [7:0]   per_img_RAW,         

    
     
    output              post_frame_vsync,    
    output              post_frame_href,     
    output              post_frame_hsync,    
    output reg  [7:0]   post_img_red,        
    output reg  [7:0]   post_img_green,      
    output reg  [7:0]   post_img_blue        
);

 
 
     
wire                matrix_frame_vsync;  
wire                matrix_frame_href;   
wire                matrix_frame_hsync;  
wire        [7:0]   matrix_p11, matrix_p12, matrix_p13;  
wire        [7:0]   matrix_p21, matrix_p22, matrix_p23;
wire        [7:0]   matrix_p31, matrix_p32, matrix_p33;
VIP_Matrix_Generate_3X3_8Bit    
#(
    .IMG_HDISP  (IMG_HDISP),     
    .IMG_VDISP  (IMG_VDISP)
)
u_VIP_Matrix_Generate_3X3_8Bit
(
     
    .clk                    (clk),                   
    .rst_n                  (rst_n),                 

     
    .per_frame_vsync        (per_frame_vsync),       
    .per_frame_href         (per_frame_href),        
    .per_frame_hsync        (per_frame_hsync),       
    .per_img_Y              (per_img_RAW),           

     
    .matrix_frame_vsync     (matrix_frame_vsync),    
    .matrix_frame_href      (matrix_frame_href),     
    .matrix_frame_hsync     (matrix_frame_hsync),    
    .matrix_p11(matrix_p11),    .matrix_p12(matrix_p12),    .matrix_p13(matrix_p13),     
    .matrix_p21(matrix_p21),    .matrix_p22(matrix_p22),    .matrix_p23(matrix_p23),
    .matrix_p31(matrix_p31),    .matrix_p32(matrix_p32),    .matrix_p33(matrix_p33)
);


 
 
reg     matrix_frame_href_r;
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        matrix_frame_href_r <= 0;
    else
        matrix_frame_href_r <= matrix_frame_href;
end
wire    matrix_frame_href_end   =   (matrix_frame_href_r & ~matrix_frame_href) ? 1'b1 : 1'b0;    

 
 
reg [10:0]  line_cnt;
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        line_cnt <= 0;
    else if(matrix_frame_vsync == 1'b1)  
        begin
        if(matrix_frame_href_end)
            line_cnt <= (line_cnt < IMG_VDISP - 1'b1) ? line_cnt + 1'b1 : 11'd0;
        else
            line_cnt <= line_cnt;
        end
    else
        line_cnt <= 0;
end

 
 
reg [13:0]  point_cnt;
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        point_cnt <= 0;
    else if(matrix_frame_href == 1'b1)   
        point_cnt <= (line_cnt < IMG_HDISP - 1'b1) ? point_cnt + 1'b1 : 11'd0;
    else
        point_cnt <= 0;
end

 
 
 
localparam  OddLINE_OddPOINT    =   2'b11;   
localparam  OddLINE_Even_POINT  =   2'b10;   
localparam  EvenLINE_OddPOINT   =   2'b01;   
localparam  EvenLINE_EvenPOINT  =   2'b00;   
reg [9:0]   post_img_red_r;
reg [9:0]   post_img_green_r;
reg [9:0]   post_img_blue_r;
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
        post_img_red_r  <=  0;
        post_img_green_r<=  0;
        post_img_blue_r <=  0;
    end
    else
    begin
        case(mirror)
            2'b10 : 
            begin
                case({line_cnt[0], point_cnt[0]})
                     
                    OddLINE_OddPOINT:    
                    begin    
                        post_img_red_r  <=  matrix_p22;
                        post_img_green_r<=  (matrix_p12 + matrix_p21 + matrix_p23 + matrix_p32)>>2;
                        post_img_blue_r <=  (matrix_p11 + matrix_p13 + matrix_p31 + matrix_p33)>>2;
                    end
                    OddLINE_Even_POINT:  
                    begin    
                        post_img_red_r  <=  (matrix_p21 + matrix_p23)>>1;
                        post_img_green_r<=  matrix_p22;
                        post_img_blue_r <=  (matrix_p12 + matrix_p32)>>1;
                    end
                     
                    EvenLINE_OddPOINT:   
                    begin    
                        post_img_red_r  <=  (matrix_p12 + matrix_p32)>>1;
                        post_img_green_r<=  matrix_p22;
                        post_img_blue_r <=  (matrix_p21 + matrix_p23)>>1;
                    end
                    EvenLINE_EvenPOINT:  
                    begin    
                        post_img_red_r  <=  (matrix_p11 + matrix_p13 + matrix_p31 + matrix_p33)>>2;
                        post_img_green_r<=  (matrix_p12 + matrix_p21 + matrix_p23 + matrix_p32)>>2;
                        post_img_blue_r <=  matrix_p22;     
                    end
                endcase
            end
            2'b11 : 
            begin
                case({line_cnt[0], point_cnt[0]})
                    
                   OddLINE_OddPOINT:    
                   begin    
                       post_img_red_r  <=  (matrix_p21 + matrix_p23)>>1;
                       post_img_green_r<=  matrix_p22;
                       post_img_blue_r <=  (matrix_p12 + matrix_p32)>>1;
                   end
                   OddLINE_Even_POINT:  
                   begin    
                       post_img_red_r  <=  matrix_p22;
                       post_img_green_r<=  (matrix_p12 + matrix_p21 + matrix_p23 + matrix_p32)>>2;
                       post_img_blue_r <=  (matrix_p11 + matrix_p13 + matrix_p31 + matrix_p33)>>2;
                   end
                    
                   EvenLINE_OddPOINT:   
                   begin    
                       post_img_red_r  <=  (matrix_p11 + matrix_p13 + matrix_p31 + matrix_p33)>>2;
                       post_img_green_r<=  (matrix_p12 + matrix_p21 + matrix_p23 + matrix_p32)>>2;
                       post_img_blue_r <=  matrix_p22;     
                   end
                   EvenLINE_EvenPOINT:  
                   begin    
                       post_img_red_r  <=  (matrix_p12 + matrix_p32)>>1;
                       post_img_green_r<=  matrix_p22;
                       post_img_blue_r <=  (matrix_p21 + matrix_p23)>>1;
                   end
                endcase
            end
            2'b00 : 
            begin
                case({line_cnt[0], point_cnt[0]})
                     
                    OddLINE_OddPOINT:    
                    begin    
                        post_img_red_r  <=  (matrix_p12 + matrix_p32)>>1;
                        post_img_green_r<=  matrix_p22;
                        post_img_blue_r <=  (matrix_p21 + matrix_p23)>>1;
                    end
                    OddLINE_Even_POINT:  
                    begin    
                        post_img_red_r  <=  (matrix_p11 + matrix_p13 + matrix_p31 + matrix_p33)>>2;
                        post_img_green_r<=  (matrix_p12 + matrix_p21 + matrix_p23 + matrix_p32)>>2;
                        post_img_blue_r <=  matrix_p22;
                    end
                     
                    EvenLINE_OddPOINT:   
                    begin    
                        post_img_red_r  <=  matrix_p22;
                        post_img_green_r<=  (matrix_p12 + matrix_p21 + matrix_p23 + matrix_p32)>>2;
                        post_img_blue_r <=  (matrix_p11 + matrix_p13 + matrix_p31 + matrix_p33)>>2;
                    end
                    EvenLINE_EvenPOINT:  
                    begin    
                        post_img_red_r  <=  (matrix_p21 + matrix_p23)>>1;
                        post_img_green_r<=  matrix_p22;
                        post_img_blue_r <=  (matrix_p12 + matrix_p32)>>1;
                    end
                endcase
            end
            2'b01 : 
            begin
                case({line_cnt[0], point_cnt[0]})
                     
                    OddLINE_OddPOINT:    
                    begin    
                        post_img_red_r  <=  (matrix_p11 + matrix_p13 + matrix_p31 + matrix_p33)>>2;
                        post_img_green_r<=  (matrix_p12 + matrix_p21 + matrix_p23 + matrix_p32)>>2;
                        post_img_blue_r <=  matrix_p22;     
                    end
                    OddLINE_Even_POINT:  
                    begin    
                        post_img_red_r  <=  (matrix_p12 + matrix_p32)>>1;
                        post_img_green_r<=  matrix_p22;
                        post_img_blue_r <=  (matrix_p21 + matrix_p23)>>1;
                    end
                     
                    EvenLINE_OddPOINT:   
                    begin    
                        post_img_red_r  <=  (matrix_p21 + matrix_p23)>>1;
                        post_img_green_r<=  matrix_p22;
                        post_img_blue_r <=  (matrix_p12 + matrix_p32)>>1;
                    end
                    EvenLINE_EvenPOINT:  
                    begin    
                        post_img_red_r  <=  matrix_p22;
                        post_img_green_r<=  (matrix_p12 + matrix_p21 + matrix_p23 + matrix_p32)>>2;
                        post_img_blue_r <=  (matrix_p11 + matrix_p13 + matrix_p31 + matrix_p33)>>2;
                    end
                endcase
            end
        endcase
    end
end

 
 
 

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
        post_img_red <= 8'b0;
        post_img_green <= 8'b0;
        post_img_blue <= 8'b0;
    end
    else
    begin
        post_img_red <= post_img_red_r[7:0];
        post_img_green <= post_img_green_r[7:0];
        post_img_blue <= post_img_blue_r[7:0];
    end
end

 
 
reg [1:0]   post_frame_vsync_r;
reg [1:0]   post_frame_href_r;
reg [1:0]   post_frame_hsync_r;
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        begin
        post_frame_vsync_r  <=  0;
        post_frame_href_r   <=  0;
        post_frame_hsync_r  <=  0;
        end
    else
        begin
        post_frame_vsync_r  <=  {post_frame_vsync_r[0], matrix_frame_vsync};
        post_frame_href_r   <=  {post_frame_href_r[0],  matrix_frame_href};
        post_frame_hsync_r  <=  {post_frame_hsync_r[0], matrix_frame_hsync};
        end
end
assign  post_frame_vsync    =   post_frame_vsync_r[1];
assign  post_frame_href     =   post_frame_href_r[1];
assign  post_frame_hsync    =   post_frame_hsync_r[1];

endmodule
