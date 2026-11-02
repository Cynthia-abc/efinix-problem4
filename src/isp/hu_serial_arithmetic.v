 
 
module hu_serial_arithmetic #(
    parameter integer WIDTH = 128
) (
    input clk, input rst_n, input start, input divide,
    input [WIDTH-1:0] operand_a, input [WIDTH-1:0] operand_b,
    output reg busy, output reg done, output reg divide_by_zero,
    output reg [WIDTH-1:0] result
);
    reg mode;
    reg [$clog2(WIDTH)-1:0] bit_index;
    reg [WIDTH-1:0] accum, multiplicand, multiplier;
    reg [WIDTH-1:0] dividend, divisor, quotient;
    reg [WIDTH:0] remainder_work;
    wire [WIDTH:0] shifted_remainder = {remainder_work[WIDTH-1:0], dividend[WIDTH-1]};
    wire subtract_ok = shifted_remainder >= {1'b0, divisor};
    wire [WIDTH:0] next_remainder = subtract_ok ?
        shifted_remainder - {1'b0, divisor} : shifted_remainder;
    wire [WIDTH-1:0] next_quotient = {quotient[WIDTH-2:0], subtract_ok};
    wire [WIDTH-1:0] next_product = accum + (multiplier[0] ? multiplicand : {WIDTH{1'b0}});
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 0; done <= 0; divide_by_zero <= 0; result <= 0;
            mode <= 0; bit_index <= 0; accum <= 0; multiplicand <= 0;
            multiplier <= 0; dividend <= 0; divisor <= 0;
            quotient <= 0; remainder_work <= 0;
        end else begin
            done <= 0;
            if (start && !busy) begin
                mode <= divide; bit_index <= 0; divide_by_zero <= 0;
                if (divide && operand_b == 0) begin
                    result <= {WIDTH{1'b1}}; done <= 1; divide_by_zero <= 1;
                end else begin
                    busy <= 1; accum <= 0; multiplicand <= operand_a;
                    multiplier <= operand_b; dividend <= operand_a;
                    divisor <= operand_b; quotient <= 0; remainder_work <= 0;
                end
            end else if (busy) begin
                if (mode) begin
                    remainder_work <= next_remainder;
                    dividend <= {dividend[WIDTH-2:0], 1'b0};
                    quotient <= next_quotient;
                end else begin
                    accum <= next_product;
                    multiplicand <= multiplicand << 1;
                    multiplier <= multiplier >> 1;
                end
                if (bit_index == WIDTH-1) begin
                    result <= mode ? next_quotient : next_product;
                    busy <= 0; done <= 1;
                end else bit_index <= bit_index + 1'b1;
            end
        end
    end
endmodule
