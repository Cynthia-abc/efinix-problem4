`timescale 1ns/1ps
module tb_uart_modes;
    parameter CLK_FREQ=96000000, BAUD=115200;
    localparam CPB=CLK_FREQ/BAUD;
    reg sys_clk=0,video_clk=0;
    always #5 sys_clk=~sys_clk;
    always #3.36 video_clk=~video_clk;
    reg rst_n=0,rx=1,blank=0;
    wire [7:0] rx_byte,reply_byte;
    wire rx_valid,reply_valid,tx,applied_valid;
    wire [1:0] active,applied;
    uart_rx #(.CLK_FREQ(CLK_FREQ),.BAUD_RATE(BAUD)) receiver (
        .clk(sys_clk),.rst_n(rst_n),.rx_i(rx),.rx_byte(rx_byte),.rx_valid(rx_valid));
    display_mode_ctrl ctrl (
        .sys_clk(sys_clk),.sys_rst_n(rst_n),.rx_byte(rx_byte),.rx_valid(rx_valid),
        .video_clk(video_clk),.video_rst_n(rst_n),.video_blank(blank),
        .active_mode(active),.applied_mode(applied),.applied_valid(applied_valid));
    uart_mode_reply #(.CLK_FREQ(CLK_FREQ),.BAUD_RATE(BAUD)) transmitter (
        .clk(sys_clk),.rst_n(rst_n),.applied_mode(applied),
        .applied_valid(applied_valid),.tx_o(tx));
    uart_rx #(.CLK_FREQ(CLK_FREQ),.BAUD_RATE(BAUD)) reply_receiver (
        .clk(sys_clk),.rst_n(rst_n),.rx_i(tx),.rx_byte(reply_byte),.rx_valid(reply_valid));
    integer replies=0,commits=0;
    reg [7:0] last_reply;
    reg [1:0] previous=0;
    reg was_blank;
    always @(posedge sys_clk) begin
        if(rst_n && reply_valid) begin
            replies=replies+1;last_reply=reply_byte;
            if(reply_byte<8'h30 || reply_byte>8'h33) $fatal(1,"invalid reply");
        end
        if(rst_n && applied_valid) commits=commits+1;
    end
    always @(posedge video_clk) begin
        was_blank=blank;
        #0.2;
        if(rst_n && active!==previous && !was_blank)
            $fatal(1,"mode changed during visible frame");
        previous=active;
    end
    task send;
        input [7:0] b;
        input bad_stop;
        integer bitno;
        begin
            @(negedge sys_clk);rx=0;repeat(CPB) @(negedge sys_clk);
            for(bitno=0;bitno<8;bitno=bitno+1) begin
                rx=b[bitno];repeat(CPB) @(negedge sys_clk);
            end
            rx=!bad_stop;repeat(CPB) @(negedge sys_clk);
            rx=1;repeat(CPB) @(negedge sys_clk);
        end
    endtask
    task wait_reply;
        input [7:0] expected;
        input integer minimum;
        integer t;
        begin
            t=0;
            while((replies<minimum || last_reply!==expected) && t<CPB*30) begin
                @(negedge sys_clk);t=t+1;
            end
            if(t==CPB*30) $fatal(1,"reply timeout expected %h got %h count %0d",expected,last_reply,replies);
        end
    endtask
    integer n,k;
    initial begin
        repeat(5) @(negedge sys_clk);rst_n=1;
        repeat(5) @(negedge sys_clk);
        if(active!==0) $fatal(1,"boot mode");
        // Invalid bytes, CR/LF, raw numeric 01 and malformed stop bits do not act.
        send(8'h78,0);send(8'h0d,0);send(8'h0a,0);send(8'h01,0);send(8'h33,1);
        repeat(40) @(negedge sys_clk);
        if(commits!=0 || replies!=0 || active!==0) $fatal(1,"invalid command acted");
        send(8'h31,0);
        repeat(40) @(negedge sys_clk);
        if(active!==0 || replies!=0) $fatal(1,"changed before blanking");
        @(negedge video_clk);blank=1;
        wait_reply(8'h31,1);
        if(active!==1) $fatal(1,"mode 1 missing");
        // All valid digits, repeat selection, and query.
        for(k=0;k<4;k=k+1) begin
            n=replies;send(8'h30+k,0);wait_reply(8'h30+k,n+1);
            if(active!==k) $fatal(1,"wrong active mode");
        end
        n=replies;send(8'h33,0);wait_reply(8'h33,n+1);
        n=replies;send(8'h3f,0);wait_reply(8'h33,n+1);
        // Queue commands with blanking withheld: finish at the latest request.
        @(negedge video_clk);blank=0;
        n=replies;send(8'h30,0);send(8'h31,0);send(8'h32,0);
        if(active!==3 || replies!=n) $fatal(1,"burst changed active frame");
        @(negedge video_clk);blank=1;
        wait_reply(8'h32,n+2);
        if(active!==2) $fatal(1,"latest request lost");
        // Reset while a command is waiting, then recover with a fresh command.
        @(negedge video_clk);blank=0;
        send(8'h33,0);
        @(negedge sys_clk);rst_n=0;
        repeat(10) @(negedge sys_clk);rst_n=1;
        @(negedge video_clk);blank=1;
        n=replies;send(8'h31,0);wait_reply(8'h31,n+1);
        if(active!==1) $fatal(1,"reset recovery");
        $display("PASS UART: digits/query/invalid bytes/bad stop/CDC/blank commit/burst/reset/reply");
        $finish;
    end
    initial begin #10000000;$fatal(1,"watchdog");end
endmodule
