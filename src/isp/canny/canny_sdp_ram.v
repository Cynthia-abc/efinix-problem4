 
 
 
 
module canny_sdp_ram #(
    parameter integer WIDTH=8, DEPTH=1920,
    parameter integer AW=(DEPTH>1 ? $clog2(DEPTH) : 1)
) (
    input clk, input rst_n,
    input wr_en, input [AW-1:0] wr_addr, input [WIDTH-1:0] wr_data,
    input rd_en, input [AW-1:0] rd_addr, output reg [WIDTH-1:0] rd_data
);
    localparam integer BANKS=(DEPTH+2047)/2048;
    localparam integer SLICES=(WIDTH+4)/5;
    wire [SLICES*5-1:0] padded_write={{(SLICES*5-WIDTH){1'b0}},wr_data};
    wire [SLICES*5-1:0] bank_data[0:BANKS-1];
    wire [10:0] native_wr_addr=wr_addr;
    wire [10:0] native_rd_addr=rd_addr;
    reg [AW-1:0] selected_bank;
    always @(posedge clk or negedge rst_n)
        if(!rst_n) selected_bank<=0;
        else if(rd_en) selected_bank<=rd_addr>>11;
    genvar b,s;
    generate for(b=0;b<BANKS;b=b+1) begin:g_bank
        for(s=0;s<SLICES;s=s+1) begin:g_slice
            EFX_RAM10 #(.READ_WIDTH(5),.WRITE_WIDTH(5),.OUTPUT_REG(1'b0),
                        .WRITE_MODE("READ_FIRST")) u_ram (
                .WCLK(clk),.WCLKE(wr_en && ((wr_addr>>11)==b)),
                .WE(2'b11),.WADDREN(1'b1),.WADDR(native_wr_addr),
                .WDATA(padded_write[s*5+:5]),
                .RCLK(clk),.RE(rd_en && ((rd_addr>>11)==b)),
                .RST(1'b0),.RADDREN(1'b1),.RADDR(native_rd_addr),
                .RDATA(bank_data[b][s*5+:5])
            );
        end
    end endgenerate
    integer i;
    always @* begin
        rd_data=0;
        for(i=0;i<BANKS;i=i+1)
            if(selected_bank==i) rd_data=bank_data[i][WIDTH-1:0];
    end
`ifndef SYNTHESIS
    always @(posedge clk) if(rst_n) begin
        if(wr_en && wr_addr>=DEPTH) $fatal(1,"Canny RAM write outside depth");
        if(rd_en && rd_addr>=DEPTH) $fatal(1,"Canny RAM read outside depth");
        if(wr_en && rd_en && wr_addr==rd_addr)
            $fatal(1,"Canny RAM read/write collision");
    end
`endif
endmodule

 
 
 
module canny_pixel_delay #(
    parameter integer WIDTH=8,DEPTH=1920,
    parameter integer AW=(DEPTH>1 ? $clog2(DEPTH) : 1)
) (
    input clk,input rst_n,input valid,input restart,input [WIDTH-1:0] data,
    output [WIDTH-1:0] delayed_data
);
    reg [AW-1:0] pointer,write_addr;
    reg write_valid;
    reg [WIDTH-1:0] write_data;
    wire [AW-1:0] current_addr=restart ? {AW{1'b0}}:pointer;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin pointer<=0;write_addr<=0;write_valid<=0;write_data<=0;end
        else begin
            write_valid<=valid;
            if(valid) begin
                write_addr<=current_addr;write_data<=data;
                if(current_addr==DEPTH-1) pointer<=0;else pointer<=current_addr+1'b1;
            end
        end
    end
    canny_sdp_ram #(.WIDTH(WIDTH),.DEPTH(DEPTH)) u_ram (
        .clk(clk),.rst_n(rst_n),.wr_en(write_valid),.wr_addr(write_addr),
        .wr_data(write_data),.rd_en(valid),.rd_addr(current_addr),.rd_data(delayed_data)
    );
endmodule
