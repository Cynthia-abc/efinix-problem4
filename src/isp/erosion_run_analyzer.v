 
 
 
 
 
 
module erosion_run_analyzer #(
    parameter W=480, H=270, LB=12, MIN_EDGES=64,
    parameter MAX_WALK=65536,
    parameter AW=$clog2(W*H), XW=$clog2(W), YW=$clog2(H)
) (
    input clk, rst_n,
    input grid_valid, input [4:0] grid_weight,
    input [XW-1:0] grid_x, input [YW-1:0] grid_y,
    output reg feature_valid, output reg [1:0] feature_index,
    output reg [31:0] feature_edges,
    output reg [XW-1:0] feature_x0,feature_x1,
    output reg [YW-1:0] feature_y0,feature_y1,
    output reg [15:0] feature_aspect,
    output reg [31:0] feature_steps,
     
    output reg [1:0] feature_walk_status,
    output reg analysis_done, output reg analysis_error,
    output busy,
    output reg [31:0] processing_cycles
);
    localparam N=W*H, NL=(1<<LB), SW=21+2*XW+2*YW;
    localparam IDLE=0,CAPTURE=1,INIT=2,READ=3,WAIT_READ=4,CELL=5,
      PREV=6,WAIT_PREV=7,USE_PREV=8,FIND=9,WAIT_FIND=10,USE_FIND=11,
      UNION=12,ALLOC=13,STAT_READ=14,STAT_WAIT=15,STAT_USE=16,FILL=17,
      ADVANCE=18,AGG_READ=19,AGG_WAIT=20,AGG_USE=21,
      MERGE_READ=22,MERGE_WAIT=23,MERGE_USE=24,
      TOP_READ=25,TOP_WAIT=26,TOP_USE=27,
      MASK_START=28,WALK_INIT=29,WALK_SCAN=30,WALK_SCAN_WAIT=31,
      WALK_SCAN_USE=32,WALK_REQ=33,WALK_WAIT=34,WALK_USE=35,
      DIV_INIT=36,DIV_STEP=37,EMIT=38,DONE=39,FAILED=40;
    reg [5:0] state;
    assign busy=state!=IDLE;
    reg [31:0] cycle_count;

    reg [4:0] snap[0:N-1];
    reg [AW-1:0] snap_addr;
    reg [4:0] snap_q;
    wire capture_first=grid_valid && grid_x==0 && grid_y==0;
    wire snap_we=grid_valid && ((state==IDLE && capture_first) || state==CAPTURE);
    wire [AW-1:0] snap_wa=grid_y*W+grid_x;
    always @(posedge clk) begin
        if(snap_we) snap[snap_wa]<=grid_weight;
        snap_q<=snap[snap_addr];
    end

    reg [LB-1:0] parent[0:NL-1];
    reg [LB-1:0] parent_addr,parent_data,parent_q;
    reg parent_we;
    always @(posedge clk) begin
        if(parent_we) parent[parent_addr]<=parent_data;
        parent_q<=parent[parent_addr];
    end
     
    reg [SW-1:0] stats[0:NL-1];
    reg [LB-1:0] stats_addr;
    reg [SW-1:0] stats_data,stats_q;
    reg stats_we;
    always @(posedge clk) begin
        if(stats_we) stats[stats_addr]<=stats_data;
        stats_q<=stats[stats_addr];
    end
    wire [20:0] sq_count=stats_q[SW-1 -:21];
    wire [XW-1:0] sq_x0=stats_q[2*XW+2*YW-1 -:XW];
    wire [XW-1:0] sq_x1=stats_q[XW+2*YW-1 -:XW];
    wire [YW-1:0] sq_y0=stats_q[2*YW-1 -:YW],sq_y1=stats_q[YW-1:0];
    reg [SW-1:0] saved_stats;
    wire [20:0] sv_count=saved_stats[SW-1 -:21];
    wire [XW-1:0] sv_x0=saved_stats[2*XW+2*YW-1 -:XW];
    wire [XW-1:0] sv_x1=saved_stats[XW+2*YW-1 -:XW];
    wire [YW-1:0] sv_y0=saved_stats[2*YW-1 -:YW],sv_y1=saved_stats[YW-1:0];

    reg [LB-1:0] lines[0:2*W-1];
    reg [$clog2(2*W)-1:0] line_addr,line_wa;
    reg [LB-1:0] line_q,line_data;
    reg line_we;
    always @(posedge clk) begin
        if(line_we) lines[line_wa]<=line_data;
        line_q<=lines[line_addr];
    end

     
     
    reg [1:0] selected_map[0:N-1];
    reg [AW-1:0] map_addr,map_wa;
    reg [1:0] map_q,map_data;
    reg map_we;
    always @(posedge clk) begin
        if(map_we) selected_map[map_wa]<=map_data;
        map_q<=selected_map[map_addr];
    end

    reg [LB:0] next_label;
    reg [LB-1:0] init_idx, scan_label;
    reg pass, line_bank;
    reg [XW-1:0] x,run_x0,run_x1,prev_x,prev_end,fill_x;
    reg [YW-1:0] y;
    reg [AW-1:0] raster_addr,row_addr;
    reg run_active;
    reg [20:0] run_weight;
    reg [LB-1:0] run_base,other_label,root_a,find_label;
    reg [1:0] find_mode;
    reg [LB:0] find_depth;
    reg [1:0] run_id;

    reg [20:0] top_count[0:2];
    reg [LB-1:0] top_label[0:2];
    reg [XW-1:0] top_x0[0:2],top_x1[0:2];
    reg [YW-1:0] top_y0[0:2],top_y1[0:2];
    integer t,j;
    reg [1:0] insert_slot;
    reg insert_found;
    always @* begin
        insert_found=0;insert_slot=0;
        for(t=0;t<3;t=t+1) if(!insert_found && sq_count>top_count[t]) begin
            insert_slot=t;insert_found=1;
        end
    end

    reg [1:0] target;
    reg [XW-1:0] wx,start_x,first_x,back_x,read_x;
    reg [YW-1:0] wy,start_y,first_y,back_y,read_y;
    reg first_set;
    reg [2:0] search_dir,search_offset;
    reg [31:0] walk_steps;
    reg [1:0] walk_status;
    reg signed [XW:0] nx;
    reg signed [YW:0] ny;
    reg request_inside;
    reg [2:0] preceding_dir;
    function signed [1:0] dx;
        input [2:0] d;
        begin case(d) 0,1,7:dx=1;3,4,5:dx=-1;default:dx=0;endcase end
    endfunction
    function signed [1:0] dy;
        input [2:0] d;
        begin case(d) 1,2,3:dy=1;5,6,7:dy=-1;default:dy=0;endcase end
    endfunction
    function [2:0] direction;
        input [XW-1:0] ax,bx;
        input [YW-1:0] ay,by;
        begin
            if(by==ay) direction=(bx>ax)?0:4;
            else if(by>ay) direction=(bx==ax)?2:((bx>ax)?1:3);
            else direction=(bx==ax)?6:((bx>ax)?7:5);
        end
    endfunction
     
    reg [19:0] dividend,quotient;
    reg [XW:0] divisor;
    reg [XW+1:0] remainder;
    wire [XW+1:0] trial={remainder[XW:0],dividend[19]};
    reg [4:0] div_left;
    reg [XW:0] bw,bh,max_dim,min_dim;
    always @* begin
        bw={1'b0,top_x1[target]}-{1'b0,top_x0[target]}+1'b1;
        bh={1'b0,top_y1[target]}-{1'b0,top_y0[target]}+1'b1;
        max_dim=(bw>=bh)?bw:bh;min_dim=(bw>=bh)?bh:bw;
        nx=$signed({1'b0,wx})+dx(search_dir);
        ny=$signed({1'b0,wy})+dy(search_dir);
        preceding_dir=search_dir-1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=IDLE;feature_valid<=0;feature_index<=0;feature_edges<=0;
            feature_x0<=0;feature_x1<=0;feature_y0<=0;feature_y1<=0;
            feature_aspect<=0;feature_steps<=0;feature_walk_status<=0;
            analysis_done<=0;analysis_error<=0;processing_cycles<=0;
            parent_we<=0;stats_we<=0;line_we<=0;map_we<=0;
            parent_addr<=0;parent_data<=0;stats_addr<=0;stats_data<=0;
            line_addr<=0;line_wa<=0;line_data<=0;map_addr<=0;map_wa<=0;map_data<=0;
            snap_addr<=0;cycle_count<=0;pass<=0;line_bank<=0;
            next_label<=1;init_idx<=0;scan_label<=0;x<=0;y<=0;
            raster_addr<=0;row_addr<=0;run_active<=0;run_weight<=0;
            run_base<=0;run_x0<=0;run_x1<=0;prev_x<=0;prev_end<=0;fill_x<=0;
            other_label<=0;root_a<=0;find_label<=0;find_mode<=0;find_depth<=0;
            run_id<=0;target<=0;wx<=0;wy<=0;start_x<=0;start_y<=0;
            first_x<=0;first_y<=0;back_x<=0;back_y<=0;read_x<=0;read_y<=0;
            first_set<=0;search_dir<=0;search_offset<=0;request_inside<=0;
            walk_steps<=0;walk_status<=0;dividend<=0;quotient<=0;
            divisor<=0;remainder<=0;div_left<=0;saved_stats<=0;
            for(j=0;j<3;j=j+1) begin
                top_count[j]<=0;top_label[j]<=0;top_x0[j]<=0;top_x1[j]<=0;
                top_y0[j]<=0;top_y1[j]<=0;
            end
        end else begin
            feature_valid<=0;analysis_done<=0;
            parent_we<=0;stats_we<=0;line_we<=0;map_we<=0;
            if(state!=IDLE && state!=CAPTURE) cycle_count<=cycle_count+1'b1;
            case(state)
            IDLE: if(capture_first) begin
                analysis_error<=0;state<=CAPTURE;
                for(j=0;j<3;j=j+1) top_count[j]<=0;
            end
            CAPTURE: if(grid_valid && grid_x==W-1 && grid_y==H-1) begin
                init_idx<=0;cycle_count<=0;state<=INIT;
            end
            INIT: begin
                parent_addr<=init_idx;parent_data<=init_idx;parent_we<=1;
                stats_addr<=init_idx;stats_data<=0;stats_we<=1;
                if(init_idx==NL-1) begin
                    pass<=0;line_bank<=0;next_label<=1;x<=0;y<=0;
                    raster_addr<=0;row_addr<=0;run_active<=0;state<=READ;
                end else init_idx<=init_idx+1'b1;
            end
            READ: begin snap_addr<=raster_addr;state<=WAIT_READ;end
            WAIT_READ: state<=CELL;
            CELL: begin
                if(snap_q!=0) begin
                    if(!run_active) begin run_x0<=x;run_weight<=snap_q;end
                    else run_weight<=run_weight+snap_q;
                    run_x1<=x;run_active<=1;
                    if(x==W-1) begin state<=ALLOC;run_base<=0;end
                    else state<=ADVANCE;
                end else begin
                    line_we<=1;line_wa<=line_bank*W+x;line_data<=0;
                    if(pass) begin map_we<=1;map_wa<=raster_addr;map_data<=0;end
                    if(run_active) begin state<=ALLOC;run_base<=0;end
                    else state<=ADVANCE;
                end
            end
            ALLOC: begin
                prev_x<=(run_x0==0)?0:run_x0-1'b1;
                prev_end<=(run_x1==W-1)?W-1:run_x1+1'b1;
                run_base<=0;
                if(y==0) begin state<=STAT_READ;end
                else state<=PREV;
            end
            PREV: begin line_addr<=(~line_bank & 1'b1)*W+prev_x;state<=WAIT_PREV;end
            WAIT_PREV: state<=USE_PREV;
            USE_PREV: begin
                if(line_q!=0 && run_base==0) run_base<=line_q;
                if(!pass && line_q!=0 && run_base!=0 && line_q!=run_base) begin
                    other_label<=line_q;find_label<=run_base;find_mode<=0;
                    find_depth<=0;state<=FIND;
                end else if(prev_x==prev_end) state<=STAT_READ;
                else begin prev_x<=prev_x+1'b1;state<=PREV;end
            end
            FIND: begin parent_addr<=find_label;state<=WAIT_FIND;end
            WAIT_FIND: state<=USE_FIND;
            USE_FIND: begin
                if(parent_q!=find_label) begin
                    find_label<=parent_q;find_depth<=find_depth+1'b1;state<=FIND;
                    if(find_depth>=NL-1) state<=FAILED;
                end else if(find_mode==0) begin
                    root_a<=find_label;find_label<=other_label;find_mode<=1;
                    find_depth<=0;state<=FIND;
                end else if(find_mode==1) state<=UNION;
                else if(find_mode==2) begin
                     
                     
                    if(find_label==scan_label) begin
                        if(scan_label==next_label-1) begin scan_label<=1;state<=TOP_READ;end
                        else begin scan_label<=scan_label+1'b1;state<=AGG_READ;end
                    end else begin stats_addr<=find_label;state<=MERGE_WAIT;end
                end else begin
                    run_id<=0;
                    for(j=0;j<3;j=j+1)
                        if(top_count[j]!=0 && top_label[j]==find_label) run_id<=j+1;
                    fill_x<=run_x0;state<=FILL;
                end
            end
            UNION: begin
                if(root_a!=find_label) begin
                    parent_we<=1;
                    parent_addr<=(root_a>find_label)?root_a:find_label;
                    parent_data<=(root_a>find_label)?find_label:root_a;
                end
                if(prev_x==prev_end) state<=STAT_READ;
                else begin prev_x<=prev_x+1'b1;state<=PREV;end
            end
            STAT_READ: begin
                if(run_base==0) begin
                    if(next_label==NL) state<=FAILED;
                    else begin run_base<=next_label[LB-1:0];next_label<=next_label+1'b1;end
                end
                state<=STAT_WAIT;
                if(run_base==0 && next_label==NL) state<=FAILED;
            end
            STAT_WAIT: begin
                if(pass) begin find_label<=run_base;find_mode<=3;find_depth<=0;state<=FIND;end
                else begin stats_addr<=run_base;state<=STAT_USE;end
            end
            STAT_USE: state<=FILL;
            FILL: begin
                 
                if(!pass && run_active) begin
                    stats_we<=1;stats_data<={sq_count+run_weight,
                        (sq_count==0 || run_x0<sq_x0)?run_x0:sq_x0,
                        (sq_count==0 || run_x1>sq_x1)?run_x1:sq_x1,
                        (sq_count==0 || y<sq_y0)?y:sq_y0,
                        (sq_count==0 || y>sq_y1)?y:sq_y1};
                    fill_x<=run_x0;run_active<=0;
                end else begin
                    line_we<=1;line_wa<=line_bank*W+fill_x;line_data<=run_base;
                    if(pass) begin map_we<=1;map_wa<=row_addr+fill_x;map_data<=run_id;end
                    if(fill_x==run_x1) begin run_active<=0;state<=ADVANCE;end
                    else fill_x<=fill_x+1'b1;
                end
            end
            ADVANCE: begin
                if(x==W-1) begin
                    x<=0;y<=y+1'b1;line_bank<=~line_bank;row_addr<=row_addr+W;
                    if(y==H-1) begin
                        if(pass) begin target<=0;state<=WALK_INIT;end
                        else if(next_label==1) state<=DONE;
                        else begin scan_label<=1;state<=AGG_READ;end
                    end else begin raster_addr<=raster_addr+1'b1;state<=READ;end
                end else begin x<=x+1'b1;raster_addr<=raster_addr+1'b1;state<=READ;end
            end
            AGG_READ: begin stats_addr<=scan_label;state<=AGG_WAIT;end
            AGG_WAIT: state<=AGG_USE;
            AGG_USE: begin saved_stats<=stats_q;find_label<=scan_label;find_mode<=2;find_depth<=0;state<=FIND;end
            MERGE_WAIT: state<=MERGE_USE;
            MERGE_USE: begin
                stats_we<=1;stats_data<={sq_count+sv_count,
                    (sq_count==0 || sv_x0<sq_x0)?sv_x0:sq_x0,
                    (sq_count==0 || sv_x1>sq_x1)?sv_x1:sq_x1,
                    (sq_count==0 || sv_y0<sq_y0)?sv_y0:sq_y0,
                    (sq_count==0 || sv_y1>sq_y1)?sv_y1:sq_y1};
                if(scan_label==next_label-1) begin scan_label<=1;state<=TOP_READ;end
                else begin scan_label<=scan_label+1'b1;state<=AGG_READ;end
            end
            TOP_READ: begin stats_addr<=scan_label;parent_addr<=scan_label;state<=TOP_WAIT;end
            TOP_WAIT: state<=TOP_USE;
            TOP_USE: begin
                if(parent_q==scan_label && sq_count>=MIN_EDGES && insert_found) begin
                    for(j=2;j>0;j=j-1) if(j>insert_slot) begin
                        top_count[j]<=top_count[j-1];top_label[j]<=top_label[j-1];
                        top_x0[j]<=top_x0[j-1];top_x1[j]<=top_x1[j-1];
                        top_y0[j]<=top_y0[j-1];top_y1[j]<=top_y1[j-1];
                    end
                    top_count[insert_slot]<=sq_count;top_label[insert_slot]<=scan_label;
                    top_x0[insert_slot]<=sq_x0;top_x1[insert_slot]<=sq_x1;
                    top_y0[insert_slot]<=sq_y0;top_y1[insert_slot]<=sq_y1;
                end
                if(scan_label==next_label-1) state<=MASK_START;
                else begin scan_label<=scan_label+1'b1;state<=TOP_READ;end
            end
            MASK_START: begin
                pass<=1;line_bank<=0;next_label<=1;x<=0;y<=0;raster_addr<=0;row_addr<=0;
                run_active<=0;state<=READ;
            end
            WALK_INIT: begin
                if(top_count[target]==0) state<=DONE;
                else begin
                    wx<=top_x0[target];wy<=top_y0[target];
                    walk_steps<=0;walk_status<=0;first_set<=0;state<=WALK_SCAN;
                end
            end
            WALK_SCAN: begin map_addr<=wy*W+wx;state<=WALK_SCAN_WAIT;end
            WALK_SCAN_WAIT: state<=WALK_SCAN_USE;
            WALK_SCAN_USE: begin
                if(map_q==target+1'b1) begin
                    start_x<=wx;start_y<=wy;back_x<=wx-1'b1;back_y<=wy;
                    search_dir<=5;search_offset<=0;state<=WALK_REQ;
                end else if(wx==top_x1[target]) begin
                    wx<=top_x0[target];wy<=wy+1'b1;state<=WALK_SCAN;
                    if(wy==top_y1[target]) state<=FAILED;
                end else begin wx<=wx+1'b1;state<=WALK_SCAN;end
            end
            WALK_REQ: begin
                request_inside<=(nx>=0 && nx<W && ny>=0 && ny<H);
                read_x<=nx[XW-1:0];read_y<=ny[YW-1:0];
                map_addr<=ny*W+nx;state<=WALK_WAIT;
            end
            WALK_WAIT: state<=WALK_USE;
            WALK_USE: begin
                if(request_inside && map_q==target+1'b1) begin
                    if(first_set && wx==start_x && wy==start_y && read_x==first_x && read_y==first_y) state<=DIV_INIT;
                    else if(walk_steps>=MAX_WALK) begin walk_status<=2;state<=DIV_INIT;end
                    else begin
                        if(!first_set) begin first_x<=read_x;first_y<=read_y;first_set<=1;end
                        back_x<=wx+dx(preceding_dir);back_y<=wy+dy(preceding_dir);
                        wx<=read_x;wy<=read_y;walk_steps<=walk_steps+1'b1;
                         
                         
                        search_dir<={search_dir[2:1],1'b0}+3'd7;
                        search_offset<=0;state<=WALK_REQ;
                    end
                end else if(search_offset==7) begin walk_status<=1;state<=DIV_INIT;end
                else begin search_dir<=search_dir+1'b1;search_offset<=search_offset+1'b1;state<=WALK_REQ;end
            end
            DIV_INIT: begin
                dividend<=max_dim*20'd1000;divisor<=min_dim;
                remainder<=0;quotient<=0;div_left<=20;state<=DIV_STEP;
            end
            DIV_STEP: begin
                dividend<=dividend<<1;
                if(trial>={1'b0,divisor}) begin remainder<=trial-divisor;quotient<={quotient[18:0],1'b1};end
                else begin remainder<=trial;quotient<={quotient[18:0],1'b0};end
                div_left<=div_left-1'b1;
                if(div_left==1) state<=EMIT;
            end
            EMIT: begin
                feature_valid<=1;feature_index<=target;feature_edges<=top_count[target];
                feature_x0<=top_x0[target];feature_x1<=top_x1[target];
                feature_y0<=top_y0[target];feature_y1<=top_y1[target];
                feature_aspect<=(quotient>65535)?16'hffff:quotient[15:0];
                feature_steps<=walk_steps;feature_walk_status<=walk_status;
                if(target==2) state<=DONE;
                else begin target<=target+1'b1;state<=WALK_INIT;end
            end
            DONE: begin analysis_done<=1;processing_cycles<=cycle_count;state<=IDLE;end
            FAILED: begin analysis_error<=1;analysis_done<=1;processing_cycles<=cycle_count;state<=IDLE;end
            default: state<=IDLE;
            endcase
        end
    end
endmodule
