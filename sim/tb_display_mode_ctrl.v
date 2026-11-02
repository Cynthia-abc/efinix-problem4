`timescale 1ns/1ps
module tb_display_mode_ctrl;
  reg sys_clk=0, video_clk=0, sys_rst_n=0, video_rst_n=0;
  reg [7:0] rx_byte=0; reg rx_valid=0; reg video_blank=0;
  wire [2:0] active_mode, applied_mode; wire applied_valid;
  wire [1:0] active_slots, applied_slots; wire slots_applied_valid;
  reg applied_seen=0, slots_seen=0;
  display_mode_ctrl dut(
    .sys_clk(sys_clk), .sys_rst_n(sys_rst_n), .rx_byte(rx_byte), .rx_valid(rx_valid),
    .video_clk(video_clk), .video_rst_n(video_rst_n), .video_blank(video_blank),
    .active_mode(active_mode), .applied_mode(applied_mode), .applied_valid(applied_valid),
    .active_slots(active_slots), .applied_slots(applied_slots),
    .slots_applied_valid(slots_applied_valid));
  always #5 sys_clk=~sys_clk;
  always #7 video_clk=~video_clk;
  always @(posedge sys_clk) begin
    if (applied_valid && applied_mode==3'd4) applied_seen<=1'b1;
    if (slots_applied_valid && applied_slots==2'd1) slots_seen<=1'b1;
  end
  initial begin
    repeat(4) @(posedge sys_clk); sys_rst_n=1; video_rst_n=1;
    @(negedge sys_clk); rx_byte=8'h34; rx_valid=1;
    repeat(2) @(negedge sys_clk); rx_valid=0;
    repeat(12) @(posedge video_clk);
    video_blank=1'b1; repeat(12) @(posedge video_clk); video_blank=1'b0;
    repeat(12) @(posedge sys_clk);
    if (active_mode !== 3'd4 || applied_mode !== 3'd4 || !applied_seen)
      $fatal(1,"mode4 commit failed: active=%0d applied=%0d seen=%0d",active_mode,applied_mode,applied_seen);
    @(negedge sys_clk); rx_byte=8'h41; rx_valid=1;
    repeat(2) @(negedge sys_clk); rx_valid=0;
    repeat(12) @(posedge video_clk);
    video_blank=1'b1; repeat(12) @(posedge video_clk); video_blank=1'b0;
    repeat(12) @(posedge sys_clk);
    if (active_slots !== 2'd1 || applied_slots !== 2'd1 || !slots_seen)
      $fatal(1,"slot-count commit failed: active=%0d applied=%0d seen=%0d",active_slots,applied_slots,slots_seen);
    $display("PASS tb_display_mode_ctrl: ASCII 4 and A commit mode/box count");
    $finish;
  end
endmodule
