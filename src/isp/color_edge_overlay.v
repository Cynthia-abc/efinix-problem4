 
 
module color_edge_overlay #(
    parameter IMAGE_WIDTH = 1920,
    parameter INPUTS_ALIGNED = 1'b0,
    parameter SPLIT_WIDTH  = 960,
     
    parameter DISPLAY_MODE = 1'b1,
     
    parameter RUNTIME_MODE = 1'b0,
     
    parameter TOP_GUARD_LINES = 8,
    parameter SHOW_ROI_GUIDE = 1'b1,
    parameter ROI_X_MIN = 560,
    parameter ROI_X_MAX = 1359,
    parameter ROI_Y_MIN = 240,
    parameter ROI_Y_MAX = 839
) (
    input        clk,
    input        rst_n,
    input        in_vsync,
    input        in_hsync,
    input        in_href,
    input  [7:0] in_r,
    input  [7:0] in_g,
    input  [7:0] in_b,
    input  [7:0] in_gray,
    input        [7:0] edge_data,
    input        edge_valid,
    input  [2:0] runtime_mode_i,
    input        target_valid,
    input  [2:0] target_shape,
    input [10:0] bbox_x_min,
    input [10:0] bbox_x_max,
    input [10:0] bbox_y_min,
    input [10:0] bbox_y_max,
     
     
    input        analysis_valid,
    input [31:0] analysis_edge_count,
    input [10:0] analysis_width,
    input [10:0] analysis_height,
    output reg [7:0] out_r,
    output reg [7:0] out_g,
    output reg [7:0] out_b,
    output out_vsync,output out_hsync,output out_href
);

    reg [7:0] rgb_r_d1, rgb_r_d2, rgb_r_d3;
    reg [7:0] rgb_g_d1, rgb_g_d2, rgb_g_d3;
    reg [7:0] rgb_b_d1, rgb_b_d2, rgb_b_d3;
    reg [7:0] gray_d1, gray_d2, gray_d3;
    reg       left_d1, left_d2, left_d3;
    reg [10:0] x_count;
    reg [10:0] y_count;
    reg [10:0] x_d1, x_d2, x_d3;
    reg [10:0] y_d1, y_d2, y_d3;

     
     
     
     
    reg [2:0] mode_d1,mode_d2,mode_d3;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin mode_d1<=0;mode_d2<=0;mode_d3<=0;end
        else begin mode_d1<=runtime_mode_i;mode_d2<=mode_d1;mode_d3<=mode_d2;end
    end
    wire show_recognition = !RUNTIME_MODE || mode_d3==3'd3;
    wire edge_pixel = top_guard_d3 && display_edge_valid && display_edge_data==8'hff;
    reg [3:0] sync_v,sync_h,sync_de;
    reg [2:0] edge_v;
    reg [7:0] edge0,edge1,edge2;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin sync_v<=0;sync_h<=0;sync_de<=0;edge_v<=0;edge0<=0;edge1<=0;edge2<=0;end
        else begin
            sync_v<={sync_v[2:0],in_vsync};sync_h<={sync_h[2:0],in_hsync};
            sync_de<={sync_de[2:0],in_href};edge_v<={edge_v[1:0],edge_valid};
            edge0<=edge_data;edge1<=edge0;edge2<=edge1;
        end
    end
    assign out_vsync=sync_v[3];assign out_hsync=sync_h[3];assign out_href=sync_de[3];
    wire display_edge_valid=INPUTS_ALIGNED ? edge_v[2]:edge_valid;
    wire [7:0] display_edge_data=INPUTS_ALIGNED ? edge2:edge_data;
    wire display_active=INPUTS_ALIGNED ? sync_v[2] && sync_de[2]:in_vsync && in_href;
    generate if(INPUTS_ALIGNED) begin:g_aligned
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                rgb_r_d1<=0;rgb_r_d2<=0;rgb_r_d3<=0;
                rgb_g_d1<=0;rgb_g_d2<=0;rgb_g_d3<=0;
                rgb_b_d1<=0;rgb_b_d2<=0;rgb_b_d3<=0;
                gray_d1<=0;gray_d2<=0;gray_d3<=0;
                left_d1<=0;left_d2<=0;left_d3<=0;
                x_count<=0;x_d1<=0;x_d2<=0;x_d3<=0;y_d1<=0;y_d2<=0;y_d3<=0;
            end else begin
                rgb_r_d1<=in_r;rgb_r_d2<=rgb_r_d1;rgb_r_d3<=rgb_r_d2;
                rgb_g_d1<=in_g;rgb_g_d2<=rgb_g_d1;rgb_g_d3<=rgb_g_d2;
                rgb_b_d1<=in_b;rgb_b_d2<=rgb_b_d1;rgb_b_d3<=rgb_b_d2;
                gray_d1<=in_gray;gray_d2<=gray_d1;gray_d3<=gray_d2;
                left_d1<=(x_count<SPLIT_WIDTH);left_d2<=left_d1;left_d3<=left_d2;
                x_d1<=x_count;x_d2<=x_d1;x_d3<=x_d2;
                y_d1<=y_count;y_d2<=y_d1;y_d3<=y_d2;
                if(!in_vsync || !in_href || x_count==IMAGE_WIDTH-1) x_count<=0;
                else x_count<=x_count+1'b1;
            end
        end
    end else begin:g_legacy
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rgb_r_d1 <= 8'd0;
            rgb_r_d2 <= 8'd0;
            rgb_r_d3 <= 8'd0;
            rgb_g_d1 <= 8'd0;
            rgb_g_d2 <= 8'd0;
            rgb_g_d3 <= 8'd0;
            rgb_b_d1 <= 8'd0;
            rgb_b_d2 <= 8'd0;
            rgb_b_d3 <= 8'd0;
            gray_d1  <= 8'd0;
            gray_d2  <= 8'd0;
            gray_d3  <= 8'd0;
            left_d1  <= 1'b1;
            left_d2  <= 1'b1;
            left_d3  <= 1'b1;
            x_count  <= 11'd0;
            x_d1     <= 11'd0;
            x_d2     <= 11'd0;
            x_d3     <= 11'd0;
            y_d1     <= 11'd0;
            y_d2     <= 11'd0;
            y_d3     <= 11'd0;
        end else if (!in_vsync) begin
            rgb_r_d1 <= 8'd0;
            rgb_r_d2 <= 8'd0;
            rgb_r_d3 <= 8'd0;
            rgb_g_d1 <= 8'd0;
            rgb_g_d2 <= 8'd0;
            rgb_g_d3 <= 8'd0;
            rgb_b_d1 <= 8'd0;
            rgb_b_d2 <= 8'd0;
            rgb_b_d3 <= 8'd0;
            gray_d1  <= 8'd0;
            gray_d2  <= 8'd0;
            gray_d3  <= 8'd0;
            left_d1  <= 1'b1;
            left_d2  <= 1'b1;
            left_d3  <= 1'b1;
            x_count  <= 11'd0;
            x_d1     <= 11'd0;
            x_d2     <= 11'd0;
            x_d3     <= 11'd0;
            y_d1     <= 11'd0;
            y_d2     <= 11'd0;
            y_d3     <= 11'd0;
        end else if (!in_href) begin
            rgb_r_d1 <= 8'd0;
            rgb_r_d2 <= 8'd0;
            rgb_r_d3 <= 8'd0;
            rgb_g_d1 <= 8'd0;
            rgb_g_d2 <= 8'd0;
            rgb_g_d3 <= 8'd0;
            rgb_b_d1 <= 8'd0;
            rgb_b_d2 <= 8'd0;
            rgb_b_d3 <= 8'd0;
            gray_d1  <= 8'd0;
            gray_d2  <= 8'd0;
            gray_d3  <= 8'd0;
            left_d1  <= 1'b1;
            left_d2  <= 1'b1;
            left_d3  <= 1'b1;
            x_count  <= 11'd0;
            x_d1     <= 11'd0;
            x_d2     <= 11'd0;
            x_d3     <= 11'd0;
            y_d1     <= 11'd0;
            y_d2     <= 11'd0;
            y_d3     <= 11'd0;
        end else begin
            rgb_r_d1 <= in_r;
            rgb_r_d2 <= rgb_r_d1;
            rgb_r_d3 <= rgb_r_d2;
            rgb_g_d1 <= in_g;
            rgb_g_d2 <= rgb_g_d1;
            rgb_g_d3 <= rgb_g_d2;
            rgb_b_d1 <= in_b;
            rgb_b_d2 <= rgb_b_d1;
            rgb_b_d3 <= rgb_b_d2;
            gray_d1  <= in_gray;
            gray_d2  <= gray_d1;
            gray_d3  <= gray_d2;
            left_d1  <= (x_count < SPLIT_WIDTH);
            left_d2  <= left_d1;
            left_d3  <= left_d2;
            x_d1     <= x_count;
            x_d2     <= x_d1;
            x_d3     <= x_d2;
            y_d1     <= y_count;
            y_d2     <= y_d1;
            y_d3     <= y_d2;

            if (x_count < IMAGE_WIDTH - 1)
                x_count <= x_count + 1'b1;
            else
                x_count <= 11'd0;
        end
    end

    end endgenerate

     
     
    reg        previous_href;
    reg        top_guard_d1, top_guard_d2, top_guard_d3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            y_count       <= 11'd0;
            previous_href <= 1'b0;
            top_guard_d1  <= 1'b0;
            top_guard_d2  <= 1'b0;
            top_guard_d3  <= 1'b0;
        end else if (!in_vsync) begin
            y_count       <= 11'd0;
            previous_href <= 1'b0;
            top_guard_d1  <= 1'b0;
            top_guard_d2  <= 1'b0;
            top_guard_d3  <= 1'b0;
        end else begin
            top_guard_d2 <= top_guard_d1;
            top_guard_d3 <= top_guard_d2;

            if (in_href) begin
                top_guard_d1  <= (y_count >= TOP_GUARD_LINES);
                previous_href <= 1'b1;
            end else begin
                 
                 
                if (previous_href && (y_count < 11'd2047))
                    y_count <= y_count + 1'b1;
                previous_href <= 1'b0;
            end
        end
    end

    reg [7:0] composed_r;
    reg [7:0] composed_g;
    reg [7:0] composed_b;

    localparam [2:0] SHAPE_CIRCLE = 3'd1;
    localparam [2:0] SHAPE_RECT   = 3'd2;
    localparam [2:0] SHAPE_TRIANGLE = 3'd3;
    localparam [2:0] SHAPE_STAR   = 3'd4;
    localparam [10:0] LABEL_X = 11'd32;
    localparam [10:0] LABEL_Y = 11'd24;

    wire [11:0] bbox_center_x_sum = {1'b0, bbox_x_min} + {1'b0, bbox_x_max};
    wire [11:0] bbox_center_y_sum = {1'b0, bbox_y_min} + {1'b0, bbox_y_max};
    wire [10:0] bbox_center_x = bbox_center_x_sum[11:1];
    wire [10:0] bbox_center_y = bbox_center_y_sum[11:1];

    wire inside_box_x = (x_d3 >= bbox_x_min) && (x_d3 <= bbox_x_max);
    wire inside_box_y = (y_d3 >= bbox_y_min) && (y_d3 <= bbox_y_max);
    wire on_box_left   = (x_d3 >= bbox_x_min) &&
                         (x_d3 <= (bbox_x_min + 1'b1));
    wire on_box_right  = (x_d3 <= bbox_x_max) &&
                         ((x_d3 + 1'b1) >= bbox_x_max);
    wire on_box_top    = (y_d3 >= bbox_y_min) &&
                         (y_d3 <= (bbox_y_min + 1'b1));
    wire on_box_bottom = (y_d3 <= bbox_y_max) &&
                         ((y_d3 + 1'b1) >= bbox_y_max);
    wire bbox_pixel = target_valid &&
        (((on_box_left || on_box_right) && inside_box_y) ||
         ((on_box_top || on_box_bottom) && inside_box_x));

    wire center_horizontal = target_valid &&
        (y_d3 >= bbox_center_y) && (y_d3 <= (bbox_center_y + 1'b1)) &&
        ((x_d3 + 11'd8) >= bbox_center_x) &&
        (x_d3 <= (bbox_center_x + 11'd8));
    wire center_vertical = target_valid &&
        (x_d3 >= bbox_center_x) && (x_d3 <= (bbox_center_x + 1'b1)) &&
        ((y_d3 + 11'd8) >= bbox_center_y) &&
        (y_d3 <= (bbox_center_y + 11'd8));
    wire center_pixel = center_horizontal || center_vertical;

     
     
    function [4:0] font_row;
        input [3:0] character;
        input [2:0] row;
        begin
            font_row = 5'b00000;
            case (character)
                4'd0: case (row)  
                    0: font_row=5'b01110; 1: font_row=5'b10001;
                    2: font_row=5'b10000; 3: font_row=5'b10000;
                    4: font_row=5'b10000; 5: font_row=5'b10001;
                    6: font_row=5'b01110; default: font_row=5'b00000;
                endcase
                4'd1: case (row)  
                    0: font_row=5'b11111; 1: font_row=5'b00100;
                    2: font_row=5'b00100; 3: font_row=5'b00100;
                    4: font_row=5'b00100; 5: font_row=5'b00100;
                    6: font_row=5'b11111; default: font_row=5'b00000;
                endcase
                4'd2: case (row)  
                    0: font_row=5'b11110; 1: font_row=5'b10001;
                    2: font_row=5'b10001; 3: font_row=5'b11110;
                    4: font_row=5'b10100; 5: font_row=5'b10010;
                    6: font_row=5'b10001; default: font_row=5'b00000;
                endcase
                4'd3: case (row)  
                    0: font_row=5'b10000; 1: font_row=5'b10000;
                    2: font_row=5'b10000; 3: font_row=5'b10000;
                    4: font_row=5'b10000; 5: font_row=5'b10000;
                    6: font_row=5'b11111; default: font_row=5'b00000;
                endcase
                4'd4: case (row)  
                    0: font_row=5'b11111; 1: font_row=5'b10000;
                    2: font_row=5'b10000; 3: font_row=5'b11110;
                    4: font_row=5'b10000; 5: font_row=5'b10000;
                    6: font_row=5'b11111; default: font_row=5'b00000;
                endcase
                4'd5: case (row)  
                    0: font_row=5'b11111; 1: font_row=5'b00100;
                    2: font_row=5'b00100; 3: font_row=5'b00100;
                    4: font_row=5'b00100; 5: font_row=5'b00100;
                    6: font_row=5'b00100; default: font_row=5'b00000;
                endcase
                4'd6: case (row)  
                    0: font_row=5'b10001; 1: font_row=5'b10001;
                    2: font_row=5'b10001; 3: font_row=5'b10001;
                    4: font_row=5'b10001; 5: font_row=5'b10001;
                    6: font_row=5'b01110; default: font_row=5'b00000;
                endcase
                4'd7: case (row)  
                    0: font_row=5'b10001; 1: font_row=5'b11001;
                    2: font_row=5'b10101; 3: font_row=5'b10101;
                    4: font_row=5'b10011; 5: font_row=5'b10001;
                    6: font_row=5'b10001; default: font_row=5'b00000;
                endcase
                4'd8: case (row)  
                    0: font_row=5'b10001; 1: font_row=5'b10010;
                    2: font_row=5'b10100; 3: font_row=5'b11000;
                    4: font_row=5'b10100; 5: font_row=5'b10010;
                    6: font_row=5'b10001; default: font_row=5'b00000;
                endcase
                4'd9: case (row)  
                    0: font_row=5'b01110; 1: font_row=5'b10001;
                    2: font_row=5'b10001; 3: font_row=5'b10001;
                    4: font_row=5'b10001; 5: font_row=5'b10001;
                    6: font_row=5'b01110; default: font_row=5'b00000;
                endcase
                4'd10: case (row)  
                    0: font_row=5'b10001; 1: font_row=5'b10001;
                    2: font_row=5'b10001; 3: font_row=5'b10101;
                    4: font_row=5'b10101; 5: font_row=5'b10101;
                    6: font_row=5'b01010; default: font_row=5'b00000;
                endcase
                4'd11: case (row)  
                    0: font_row=5'b01111; 1: font_row=5'b10000;
                    2: font_row=5'b10000; 3: font_row=5'b01110;
                    4: font_row=5'b00001; 5: font_row=5'b00001;
                    6: font_row=5'b11110; default: font_row=5'b00000;
                endcase
                4'd12: case (row)  
                    0: font_row=5'b01110; 1: font_row=5'b10001;
                    2: font_row=5'b10001; 3: font_row=5'b11111;
                    4: font_row=5'b10001; 5: font_row=5'b10001;
                    6: font_row=5'b10001; default: font_row=5'b00000;
                endcase
                default: font_row=5'b00000;
            endcase
        end
    endfunction

    wire [10:0] label_rel_x = x_d3 - LABEL_X;
    wire [10:0] label_rel_y = y_d3 - LABEL_Y;
    wire [2:0] glyph_index = label_rel_x[7:5];
    wire [2:0] glyph_column = label_rel_x[4:2];
    wire [2:0] glyph_row_index = label_rel_y[4:2];
    reg  [3:0] glyph_character;
    reg  [3:0] label_length;

    always @* begin
        glyph_character = 4'd15;
        case (target_shape)
            SHAPE_CIRCLE: begin
                label_length = 4'd6;
                case (glyph_index)
                    0: glyph_character=4'd0; 1: glyph_character=4'd1;
                    2: glyph_character=4'd2; 3: glyph_character=4'd0;
                    4: glyph_character=4'd3; 5: glyph_character=4'd4;
                    default: glyph_character=4'd15;
                endcase
            end
            SHAPE_RECT: begin
                label_length = 4'd4;
                case (glyph_index)
                    0: glyph_character=4'd2; 1: glyph_character=4'd4;
                    2: glyph_character=4'd0; 3: glyph_character=4'd5;
                    default: glyph_character=4'd15;
                endcase
            end
            SHAPE_TRIANGLE: begin
                label_length = 4'd3;
                case (glyph_index)
                    0: glyph_character=4'd5; 1: glyph_character=4'd2;
                    2: glyph_character=4'd1;
                    default: glyph_character=4'd15;
                endcase
            end
            SHAPE_STAR: begin
                label_length = 4'd4;
                case (glyph_index)
                    0: glyph_character=4'd11; 1: glyph_character=4'd5;
                    2: glyph_character=4'd12; 3: glyph_character=4'd2;
                    default: glyph_character=4'd15;
                endcase
            end
            default: begin
                label_length = 4'd7;
                case (glyph_index)
                    0: glyph_character=4'd6; 1: glyph_character=4'd7;
                    2: glyph_character=4'd8; 3: glyph_character=4'd7;
                    4: glyph_character=4'd9; 5: glyph_character=4'd10;
                    6: glyph_character=4'd7;
                    default: glyph_character=4'd15;
                endcase
            end
        endcase
    end

    wire [11:0] label_x_limit = {1'b0, LABEL_X} +
                               ({8'd0, label_length} << 5);
    wire label_region = target_valid && (x_d3 >= LABEL_X) &&
        ({1'b0, x_d3} < label_x_limit) &&
        (y_d3 >= LABEL_Y) && (y_d3 < (LABEL_Y + 11'd28)) &&
        (glyph_index < label_length) &&
        (glyph_column < 3'd5) && (glyph_row_index < 3'd7);
    wire [4:0] selected_font_row = font_row(glyph_character, glyph_row_index);
    wire label_pixel = label_region && selected_font_row[4 - glyph_column];
    wire recognition_pixel = bbox_pixel || center_pixel || label_pixel;

     
     
     
    wire [19:0] edge_bar_raw = analysis_edge_count[31:12];
    wire [9:0] edge_bar_len = (edge_bar_raw > 20'd512) ? 10'd512 : edge_bar_raw[9:0];
    wire [8:0] width_bar_raw = analysis_width[10:2];
    wire [8:0] height_bar_raw = analysis_height[10:2];
     
     
    wire [9:0] width_bar_len = {1'b0,width_bar_raw};
    wire [9:0] height_bar_len = {1'b0,height_bar_raw};
    wire analysis_panel = show_recognition && analysis_valid &&
                          (x_d3 >= LABEL_X) && (x_d3 < LABEL_X + 11'd520) &&
                          (y_d3 >= 11'd64) && (y_d3 < 11'd88);
    wire edge_bar_pixel = analysis_panel && (y_d3 >= 11'd64) && (y_d3 < 11'd70) &&
                          (x_d3 < LABEL_X + edge_bar_len);
    wire width_bar_pixel = analysis_panel && (y_d3 >= 11'd72) && (y_d3 < 11'd78) &&
                           (x_d3 < LABEL_X + width_bar_len);
    wire height_bar_pixel = analysis_panel && (y_d3 >= 11'd80) && (y_d3 < 11'd86) &&
                            (x_d3 < LABEL_X + height_bar_len);
    wire analysis_meter_pixel = edge_bar_pixel || width_bar_pixel || height_bar_pixel;

     
     
    wire roi_x_inside = (x_d3 >= ROI_X_MIN) && (x_d3 <= ROI_X_MAX);
    wire roi_y_inside = (y_d3 >= ROI_Y_MIN) && (y_d3 <= ROI_Y_MAX);
    wire roi_left_segment = (x_d3 >= ROI_X_MIN) &&
                            (x_d3 <= (ROI_X_MIN + 11'd40));
    wire roi_right_segment = (x_d3 <= ROI_X_MAX) &&
                             ((x_d3 + 11'd40) >= ROI_X_MAX);
    wire roi_top_segment = (y_d3 >= ROI_Y_MIN) &&
                           (y_d3 <= (ROI_Y_MIN + 11'd40));
    wire roi_bottom_segment = (y_d3 <= ROI_Y_MAX) &&
                              ((y_d3 + 11'd40) >= ROI_Y_MAX);
    wire roi_left_line = (x_d3 >= ROI_X_MIN) &&
                         (x_d3 <= (ROI_X_MIN + 1'b1));
    wire roi_right_line = (x_d3 <= ROI_X_MAX) &&
                          ((x_d3 + 1'b1) >= ROI_X_MAX);
    wire roi_top_line = (y_d3 >= ROI_Y_MIN) &&
                        (y_d3 <= (ROI_Y_MIN + 1'b1));
    wire roi_bottom_line = (y_d3 <= ROI_Y_MAX) &&
                           ((y_d3 + 1'b1) >= ROI_Y_MAX);
    wire roi_guide_pixel = SHOW_ROI_GUIDE &&
        (((roi_top_line || roi_bottom_line) &&
          (roi_left_segment || roi_right_segment) && roi_x_inside) ||
         ((roi_left_line || roi_right_line) &&
          (roi_top_segment || roi_bottom_segment) && roi_y_inside));

    always @* begin
        if (show_recognition && recognition_pixel && (target_shape == SHAPE_CIRCLE)) begin
            composed_r = 8'd0;
            composed_g = 8'hff;
            composed_b = 8'd0;
        end else if (show_recognition && recognition_pixel && (target_shape == SHAPE_RECT)) begin
            composed_r = 8'd0;
            composed_g = 8'hff;
            composed_b = 8'hff;
        end else if (show_recognition && recognition_pixel) begin
            composed_r = 8'hff;
            composed_g = 8'hff;
            composed_b = 8'd0;
        end else if (edge_bar_pixel) begin
            composed_r = 8'hff;
            composed_g = 8'd0;
            composed_b = 8'hff;
        end else if (width_bar_pixel) begin
            composed_r = 8'hff;
            composed_g = 8'hff;
            composed_b = 8'd0;
        end else if (height_bar_pixel) begin
            composed_r = 8'd0;
            composed_g = 8'hff;
            composed_b = 8'hff;
        end else if (show_recognition && roi_guide_pixel) begin
            composed_r = 8'd0;
            composed_g = 8'h80;
            composed_b = 8'hff;
        end else if (RUNTIME_MODE && mode_d3==3'd0) begin
            composed_r = rgb_r_d3;
            composed_g = rgb_g_d3;
            composed_b = rgb_b_d3;
        end else if (RUNTIME_MODE && mode_d3==3'd1) begin
            if (left_d3) begin
                composed_r = gray_d3;
                composed_g = gray_d3;
                composed_b = gray_d3;
            end else begin
                composed_r = edge_pixel ? 8'hff:8'd0;
                composed_g = edge_pixel ? 8'hff:8'd0;
                composed_b = edge_pixel ? 8'hff:8'd0;
            end
        end else if (!RUNTIME_MODE && (DISPLAY_MODE == 1'b0) && left_d3) begin
            composed_r = gray_d3;
            composed_g = gray_d3;
            composed_b = gray_d3;
        end else if (top_guard_d3 && display_edge_valid && (display_edge_data == 8'hff)) begin
            composed_r = 8'hff;
            composed_g = 8'd0;
            composed_b = 8'd0;
        end else begin
            composed_r = rgb_r_d3;
            composed_g = rgb_g_d3;
            composed_b = rgb_b_d3;
        end
    end

     
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_r <= 8'd0;
            out_g <= 8'd0;
            out_b <= 8'd0;
        end else if (!display_active) begin
            out_r <= 8'd0;
            out_g <= 8'd0;
            out_b <= 8'd0;
        end else begin
            out_r <= composed_r;
            out_g <= composed_g;
            out_b <= composed_b;
        end
    end

endmodule
