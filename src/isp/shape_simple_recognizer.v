 
 
 
 
 
 
 
 
module shape_simple_recognizer #(
    parameter integer IMAGE_WIDTH=1920,
    parameter integer IMAGE_HEIGHT=1080,
    parameter integer BLOCK=32,
     
     
     
    parameter integer ROI_X_MIN=0,
    parameter integer ROI_X_MAX=IMAGE_WIDTH-1,
    parameter integer ROI_Y_MIN=0,
    parameter integer ROI_Y_MAX=IMAGE_HEIGHT-1,
    parameter integer GRID_WIDTH=IMAGE_WIDTH/BLOCK,
    parameter integer GRID_HEIGHT=(IMAGE_HEIGHT+BLOCK-1)/BLOCK,
    parameter integer GXW=(GRID_WIDTH<=2)?1:$clog2(GRID_WIDTH),
    parameter integer GYW=(GRID_HEIGHT<=2)?1:$clog2(GRID_HEIGHT),
    parameter integer MAP_AW=(GRID_WIDTH*GRID_HEIGHT<=2)?1:$clog2(GRID_WIDTH*GRID_HEIGHT)
) (
    input clk,input rst_n,
    input in_vsync,input in_href,input edge_valid,input [7:0] edge_data,
    output reg result_valid,
    output reg [2:0] result_shape,  
    output reg [7:0] result_confidence,
    output reg [10:0] result_x_min,result_x_max,result_y_min,result_y_max,
    output reg [11:0] result_edge_cells,
    output reg analysis_done,
    output busy
);
    localparam integer MAP_N=GRID_WIDTH*GRID_HEIGHT;
    localparam [2:0] SHAPE_CIRCLE=3'd1, SHAPE_RECT=3'd2;
    localparam [3:0] IDLE=0,CAPTURE=1,AN_READ=2,AN_WAIT=3,AN_USE=4,
                     BD_READ=5,BD_WAIT=6,BD_USE=7,EMIT=8,DONE=9;
    reg [3:0] state;
    assign busy=(state!=IDLE);

    reg coarse_map[0:MAP_N-1];
    reg [MAP_AW-1:0] map_addr,map_wa;
    reg map_q,map_data,map_we;
    always @(posedge clk) begin
        if(map_we) coarse_map[map_wa]<=map_data;
        map_q<=coarse_map[map_addr];
    end

    reg [10:0] pixel_x,pixel_y;
    reg href_d,vs_d,block_or;
     
     
     
    reg column_or[0:GRID_WIDTH-1];
    wire frame_start=in_vsync && !vs_d;
    wire inside_roi=(pixel_x>=ROI_X_MIN) && (pixel_x<=ROI_X_MAX) &&
                    (pixel_y>=ROI_Y_MIN) && (pixel_y<=ROI_Y_MAX);
    wire edge_bit=edge_valid && (edge_data==8'hff) && inside_roi;
    wire [GXW-1:0] cur_gx=pixel_x/BLOCK;
    wire [GYW-1:0] cur_gy=pixel_y/BLOCK;
    wire [MAP_AW-1:0] cur_map_addr=cur_gy*GRID_WIDTH+cur_gx;
     
     
    wire column_last=((pixel_x%BLOCK)==BLOCK-1 || pixel_x==IMAGE_WIDTH-1);
    wire row_first=((pixel_y%BLOCK)==0);
    wire row_last=((pixel_y%BLOCK)==BLOCK-1 || pixel_y==IMAGE_HEIGHT-1);
    wire block_value=block_or || edge_bit;
    wire pooled_value=block_value || (!row_first && column_or[cur_gx]);

    reg [MAP_AW-1:0] scan_addr;
    reg [GXW-1:0] scan_x,min_x,max_x;
    reg [GYW-1:0] scan_y,min_y,max_y;
    reg [11:0] edge_cells,boundary_hits;
    reg [7:0] top_hits,bottom_hits,left_hits,right_hits;
    reg [7:0] corner_hits;
    reg [3:0] corner_seen,corner_supported;
    wire [GXW:0] bbox_w={1'b0,max_x}-{1'b0,min_x}+1'b1;
    wire [GYW:0] bbox_h={1'b0,max_y}-{1'b0,min_y}+1'b1;
    wire [GXW+GYW+2:0] perimeter=(bbox_w<<1)+(bbox_h<<1)-4;
    wire squareish=(bbox_w<<2 <= bbox_h*5) && (bbox_h<<2 <= bbox_w*5);
    wire boundary_good=((boundary_hits<<2) >= perimeter*3);
    wire enough_edges=(edge_cells>=12'd4) && (bbox_w>=3) && (bbox_h>=3);
     
     
     
     
     
     
    wire near_left=(scan_x>=min_x) && ((scan_x-min_x)*8<=bbox_w);
    wire near_right=(scan_x<=max_x) && ((max_x-scan_x)*8<=bbox_w);
    wire near_top=(scan_y>=min_y) && ((scan_y-min_y)*8<=bbox_h);
    wire near_bottom=(scan_y<=max_y) && ((max_y-scan_y)*8<=bbox_h);
     
    wire corner_left=(scan_x>=min_x) && ((scan_x-min_x)<=1 || (scan_x-min_x)*10<=bbox_w);
    wire corner_right=(scan_x<=max_x) && ((max_x-scan_x)<=1 || (max_x-scan_x)*10<=bbox_w);
    wire corner_top=(scan_y>=min_y) && ((scan_y-min_y)<=1 || (scan_y-min_y)*10<=bbox_h);
    wire corner_bottom=(scan_y<=max_y) && ((max_y-scan_y)<=1 || (max_y-scan_y)*10<=bbox_h);
     
     
    wire [2:0] corner_count={2'b0,corner_supported[0]}+{2'b0,corner_supported[1]}+
                            {2'b0,corner_supported[2]}+{2'b0,corner_supported[3]};
    wire rectangle_like=enough_edges && (corner_count>=3) &&
                         ((boundary_good) ||
                          (corner_count==4 && boundary_hits*2>=perimeter));
    wire classify_rect=rectangle_like;
    wire classify_circle=enough_edges && squareish && (corner_count<=1) && !rectangle_like;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=IDLE;result_valid<=0;result_shape<=0;result_confidence<=0;
            result_x_min<=0;result_x_max<=0;result_y_min<=0;result_y_max<=0;
            result_edge_cells<=0;analysis_done<=0;
            pixel_x<=0;pixel_y<=0;href_d<=0;vs_d<=0;block_or<=0;
            map_addr<=0;map_wa<=0;map_data<=0;map_we<=0;
            scan_addr<=0;scan_x<=0;scan_y<=0;min_x<=0;max_x<=0;min_y<=0;max_y<=0;
            edge_cells<=0;boundary_hits<=0;corner_hits<=0;corner_seen<=0;corner_supported<=0;
            top_hits<=0;bottom_hits<=0;left_hits<=0;right_hits<=0;
        end else begin
            result_valid<=0;analysis_done<=0;map_we<=0;
            href_d<=in_href;vs_d<=in_vsync;

             
             
            if(state==IDLE && frame_start) state<=CAPTURE;

            if(!in_vsync) begin
                pixel_x<=0;pixel_y<=0;block_or<=0;
                if(state==IDLE) begin end
            end else if(in_href) begin
                if(state==CAPTURE) begin
                    if(column_last) begin
                        column_or[cur_gx]<=pooled_value;
                        if(row_last) begin
                            map_we<=1;map_wa<=cur_map_addr;map_data<=pooled_value;
                        end
                        block_or<=0;
                    end else if((pixel_x%BLOCK)==0) block_or<=edge_bit;
                    else block_or<=block_value;
                    if(pixel_x==IMAGE_WIDTH-1) pixel_x<=0;
                    else pixel_x<=pixel_x+1'b1;
                    if(pixel_x==IMAGE_WIDTH-1 && pixel_y==IMAGE_HEIGHT-1) begin
                         
                         
                        state<=AN_READ;scan_addr<=0;scan_x<=0;scan_y<=0;
                        min_x<=GRID_WIDTH-1;max_x<=0;min_y<=GRID_HEIGHT-1;max_y<=0;
                        edge_cells<=0;
                    end
                end
            end else if(href_d && state==CAPTURE) begin
                pixel_x<=0;
                if(pixel_y==IMAGE_HEIGHT-1) pixel_y<=0;
                else pixel_y<=pixel_y+1'b1;
                block_or<=0;
            end

            case(state)
                AN_READ: begin map_addr<=scan_addr;state<=AN_WAIT;end
                AN_WAIT: state<=AN_USE;
                AN_USE: begin
                    if(map_q) begin
                        if(scan_x<min_x)min_x<=scan_x;
                        if(scan_x>max_x)max_x<=scan_x;
                        if(scan_y<min_y)min_y<=scan_y;
                        if(scan_y>max_y)max_y<=scan_y;
                        edge_cells<=edge_cells+1'b1;
                    end
                    if(scan_addr==MAP_N-1) begin
                        scan_addr<=0;scan_x<=0;scan_y<=0;
                        boundary_hits<=0;corner_hits<=0;corner_seen<=0;corner_supported<=0;
                        top_hits<=0;bottom_hits<=0;left_hits<=0;right_hits<=0;
                        state<=BD_READ;
                    end else begin
                        scan_addr<=scan_addr+1'b1;
                        if(scan_x==GRID_WIDTH-1)begin scan_x<=0;scan_y<=scan_y+1'b1;end
                        else scan_x<=scan_x+1'b1;
                        state<=AN_READ;
                    end
                end
                BD_READ: begin map_addr<=scan_addr;state<=BD_WAIT;end
                BD_WAIT: state<=BD_USE;
                BD_USE: begin
                    if(map_q && (near_left||near_right||near_top||near_bottom)) begin
                        boundary_hits<=boundary_hits+1'b1;
                        if(scan_y==min_y) top_hits<=top_hits+1'b1;
                        if(scan_y==max_y) bottom_hits<=bottom_hits+1'b1;
                        if(scan_x==min_x) left_hits<=left_hits+1'b1;
                        if(scan_x==max_x) right_hits<=right_hits+1'b1;
                        if((corner_left||corner_right) && (corner_top||corner_bottom))
                            corner_hits<=corner_hits+1'b1;
                        if(corner_left && corner_top) begin corner_seen[0]<=1;corner_supported[0]<=corner_seen[0];end
                        if(corner_right && corner_top) begin corner_seen[1]<=1;corner_supported[1]<=corner_seen[1];end
                        if(corner_left && corner_bottom) begin corner_seen[2]<=1;corner_supported[2]<=corner_seen[2];end
                        if(corner_right && corner_bottom) begin corner_seen[3]<=1;corner_supported[3]<=corner_seen[3];end
                    end
                    if(scan_addr==MAP_N-1) state<=EMIT;
                    else begin
                        scan_addr<=scan_addr+1'b1;
                        if(scan_x==GRID_WIDTH-1)begin scan_x<=0;scan_y<=scan_y+1'b1;end
                        else scan_x<=scan_x+1'b1;
                        state<=BD_READ;
                    end
                end
                EMIT: begin
                    result_valid<=1;
                    result_shape<=classify_rect?SHAPE_RECT:(classify_circle?SHAPE_CIRCLE:3'd0);
                    result_confidence<=(classify_circle||classify_rect)?8'd180:8'd0;
                    result_edge_cells<=edge_cells;
                    if(edge_cells==0) begin
                        result_x_min<=0;result_x_max<=0;result_y_min<=0;result_y_max<=0;
                    end else begin
                        result_x_min<=min_x*BLOCK;
                        result_x_max<=((max_x+1'b1)*BLOCK>IMAGE_WIDTH)?IMAGE_WIDTH-1:(max_x+1'b1)*BLOCK-1;
                        result_y_min<=min_y*BLOCK;
                        result_y_max<=((max_y+1'b1)*BLOCK>IMAGE_HEIGHT)?IMAGE_HEIGHT-1:(max_y+1'b1)*BLOCK-1;
                    end
                    state<=DONE;
                end
                DONE: begin analysis_done<=1;state<=IDLE;end
                default: begin end
            endcase
        end
    end
endmodule
