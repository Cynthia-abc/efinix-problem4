 
 
 
module threshold_key_ctrl #(
    parameter integer CLK_FREQ_HZ       = 96000000,
    parameter integer DEBOUNCE_MS       = 20,
    parameter integer COMBO_WAIT_MS     = 120,
    parameter integer LONG_PRESS_MS     = 800,
    parameter [7:0]   INITIAL_THRESHOLD = 8'd64,
    parameter [7:0]   THRESHOLD_STEP    = 8'd8,
    parameter [7:0]   MAX_THRESHOLD     = 8'd248
) (
    input            clk,
    input            rst_n,
    input      [1:0] key_n,
    output reg [7:0] threshold_shadow,
    output reg       threshold_update_toggle,
    output reg       frame_freeze_active,
    output reg       replay_prev_toggle,
    output reg       replay_next_toggle
);

    localparam integer DEBOUNCE_CYCLES  = (CLK_FREQ_HZ / 1000) * DEBOUNCE_MS;
    localparam integer COMBO_WAIT_CYCLES = (CLK_FREQ_HZ / 1000) * COMBO_WAIT_MS;
    localparam integer LONG_PRESS_CYCLES = (CLK_FREQ_HZ / 1000) * LONG_PRESS_MS;

    reg [1:0] key_meta;
    reg [1:0] key_sync;
    reg [1:0] key_debounced_n;
    reg [1:0] key_debounced_d;
    reg [31:0] key0_count;
    reg [31:0] key1_count;

     
    reg [1:0]  pending_single_key;
    reg [31:0] combo_wait_count;
    reg [31:0] single_hold_count;
    reg        long_action_sent;

    wire key_add_press = key_debounced_d[0] && !key_debounced_n[0];
    wire key_sub_press = key_debounced_d[1] && !key_debounced_n[1];
     
    wire key_both_press = (key_debounced_d != 2'b00) &&
                          (key_debounced_n == 2'b00);

     
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_meta <= 2'b11;
            key_sync <= 2'b11;
        end else begin
            key_meta <= key_n;
            key_sync <= key_meta;
        end
    end

     
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_debounced_n <= 2'b11;
            key0_count      <= 32'd0;
            key1_count      <= 32'd0;
        end else begin
            if (key_sync[0] == key_debounced_n[0]) begin
                key0_count <= 32'd0;
            end else if (key0_count >= DEBOUNCE_CYCLES - 1) begin
                key_debounced_n[0] <= key_sync[0];
                key0_count <= 32'd0;
            end else begin
                key0_count <= key0_count + 1'b1;
            end

            if (key_sync[1] == key_debounced_n[1]) begin
                key1_count <= 32'd0;
            end else if (key1_count >= DEBOUNCE_CYCLES - 1) begin
                key_debounced_n[1] <= key_sync[1];
                key1_count <= 32'd0;
            end else begin
                key1_count <= key1_count + 1'b1;
            end
        end
    end

     
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            key_debounced_d <= 2'b11;
        else
            key_debounced_d <= key_debounced_n;
    end

     
     
     
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            threshold_shadow        <= INITIAL_THRESHOLD;
            threshold_update_toggle <= 1'b0;
            frame_freeze_active     <= 1'b0;
            replay_prev_toggle      <= 1'b0;
            replay_next_toggle      <= 1'b0;
            pending_single_key      <= 2'b00;
            combo_wait_count        <= 32'd0;
            single_hold_count       <= 32'd0;
            long_action_sent        <= 1'b0;
        end else if (key_both_press) begin
             
             
            frame_freeze_active <= ~frame_freeze_active;
            pending_single_key  <= 2'b00;
            combo_wait_count    <= 32'd0;
            single_hold_count   <= 32'd0;
            long_action_sent    <= 1'b0;
        end else if (pending_single_key != 2'b00) begin
            if (combo_wait_count < COMBO_WAIT_CYCLES)
                combo_wait_count <= combo_wait_count + 1'b1;

             
            if (!long_action_sent &&
                !((pending_single_key == 2'b01) ? key_debounced_n[0] :
                                                   key_debounced_n[1])) begin
                if (single_hold_count >= LONG_PRESS_CYCLES - 1) begin
                    if (pending_single_key == 2'b01)
                        replay_prev_toggle <= ~replay_prev_toggle;
                    else
                        replay_next_toggle <= ~replay_next_toggle;
                    long_action_sent  <= 1'b1;
                    single_hold_count <= single_hold_count;
                end else begin
                    single_hold_count <= single_hold_count + 1'b1;
                end
            end

             
            if ((combo_wait_count >= COMBO_WAIT_CYCLES - 1) &&
                !long_action_sent &&
                ((pending_single_key == 2'b01) ? key_debounced_n[0] :
                                                 key_debounced_n[1])) begin
                if (pending_single_key == 2'b01) begin
                    if (threshold_shadow < MAX_THRESHOLD) begin
                        if (threshold_shadow >= MAX_THRESHOLD - THRESHOLD_STEP)
                            threshold_shadow <= MAX_THRESHOLD;
                        else
                            threshold_shadow <= threshold_shadow + THRESHOLD_STEP;
                        threshold_update_toggle <= ~threshold_update_toggle;
                    end
                end else begin
                    if (threshold_shadow > 8'd0) begin
                        if (threshold_shadow <= THRESHOLD_STEP)
                            threshold_shadow <= 8'd0;
                        else
                            threshold_shadow <= threshold_shadow - THRESHOLD_STEP;
                        threshold_update_toggle <= ~threshold_update_toggle;
                    end
                end
                pending_single_key <= 2'b00;
                combo_wait_count   <= 32'd0;
                single_hold_count  <= 32'd0;
            end else if ((combo_wait_count >= COMBO_WAIT_CYCLES - 1) &&
                         long_action_sent &&
                         ((pending_single_key == 2'b01) ? key_debounced_n[0] :
                                                          key_debounced_n[1])) begin
                 
                pending_single_key <= 2'b00;
                combo_wait_count   <= 32'd0;
                single_hold_count  <= 32'd0;
                long_action_sent   <= 1'b0;
            end
        end else if (key_add_press && !key_sub_press) begin
            pending_single_key <= 2'b01;
            combo_wait_count   <= 32'd0;
            single_hold_count  <= 32'd0;
            long_action_sent   <= 1'b0;
        end else if (key_sub_press && !key_add_press) begin
            pending_single_key <= 2'b10;
            combo_wait_count   <= 32'd0;
            single_hold_count  <= 32'd0;
            long_action_sent   <= 1'b0;
        end
    end

endmodule
