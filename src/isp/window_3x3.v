// Combinational-output 3x3 window generator with two line buffers.
module window_3x3 #(
    parameter IMAGE_WIDTH = 1920
) (
    input        clk,
    input        rst_n,
    input  [7:0] gray_data,
    input        in_vsync,
    input        in_hsync,
    input        in_href,
    output reg [7:0] p00,
    output reg [7:0] p01,
    output reg [7:0] p02,
    output reg [7:0] p10,
    output reg [7:0] p11,
    output reg [7:0] p12,
    output reg [7:0] p20,
    output reg [7:0] p21,
    output reg [7:0] p22,
    output reg       out_vsync,
    output reg       out_hsync,
    output reg       out_href,
    output reg       window_valid
);

    // The two buffers retain the two rows above the current input row.
    reg [7:0] line_buffer_0 [0:IMAGE_WIDTH-1];
    reg [7:0] line_buffer_1 [0:IMAGE_WIDTH-1];

    // Each row has three horizontal registers for the most recent pixels.
    reg [7:0] top_shift_0, top_shift_1, top_shift_2;
    reg [7:0] mid_shift_0, mid_shift_1, mid_shift_2;
    reg [7:0] bot_shift_0, bot_shift_1, bot_shift_2;

    reg [31:0] column_count;
    reg [31:0] row_count;
    reg        previous_href;
    integer    reset_index;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            column_count  <= 0;
            row_count     <= 0;
            previous_href <= 1'b0;

            top_shift_0 <= 0;
            top_shift_1 <= 0;
            top_shift_2 <= 0;
            mid_shift_0 <= 0;
            mid_shift_1 <= 0;
            mid_shift_2 <= 0;
            bot_shift_0 <= 0;
            bot_shift_1 <= 0;
            bot_shift_2 <= 0;

            p00 <= 0; p01 <= 0; p02 <= 0;
            p10 <= 0; p11 <= 0; p12 <= 0;
            p20 <= 0; p21 <= 0; p22 <= 0;
            out_vsync <= 0;
            out_hsync <= 0;
            out_href  <= 0;
            window_valid <= 0;

            for (reset_index = 0; reset_index < IMAGE_WIDTH; reset_index = reset_index + 1) begin
                line_buffer_0[reset_index] <= 0;
                line_buffer_1[reset_index] <= 0;
            end
        end else if (in_vsync) begin
            // A frame start clears the address and horizontal history.
            column_count  <= 0;
            row_count     <= 0;
            previous_href <= 1'b0;

            top_shift_0 <= 0;
            top_shift_1 <= 0;
            top_shift_2 <= 0;
            mid_shift_0 <= 0;
            mid_shift_1 <= 0;
            mid_shift_2 <= 0;
            bot_shift_0 <= 0;
            bot_shift_1 <= 0;
            bot_shift_2 <= 0;

            p00 <= 0; p01 <= 0; p02 <= 0;
            p10 <= 0; p11 <= 0; p12 <= 0;
            p20 <= 0; p21 <= 0; p22 <= 0;
            out_vsync <= 1'b1;
            out_hsync <= in_hsync;
            out_href  <= 1'b0;
            window_valid <= 1'b0;

            for (reset_index = 0; reset_index < IMAGE_WIDTH; reset_index = reset_index + 1) begin
                line_buffer_0[reset_index] <= 0;
                line_buffer_1[reset_index] <= 0;
            end
        end else begin
            // Sync signals have the same registered timing as the window.
            out_vsync <= in_vsync;
            out_hsync <= in_hsync;
            out_href  <= in_href;
            previous_href <= in_href;

            if (!in_href) begin
                // The inactive gap ends a row and starts the next at column zero.
                if (previous_href)
                    row_count <= row_count + 1;
                column_count <= 0;

                top_shift_0 <= 0;
                top_shift_1 <= 0;
                top_shift_2 <= 0;
                mid_shift_0 <= 0;
                mid_shift_1 <= 0;
                mid_shift_2 <= 0;
                bot_shift_0 <= 0;
                bot_shift_1 <= 0;
                bot_shift_2 <= 0;
                window_valid <= 1'b0;
            end else begin
                // The current column supplies the right edge of the window.
                p00 <= top_shift_1;
                p01 <= top_shift_2;
                p02 <= line_buffer_1[column_count];
                p10 <= mid_shift_1;
                p11 <= mid_shift_2;
                p12 <= line_buffer_0[column_count];
                p20 <= bot_shift_1;
                p21 <= bot_shift_2;
                p22 <= gray_data;

                // Shift each row and advance the two line-buffer contents.
                top_shift_0 <= top_shift_1;
                top_shift_1 <= top_shift_2;
                top_shift_2 <= line_buffer_1[column_count];
                mid_shift_0 <= mid_shift_1;
                mid_shift_1 <= mid_shift_2;
                mid_shift_2 <= line_buffer_0[column_count];
                bot_shift_0 <= bot_shift_1;
                bot_shift_1 <= bot_shift_2;
                bot_shift_2 <= gray_data;

                line_buffer_1[column_count] <= line_buffer_0[column_count];
                line_buffer_0[column_count] <= gray_data;

                // Two complete previous rows and two previous columns are needed.
                window_valid <= (row_count >= 2) && (column_count >= 2);

                if (column_count < IMAGE_WIDTH - 1)
                    column_count <= column_count + 1;
                else
                    column_count <= 0;
            end
        end
    end

endmodule
