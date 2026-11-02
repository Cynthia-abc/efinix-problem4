 
 
 
 
module canny_nms_core (
    input  [7:0] m00,
    input  [7:0] m01,
    input  [7:0] m02,
    input  [7:0] m10,
    input  [7:0] m11,
    input  [7:0] m12,
    input  [7:0] m20,
    input  [7:0] m21,
    input  [7:0] m22,
    input  [1:0] direction,
    input        window_valid,
    output reg [7:0] edge_data,
    output reg       edge_valid
);

    reg [7:0] neighbor_a;
    reg [7:0] neighbor_b;

    always @* begin
        neighbor_a = 8'd0;
        neighbor_b = 8'd0;
        case (direction)
            2'b00: begin
                neighbor_a = m10;
                neighbor_b = m12;
            end
            2'b01: begin
                neighbor_a = m01;
                neighbor_b = m21;
            end
            2'b10: begin
                neighbor_a = m00;
                neighbor_b = m22;
            end
            default: begin
                neighbor_a = m02;
                neighbor_b = m20;
            end
        endcase

        edge_valid = window_valid;
        if (window_valid && (m11 >= neighbor_a) && (m11 >= neighbor_b))
            edge_data = m11;
        else
            edge_data = 8'd0;
    end

endmodule
