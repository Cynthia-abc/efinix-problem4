 
module threshold_uart_ctrl #(
    parameter [7:0] INITIAL_THRESHOLD = 8'd64
) (
    input        clk,
    input        rst_n,
    input  [7:0] rx_byte,
    input        rx_valid,
    output reg [7:0] threshold_shadow,
    output reg       threshold_update_toggle
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            threshold_shadow        <= INITIAL_THRESHOLD;
            threshold_update_toggle <= 1'b0;
        end else if (rx_valid) begin
            if (rx_byte == 8'h2b) begin
                 
                if (threshold_shadow < 8'd248) begin
                    if (threshold_shadow >= 8'd240)
                        threshold_shadow <= 8'd248;
                    else
                        threshold_shadow <= threshold_shadow + 8'd8;
                    threshold_update_toggle <= ~threshold_update_toggle;
                end
            end else if (rx_byte == 8'h2d) begin
                 
                if (threshold_shadow > 8'd0) begin
                    if (threshold_shadow <= 8'd8)
                        threshold_shadow <= 8'd0;
                    else
                        threshold_shadow <= threshold_shadow - 8'd8;
                    threshold_update_toggle <= ~threshold_update_toggle;
                end
            end
        end
    end

endmodule
