 
 
 
 
 
module uart_rx #(
    parameter integer CLK_FREQ  = 96000000,
    parameter integer BAUD_RATE = 460800
) (
    input        clk,
    input        rst_n,
    input        rx_i,
    output reg [7:0] rx_byte,
    output reg       rx_valid
);

     
    localparam integer CLKS_PER_BIT = (CLK_FREQ / BAUD_RATE);
    localparam integer HALF_BIT     = (CLKS_PER_BIT / 2);

    localparam [1:0] STATE_IDLE  = 2'd0;
    localparam [1:0] STATE_START = 2'd1;
    localparam [1:0] STATE_DATA  = 2'd2;
    localparam [1:0] STATE_STOP  = 2'd3;

    reg        rx_meta;
    reg        rx_sync;
    reg [1:0]  state;
    reg [31:0] bit_count;
    reg [3:0]  bit_index;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_meta   <= 1'b1;
            rx_sync   <= 1'b1;
            state     <= STATE_IDLE;
            bit_count <= 32'd0;
            bit_index <= 4'd0;
            rx_byte   <= 8'd0;
            rx_valid  <= 1'b0;
        end else begin
            rx_meta  <= rx_i;
            rx_sync  <= rx_meta;
            rx_valid <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    bit_count <= 32'd0;
                    bit_index <= 4'd0;
                    if (!rx_sync) begin
                        state <= STATE_START;
                        if (HALF_BIT > 0)
                            bit_count <= HALF_BIT - 1;
                    end
                end

                STATE_START: begin
                    if (bit_count == 0) begin
                         
                        if (!rx_sync) begin
                            state     <= STATE_DATA;
                            bit_index <= 4'd0;
                            if (CLKS_PER_BIT > 0)
                                bit_count <= CLKS_PER_BIT - 1;
                        end else begin
                            state <= STATE_IDLE;
                        end
                    end else begin
                        bit_count <= bit_count - 1'b1;
                    end
                end

                STATE_DATA: begin
                    if (bit_count == 0) begin
                        rx_byte[bit_index] <= rx_sync;
                        if (bit_index == 4'd7) begin
                            state <= STATE_STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                        if (CLKS_PER_BIT > 0)
                            bit_count <= CLKS_PER_BIT - 1;
                    end else begin
                        bit_count <= bit_count - 1'b1;
                    end
                end

                STATE_STOP: begin
                    if (bit_count == 0) begin
                         
                        if (rx_sync)
                            rx_valid <= 1'b1;
                        state     <= STATE_IDLE;
                        bit_count <= 32'd0;
                    end else begin
                        bit_count <= bit_count - 1'b1;
                    end
                end

                default: begin
                    state     <= STATE_IDLE;
                    bit_count <= 32'd0;
                    bit_index <= 4'd0;
                end
            endcase
        end
    end

endmodule
