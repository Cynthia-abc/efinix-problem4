// SIMULATION ONLY. NOT registered in the Efinity project.
// Word-level equivalent of the *specific* native 2048x5, unregistered-output
// configuration used by canny_sdp_ram. Accelerates full-raster simulations;
// official Efinix model is used for module, hysteresis and banking regressions.
// Same-address read/write is forbidden and checked by canny_sdp_ram.
module EFX_RAM10 #(
    parameter READ_WIDTH=5,WRITE_WIDTH=5,OUTPUT_REG=1'b0,
    parameter WRITE_MODE="READ_FIRST"
) (
    input WCLK,WCLKE,WADDREN,input [1:0] WE,input [4:0] WDATA,input [10:0] WADDR,
    input RCLK,RE,RST,RADDREN,input [10:0] RADDR,output reg [4:0] RDATA
);
    reg [4:0] words[0:2047];
    integer i;
    initial begin
        if(READ_WIDTH!=5 || WRITE_WIDTH!=5 || OUTPUT_REG!=0 || WRITE_MODE!="READ_FIRST")
            $fatal(1,"Fast model used outside verified configuration");
        RDATA=0;for(i=0;i<2048;i=i+1) words[i]=0;
    end
    always @(posedge WCLK)
        if(WCLKE && WADDREN && WE==2'b11) words[WADDR]<=WDATA;
    always @(posedge RCLK or posedge RST)
        if(RST) RDATA<=0;else if(RE && RADDREN) RDATA<=words[RADDR];
endmodule
