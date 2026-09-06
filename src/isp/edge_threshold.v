// Threshold-binarize the Sobel gradient strength without adding latency.
module edge_threshold #(
    parameter THRESHOLD = 8'd80
) (
    input  [7:0] edge_data_in,
    input        edge_valid_in,
    output reg [7:0] edge_data_out,
    output reg       edge_valid_out
);

    always @* begin
        edge_valid_out = edge_valid_in;

        if (!edge_valid_in) begin
            edge_data_out = 8'd0;
            edge_valid_out = 1'b0;
        end else if (edge_data_in >= THRESHOLD) begin
            edge_data_out = 8'hff;
        end else begin
            edge_data_out = 8'd0;
        end
    end

endmodule
