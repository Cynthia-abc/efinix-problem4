 
 
 
module uart_mode_reply #(
    parameter integer CLK_FREQ=96000000,
    parameter integer BAUD_RATE=115200
) (
    input clk, input rst_n,
    input [2:0] applied_mode, input applied_valid,
    input [1:0] applied_slots, input slots_applied_valid,
    output reg tx_o
);
    localparam integer CLKS_PER_BIT=CLK_FREQ/BAUD_RATE;
    reg [9:0] shift_data;
    reg [3:0] bit_index;
    reg [15:0] bit_count;
    reg busy, pending_valid;
    reg [7:0] pending_byte;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_o<=1; shift_data<=10'h3ff; bit_index<=0; bit_count<=0;
            busy<=0; pending_valid<=0; pending_byte<=8'h30;
        end else begin
            if (!busy && pending_valid) begin
                shift_data<={1'b1,pending_byte,1'b0};
                tx_o<=0; bit_index<=0; bit_count<=CLKS_PER_BIT-1;
                busy<=1; pending_valid<=0;
            end else if (busy) begin
                if (bit_count!=0) bit_count<=bit_count-1'b1;
                else if (bit_index==9) begin
                    busy<=0; tx_o<=1;
                end else begin
                    shift_data<={1'b1,shift_data[9:1]};
                    tx_o<=shift_data[1];
                    bit_index<=bit_index+1'b1;
                    bit_count<=CLKS_PER_BIT-1;
                end
            end
            if (applied_valid) begin
                pending_byte<=slots_applied_valid ? (8'h40+applied_slots) : (8'h30+applied_mode);
                pending_valid<=1;
            end
        end
    end
endmodule
