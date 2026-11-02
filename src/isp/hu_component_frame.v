 
 
 
 
 
 
 
 
 
 
module hu_component_frame #(
    parameter integer WIDTH=160,
    parameter integer HEIGHT=110,
    parameter integer MIN_AREA=64,
    parameter integer FRAME_ID_WIDTH=16
) (
    input clk, input rst_n,
    input frame_start, input pixel_valid, input foreground, input frame_end,
    input [FRAME_ID_WIDTH-1:0] frame_id,
    output capture_ready, output busy,
    output reg done, output reg target_valid, output reg input_error,
    output reg [FRAME_ID_WIDTH-1:0] result_frame_id,
    output reg [47:0] m00,m10,m01,m20,m11,m02,
    output reg [7:0] bbox_x_min,bbox_x_max,bbox_y_min,bbox_y_max,
    output reg [31:0] processing_cycles,
    output reg [31:0] component_count
);
    localparam N=WIDTH*HEIGHT;
    localparam AW=$clog2(N);
    localparam CW=$clog2(N+1);
    localparam IDLE=0, LOAD=1, EXT_REQ=2, EXT_WAIT=3,
               POP_REQ=4, POP_WAIT=5, NEIGH_REQ=6, NEIGH_WAIT=7,
               SCAN_REQ=8, SCAN_WAIT=9, COMPONENT_DONE=10, FINISH=11;
    reg [3:0] state;
     
    reg [1:0] mask [0:N-1];
    reg [15:0] queue [0:N-1];
    reg [1:0] mask_q;
    reg [15:0] queue_q;
    reg mask_rd, mask_wr, queue_rd, queue_wr;
    reg [AW-1:0] mask_addr, queue_addr;
    reg [1:0] mask_d;
    reg [15:0] queue_d;
    reg [CW-1:0] load_count, head, tail;
    reg [AW-1:0] scan_addr;
    reg [7:0] scan_x,scan_y,current_x,current_y;
    reg exterior;
    reg [2:0] direction;
    reg [7:0] neighbor_x,neighbor_y;
    reg neighbor_inside;
    reg [47:0] area,sx,sy,sxx,sxy,syy;
    reg [7:0] x_min,x_max,y_min,y_max;
    reg touches_border;
    reg [31:0] cycles;
    wire [31:0] neighbor_linear_addr=neighbor_y*WIDTH+neighbor_x;
    wire scan_last=(scan_addr==N-1);
    wire scan_border=(scan_x==0 || scan_x==WIDTH-1 || scan_y==0 || scan_y==HEIGHT-1);
    wire current_border=(queue_q[7:0]==0 || queue_q[7:0]==WIDTH-1 ||
                         queue_q[15:8]==0 || queue_q[15:8]==HEIGHT-1);
    wire [15:0] pop_x2=queue_q[7:0]*queue_q[7:0];
    wire [15:0] pop_y2=queue_q[15:8]*queue_q[15:8];
    wire [15:0] pop_xy=queue_q[7:0]*queue_q[15:8];
    assign capture_ready=(state==IDLE || state==LOAD);
    assign busy=(state!=IDLE && state!=LOAD);
    always @(posedge clk) begin
        if(mask_wr) mask[mask_addr]<=mask_d;
        if(mask_rd) mask_q<=mask[mask_addr];
        if(queue_wr) queue[queue_addr]<=queue_d;
        if(queue_rd) queue_q<=queue[queue_addr];
    end
    always @* begin
        neighbor_x=current_x; neighbor_y=current_y; neighbor_inside=1;
        case(direction)
            0: begin neighbor_inside=current_x+1<WIDTH; neighbor_x=current_x+1'b1; end
            1: begin neighbor_inside=current_y+1<HEIGHT; neighbor_y=current_y+1'b1; end
            2: begin neighbor_inside=current_x>0; neighbor_x=current_x-1'b1; end
            3: begin neighbor_inside=current_y>0; neighbor_y=current_y-1'b1; end
            4: begin neighbor_inside=(current_x+1<WIDTH && current_y+1<HEIGHT);
                     neighbor_x=current_x+1'b1; neighbor_y=current_y+1'b1; end
            5: begin neighbor_inside=(current_x>0 && current_y+1<HEIGHT);
                     neighbor_x=current_x-1'b1; neighbor_y=current_y+1'b1; end
            6: begin neighbor_inside=(current_x>0 && current_y>0);
                     neighbor_x=current_x-1'b1; neighbor_y=current_y-1'b1; end
            7: begin neighbor_inside=(current_x+1<WIDTH && current_y>0);
                     neighbor_x=current_x+1'b1; neighbor_y=current_y-1'b1; end
        endcase
        mask_rd=0; mask_wr=0; mask_addr=0; mask_d=0;
        queue_rd=0; queue_wr=0; queue_addr=0; queue_d=0;
        case(state)
            LOAD: if(pixel_valid && load_count<N) begin
                mask_wr=1; mask_addr=load_count[AW-1:0]; mask_d={1'b0,foreground};
            end
            EXT_REQ,SCAN_REQ: begin mask_rd=1; mask_addr=scan_addr; end
            EXT_WAIT: if(scan_border && mask_q==0 && tail<N) begin
                mask_wr=1; mask_addr=scan_addr; mask_d=2'b10;
                queue_wr=1; queue_addr=tail[AW-1:0]; queue_d={scan_y,scan_x};
            end
            SCAN_WAIT: if(!mask_q[1]) begin
                mask_wr=1; mask_addr=scan_addr; mask_d=2'b11;
                queue_wr=1; queue_addr=0; queue_d={scan_y,scan_x};
            end
            POP_REQ: if(head<tail) begin queue_rd=1; queue_addr=head[AW-1:0]; end
            NEIGH_REQ: if(neighbor_inside) begin
                mask_rd=1; mask_addr=neighbor_linear_addr[AW-1:0];
            end
            NEIGH_WAIT: if(neighbor_inside && tail<N &&
                ((exterior && mask_q==0) || (!exterior && !mask_q[1]))) begin
                mask_wr=1; mask_addr=neighbor_linear_addr[AW-1:0];
                mask_d=exterior?2'b10:2'b11;
                queue_wr=1; queue_addr=tail[AW-1:0]; queue_d={neighbor_y,neighbor_x};
            end
        endcase
    end
    task next_scan;
        begin
            scan_addr<=scan_addr+1'b1;
            if(scan_x==WIDTH-1) begin scan_x<=0; scan_y<=scan_y+1'b1; end
            else scan_x<=scan_x+1'b1;
        end
    endtask
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=IDLE; load_count<=0; head<=0; tail<=0; scan_addr<=0;
            scan_x<=0; scan_y<=0; current_x<=0; current_y<=0; direction<=0;
            exterior<=0; area<=0; sx<=0; sy<=0; sxx<=0; sxy<=0; syy<=0;
            x_min<=255; x_max<=0; y_min<=255; y_max<=0; touches_border<=0;
            done<=0; target_valid<=0; input_error<=0; result_frame_id<=0;
            m00<=0; m10<=0; m01<=0; m20<=0; m11<=0; m02<=0;
            bbox_x_min<=0; bbox_x_max<=0; bbox_y_min<=0; bbox_y_max<=0;
            processing_cycles<=0; cycles<=0; component_count<=0;
        end else begin
            done<=0;
            if(busy) cycles<=cycles+1'b1;
            if(frame_start && state!=IDLE) input_error<=1;
            case(state)
                IDLE: if(frame_start) begin
                    state<=LOAD; load_count<=0; target_valid<=0; input_error<=0;
                    result_frame_id<=frame_id; component_count<=0;
                    m00<=0; m10<=0; m01<=0; m20<=0; m11<=0; m02<=0;
                    bbox_x_min<=0; bbox_x_max<=0; bbox_y_min<=0; bbox_y_max<=0;
                end
                LOAD: begin
                    if(pixel_valid) begin
                        if(load_count<N) load_count<=load_count+1'b1;
                        else input_error<=1;
                    end
                    if(frame_end) begin
                        cycles<=0;
                        if((load_count+(pixel_valid?1:0))!=N || input_error) begin
                            input_error<=1; state<=FINISH;
                        end else begin
                            head<=0; tail<=0; scan_addr<=0; scan_x<=0; scan_y<=0;
                            exterior<=1; state<=EXT_REQ;
                        end
                    end
                end
                EXT_REQ: state<=EXT_WAIT;
                EXT_WAIT: begin
                    if(scan_border && mask_q==0) tail<=tail+1'b1;
                    if(scan_last) state<=POP_REQ;
                    else begin next_scan(); state<=EXT_REQ; end
                end
                SCAN_REQ: state<=SCAN_WAIT;
                SCAN_WAIT: begin
                    if(!mask_q[1]) begin
                        head<=0; tail<=1; area<=0; sx<=0; sy<=0; sxx<=0; sxy<=0; syy<=0;
                        x_min<=255; x_max<=0; y_min<=255; y_max<=0;
                        touches_border<=0; exterior<=0; state<=POP_REQ;
                        component_count<=component_count+1'b1;
                    end else if(scan_last) state<=FINISH;
                    else begin next_scan(); state<=SCAN_REQ; end
                end
                POP_REQ: begin
                    if(head<tail) state<=POP_WAIT;
                    else if(exterior) begin
                        scan_addr<=0; scan_x<=0; scan_y<=0; state<=SCAN_REQ;
                    end else state<=COMPONENT_DONE;
                end
                POP_WAIT: begin
                    current_x<=queue_q[7:0]; current_y<=queue_q[15:8];
                    head<=head+1'b1; direction<=0; state<=NEIGH_REQ;
                    if(!exterior) begin
                        area<=area+1'b1; sx<=sx+queue_q[7:0]; sy<=sy+queue_q[15:8];
                        sxx<=sxx+pop_x2; sxy<=sxy+pop_xy; syy<=syy+pop_y2;
                        if(queue_q[7:0]<x_min) x_min<=queue_q[7:0];
                        if(queue_q[7:0]>x_max) x_max<=queue_q[7:0];
                        if(queue_q[15:8]<y_min) y_min<=queue_q[15:8];
                        if(queue_q[15:8]>y_max) y_max<=queue_q[15:8];
                        if(current_border) touches_border<=1;
                    end
                end
                NEIGH_REQ: state<=NEIGH_WAIT;
                NEIGH_WAIT: begin
                    if(neighbor_inside &&
                       ((exterior && mask_q==0) || (!exterior && !mask_q[1]))) begin
                        if(tail<N) tail<=tail+1'b1;
                        else input_error<=1;
                    end
                    if(direction==(exterior?3:7)) state<=POP_REQ;
                    else begin direction<=direction+1'b1; state<=NEIGH_REQ; end
                    if(neighbor_inside && tail>=N &&
                       ((exterior && mask_q==0) || (!exterior && !mask_q[1]))) begin
                        input_error<=1; state<=FINISH;
                    end
                end
                COMPONENT_DONE: begin
                    if(!touches_border && area>=MIN_AREA && area>m00) begin
                        target_valid<=1; m00<=area; m10<=sx; m01<=sy;
                        m20<=sxx; m11<=sxy; m02<=syy;
                        bbox_x_min<=x_min; bbox_x_max<=x_max;
                        bbox_y_min<=y_min; bbox_y_max<=y_max;
                    end
                    if(scan_last) state<=FINISH;
                    else begin next_scan(); state<=SCAN_REQ; end
                end
                FINISH: begin
                    done<=1; processing_cycles<=cycles; state<=IDLE;
                    if(input_error) target_valid<=0;
                end
            endcase
        end
    end
endmodule
