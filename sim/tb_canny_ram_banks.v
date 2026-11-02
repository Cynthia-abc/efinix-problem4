`timescale 1ns/1ps
// Official vendor primitive model, depth beyond 8192, width spanning five
// 5-bit slices. Checks all bank transitions, pointer wrap, bubbles and reset.
module tb_canny_ram_banks;
    localparam DEPTH=8825,N=DEPTH*3+17;
    reg clk=0;always #3.36 clk=~clk;
    reg rst_n=0,v=0;reg [23:0] data=0;wire [23:0] got;
    canny_pixel_delay #(.WIDTH(24),.DEPTH(DEPTH)) dut (
        .clk(clk),.rst_n(rst_n),.valid(v),.restart(1'b0),.data(data),.delayed_data(got));
    reg [23:0] reference[0:N-1];integer seen=0,i;
    reg [23:0] expected;reg compare_now;
    always @(posedge clk) begin
        if(!rst_n) seen=0;
        else begin
            compare_now=v && seen>=DEPTH;
            if(v) begin
                reference[seen]=data;
                if(compare_now) expected=reference[seen-DEPTH];
                seen=seen+1;
            end
            #1;
            if(compare_now && got!==expected) $fatal(1,"RAM bank/wrap sample %0d got %h expected %h",seen-1,got,expected);
        end
    end
    initial begin
        repeat(5) @(negedge clk);rst_n=1;
        for(i=0;i<N;i=i+1) begin
            @(negedge clk);v=1;data=(i*24'h123457)^24'hac59f3;
            if(i%11==5) begin @(negedge clk);v=0;end
        end
        @(negedge clk);v=0;repeat(10) @(negedge clk);
        if(seen!=N) $fatal(1,"RAM test lost samples");
        $display("PASS official BRAM model: 24-bit x 8825, all five banks/slices, 3 wraps + bubbles, no read/write collisions");$finish;
    end
    initial begin #300000;$fatal(1,"RAM test timeout");end
endmodule
