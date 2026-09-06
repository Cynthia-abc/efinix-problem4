// Combinational 3x3 Sobel edge detector for 8-bit grayscale pixels.
module sobel_core (
    input  [7:0] p00,
    input  [7:0] p01,
    input  [7:0] p02,
    input  [7:0] p10,
    input  [7:0] p11,
    input  [7:0] p12,
    input  [7:0] p20,
    input  [7:0] p21,
    input  [7:0] p22,
    input        window_valid,
    output reg [7:0] edge_data,
    output reg       edge_valid
);

    // Zero-extend each unsigned pixel before signed Sobel arithmetic.
    reg signed [12:0] s_p00;
    reg signed [12:0] s_p01;
    reg signed [12:0] s_p02;
    reg signed [12:0] s_p10;
    reg signed [12:0] s_p12;
    reg signed [12:0] s_p20;
    reg signed [12:0] s_p21;
    reg signed [12:0] s_p22;

    reg signed [12:0] gx;
    reg signed [12:0] gy;
    reg signed [12:0] abs_gx;
    reg signed [12:0] abs_gy;
    reg        [12:0] magnitude;

    always @* begin
        s_p00 = {5'b0, p00};
        s_p01 = {5'b0, p01};
        s_p02 = {5'b0, p02};
        s_p10 = {5'b0, p10};
        s_p12 = {5'b0, p12};
        s_p20 = {5'b0, p20};
        s_p21 = {5'b0, p21};
        s_p22 = {5'b0, p22};

        // Sobel horizontal and vertical gradients. A factor of two uses a shift.
        gx = -s_p00 + s_p02 - (s_p10 <<< 1) +
             (s_p12 <<< 1) - s_p20 + s_p22;
        gy =  s_p00 + (s_p01 <<< 1) + s_p02 -
             s_p20 - (s_p21 <<< 1) - s_p22;

        // Convert signed gradients to magnitudes and add them.
        abs_gx = (gx < 0) ? -gx : gx;
        abs_gy = (gy < 0) ? -gy : gy;
        magnitude = abs_gx + abs_gy;

        // Validity passes through without a clock delay; invalid data is zero.
        edge_valid = window_valid;
        if (!window_valid)
            edge_data = 8'd0;
        else if (magnitude > 13'd255)
            edge_data = 8'hff;
        else
            edge_data = magnitude[7:0];
    end

endmodule
