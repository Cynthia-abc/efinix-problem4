 
 
 
 
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
    output reg       edge_valid,
    output reg [1:0] edge_dir,
    output reg signed [12:0] gradient_x,
    output reg signed [12:0] gradient_y
);

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

        gx = -s_p00 + s_p02 - (s_p10 <<< 1) +
             (s_p12 <<< 1) - s_p20 + s_p22;
        gy =  s_p00 + (s_p01 <<< 1) + s_p02 -
             s_p20 - (s_p21 <<< 1) - s_p22;

        abs_gx = (gx < 0) ? -gx : gx;
        abs_gy = (gy < 0) ? -gy : gy;
        magnitude = abs_gx + abs_gy;

        edge_valid = window_valid;
        edge_dir   = 2'b00;
        gradient_x = window_valid ? gx : 13'sd0;
        gradient_y = window_valid ? gy : 13'sd0;
        if (!window_valid) begin
            edge_data = 8'd0;
        end else begin
            if (abs_gx >= (abs_gy <<< 1))
                edge_dir = 2'b00;
            else if (abs_gy >= (abs_gx <<< 1))
                edge_dir = 2'b01;
            else if (gx[12] == gy[12])
                edge_dir = 2'b10;
            else
                edge_dir = 2'b11;

            if (magnitude > 13'd255)
                edge_data = 8'hff;
            else
                edge_data = magnitude[7:0];
        end
    end

endmodule
