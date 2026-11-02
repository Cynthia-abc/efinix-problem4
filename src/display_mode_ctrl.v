 
 
 
 
 
 
module display_mode_ctrl (
    input sys_clk, input sys_rst_n,
    input [7:0] rx_byte, input rx_valid,
    input video_clk, input video_rst_n, input video_blank,
    output reg [2:0] active_mode,
    output reg [2:0] applied_mode,
    output reg applied_valid,
    output reg [1:0] active_slots,
    output reg [1:0] applied_slots,
    output reg slots_applied_valid
);
    reg [2:0] requested_mode, held_mode;
    reg [1:0] requested_slots, held_slots;
    reg held_is_slots, requested_is_slots;
    reg dirty, busy, request_toggle;
    reg acknowledge_toggle;
    (* async_reg="true" *) reg ack_meta, ack_sync;
    (* async_reg="true" *) reg req_meta, req_sync;
    reg req_seen, settle;
    wire digit = rx_byte >= 8'h30 && rx_byte <= 8'h34;
    wire slot_cmd = rx_byte >= 8'h41 && rx_byte <= 8'h43;

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            requested_mode<=0; held_mode<=0; requested_slots<=3; held_slots<=3;
            requested_is_slots<=0; held_is_slots<=0; dirty<=0; busy<=0;
            request_toggle<=0; ack_meta<=0; ack_sync<=0;
            applied_mode<=0; applied_slots<=3; applied_valid<=0; slots_applied_valid<=0;
        end else begin
            ack_meta<=acknowledge_toggle; ack_sync<=ack_meta;
            applied_valid<=0;
            slots_applied_valid<=0;
            if (busy && ack_sync==request_toggle) begin
                busy<=0;
                applied_mode<=held_mode;
                applied_slots<=held_slots;
                applied_valid<=1;
                slots_applied_valid<=held_is_slots;
            end
            if (!busy && dirty) begin
                held_mode<=requested_mode;
                held_slots<=requested_slots;
                held_is_slots<=requested_is_slots;
                request_toggle<=~request_toggle;
                dirty<=0;
                busy<=1;
            end
             
            if (rx_valid && (digit || slot_cmd || rx_byte==8'h3f)) begin
                 
                 
                 
                if (digit) begin
                    requested_mode<=rx_byte-8'h30;
                    requested_is_slots<=0;
                end else if (slot_cmd) begin
                    requested_slots<=rx_byte-8'h40;
                    requested_is_slots<=1;
                end else begin
                    requested_is_slots<=0;
                end
                dirty<=1;
            end
        end
    end

     
     
    always @(posedge video_clk or negedge video_rst_n) begin
        if (!video_rst_n) begin
            req_meta<=0; req_sync<=0; req_seen<=0; settle<=0;
            active_mode<=0; active_slots<=3; acknowledge_toggle<=0;
        end else begin
            req_meta<=request_toggle; req_sync<=req_meta;
            if (req_sync!=req_seen) begin
                if (!settle) settle<=1;
                else if (video_blank) begin
                    active_mode<=held_mode;
                    active_slots<=held_slots;
                    req_seen<=req_sync;
                    acknowledge_toggle<=req_sync;
                    settle<=0;
                end
            end else settle<=0;
        end
    end
endmodule
