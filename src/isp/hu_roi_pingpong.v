 
 
 
 
module hu_roi_pingpong #(
    parameter integer WIDTH=160, HEIGHT=110, MIN_AREA=64
) (
    input video_clk, input video_rst_n,
    input capture_start, input sample_valid, input sample_data, input capture_end,
    input [15:0] capture_frame_id,
    input process_clk, input process_rst_n,
    output reg result_event, output reg result_valid,
    output reg [2:0] result_shape, output reg [15:0] result_frame_id,
    output reg [7:0] result_x_min,result_x_max,result_y_min,result_y_max,
    output reg [31:0] result_cycles, output reg [31:0] result_hu_det,
    output reg [31:0] dropped_frames, output reg [31:0] malformed_frames,
    output [1:0] bank_locked, output processing_busy
);
    localparam N=WIDTH*HEIGHT, AW=$clog2(N), CW=$clog2(N+1);
    reg bank0[0:N-1], bank1[0:N-1];
    reg [1:0] publish, release_bank;
    (* async_reg="true" *) reg [1:0] release_meta,release_sync;
    (* async_reg="true" *) reg [1:0] publish_meta,publish_sync;
    reg [15:0] tag0,tag1;
    reg capturing,write_bank,prefer_bank,write_error;
    reg [CW-1:0] write_count;
    reg [15:0] write_tag;
    assign bank_locked=publish ^ release_sync;
    wire write_enable=capturing && sample_valid && write_count<N;
    always @(posedge video_clk) begin
        if(write_enable && !write_bank) bank0[write_count[AW-1:0]]<=sample_data;
        if(write_enable && write_bank) bank1[write_count[AW-1:0]]<=sample_data;
    end
    always @(posedge video_clk or negedge video_rst_n) begin
        if(!video_rst_n) begin
            release_meta<=0; release_sync<=0; publish<=0; tag0<=0; tag1<=0;
            capturing<=0; write_bank<=0; prefer_bank<=0; write_count<=0;write_error<=0;
            write_tag<=0; dropped_frames<=0; malformed_frames<=0;
        end else begin
            release_meta<=release_bank; release_sync<=release_meta;
            if(capturing && sample_valid && write_count<N) write_count<=write_count+1'b1;
            if(capturing && sample_valid && write_count>=N) write_error<=1;
            if(capture_end && capturing) begin
                capturing<=0;
                if(!write_error && write_count+(sample_valid?1:0)==N) begin
                    if(write_bank) begin tag1<=write_tag; publish[1]<=~publish[1]; end
                    else begin tag0<=write_tag; publish[0]<=~publish[0]; end
                end else malformed_frames<=malformed_frames+1'b1;
            end
            if(capture_start) begin
                 
                if(capturing) malformed_frames<=malformed_frames+1'b1;
                capturing<=0; write_count<=0; write_tag<=capture_frame_id;write_error<=0;
                if(!bank_locked[prefer_bank]) begin
                    capturing<=1; write_bank<=prefer_bank; prefer_bank<=~prefer_bank;
                end else if(!bank_locked[!prefer_bank]) begin
                    capturing<=1; write_bank<=!prefer_bank; prefer_bank<=prefer_bank;
                end else dropped_frames<=dropped_frames+1'b1;
            end
        end
    end

    localparam IDLE=0, DESCRIPTOR=1, START=2, PRIME=3, STREAM=4, WAIT_RESULT=5, SEND=6;
    reg [2:0] state;
    reg read_bank, read_token;
    reg [AW-1:0] read_addr;
    reg [CW-1:0] stream_count;
    reg ram0_q,ram1_q;
    wire ram_q=read_bank?ram1_q:ram0_q;
    reg [15:0] core_tag;
    wire ram_read=(state==PRIME || state==STREAM);
    always @(posedge process_clk) begin
        if(ram_read && !read_bank) ram0_q<=bank0[read_addr];
        if(ram_read && read_bank) ram1_q<=bank1[read_addr];
    end
    wire core_ready, core_done, core_valid, core_error;
    wire [2:0] core_shape;
    wire [15:0] core_result_tag;
    wire [7:0] bx0,bx1,by0,by1;
    wire [31:0] core_cycles,core_hd;
    reg [31:0] transaction_cycles;
    assign processing_busy=(state!=IDLE);
    hu_shape_frame #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.MIN_AREA(MIN_AREA)) u_core (
        .clk(process_clk),.rst_n(process_rst_n),.frame_start(state==START),
        .pixel_valid(state==STREAM),.foreground(ram_q),
        .frame_end(state==STREAM && stream_count==N-1),.frame_id(core_tag),
        .ready(core_ready),.busy(),.done(core_done),.target_valid(core_valid),
        .shape(core_shape),.result_frame_id(core_result_tag),
        .bbox_x_min(bx0),.bbox_x_max(bx1),.bbox_y_min(by0),.bbox_y_max(by1),
        .hu1_q24(),.hu2_q24(),.hu_det_q24(core_hd),.match_distance_q24(),
        .component_cycles(core_cycles),.component_count(),.input_error(core_error)
    );

     
     
    reg result_request;
    reg result_ack;
    (* async_reg="true" *) reg ack_meta,ack_sync;
    (* async_reg="true" *) reg result_meta,result_sync;
    reg payload_valid;
    reg [2:0] payload_shape;
    reg [15:0] payload_tag;
    reg [7:0] payload_x0,payload_x1,payload_y0,payload_y1;
    reg [31:0] payload_cycles,payload_hd;
    reg mailbox_settle;
    always @(posedge process_clk or negedge process_rst_n) begin
        if(!process_rst_n) begin
            publish_meta<=0;publish_sync<=0;release_bank<=0;
            state<=IDLE;read_bank<=0;read_token<=0;read_addr<=0;stream_count<=0;
            core_tag<=0;transaction_cycles<=0;result_request<=0;
            ack_meta<=0;ack_sync<=0;payload_valid<=0;payload_shape<=0;
            payload_tag<=0;payload_x0<=0;payload_x1<=0;payload_y0<=0;payload_y1<=0;
            payload_cycles<=0;payload_hd<=0;
        end else begin
            publish_meta<=publish;publish_sync<=publish_meta;
            ack_meta<=result_ack;ack_sync<=ack_meta;
            if(state!=IDLE) transaction_cycles<=transaction_cycles+1'b1;
            case(state)
                IDLE: if(core_ready && result_request==ack_sync &&
                             (publish_sync!=release_bank)) begin
                     
                     
                    if((publish_sync[0]!=release_bank[0]) &&
                       ((publish_sync[1]==release_bank[1]) || $signed(tag0-tag1)<0)) begin
                        read_bank<=0;read_token<=publish_sync[0];
                    end else begin read_bank<=1;read_token<=publish_sync[1]; end
                    state<=DESCRIPTOR;transaction_cycles<=0;
                end
                DESCRIPTOR: begin core_tag<=read_bank?tag1:tag0;state<=START;end
                START: begin read_addr<=0;stream_count<=0;state<=PRIME;end
                PRIME: begin read_addr<=1;state<=STREAM;end
                STREAM: begin
                     
                    if(read_addr<N-1) read_addr<=read_addr+1'b1;
                    if(stream_count==N-1) begin
                        release_bank[read_bank]<=read_token;state<=WAIT_RESULT;
                    end else stream_count<=stream_count+1'b1;
                end
                WAIT_RESULT: if(core_done) begin
                    payload_valid<=core_valid && !core_error;payload_shape<=core_shape;
                    payload_tag<=core_result_tag;payload_x0<=bx0;payload_x1<=bx1;
                    payload_y0<=by0;payload_y1<=by1;
                    payload_cycles<=transaction_cycles;payload_hd<=core_hd;
                    state<=SEND;
                end
                SEND: begin result_request<=~result_request;state<=IDLE;end
                default: state<=IDLE;
            endcase
        end
    end
    always @(posedge video_clk or negedge video_rst_n) begin
        if(!video_rst_n) begin
            result_meta<=0;result_sync<=0;result_ack<=0;mailbox_settle<=0;
            result_event<=0;result_valid<=0;result_shape<=0;result_frame_id<=0;
            result_x_min<=0;result_x_max<=0;result_y_min<=0;result_y_max<=0;
            result_cycles<=0;result_hu_det<=0;
        end else begin
            result_meta<=result_request;result_sync<=result_meta;result_event<=0;
            if(result_sync!=result_ack) begin
                if(!mailbox_settle) mailbox_settle<=1;
                else begin
                    result_event<=1;result_valid<=payload_valid;result_shape<=payload_shape;
                    result_frame_id<=payload_tag;result_x_min<=payload_x0;result_x_max<=payload_x1;
                    result_y_min<=payload_y0;result_y_max<=payload_y1;
                    result_cycles<=payload_cycles;result_hu_det<=payload_hd;
                    result_ack<=result_sync;mailbox_settle<=0;
                end
            end
        end
    end
endmodule
