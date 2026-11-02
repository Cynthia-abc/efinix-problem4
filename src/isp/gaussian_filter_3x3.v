 
 
module gaussian_filter_3x3 (
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
    output reg [7:0] gaussian_data,
    output reg       gaussian_valid
);

    reg [11:0] weighted_sum;

    always @* begin
        weighted_sum = {4'd0, p00} + ({4'd0, p01} << 1) +
                       {4'd0, p02} + ({4'd0, p10} << 1) +
                       ({4'd0, p11} << 2) + ({4'd0, p12} << 1) +
                       {4'd0, p20} + ({4'd0, p21} << 1) +
                       {4'd0, p22};
        gaussian_data  = weighted_sum[11:4];
        gaussian_valid = window_valid;
    end

endmodule
