// Registered 3x3 window generator with two synchronous line buffers.
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

    // Two buffers alternate as the current-row store and the two-row history.
    reg [7:0] line_buffer_0 [0:IMAGE_WIDTH-1];
    reg [7:0] line_buffer_1 [0:IMAGE_WIDTH-1];

    // Synchronous RAM read results. These add one common cycle of latency.
    reg [7:0] top_read_q;
    reg [7:0] mid_read_q;
    reg [7:0] gray_data_q;

    // Each row has three horizontal registers for the most recent pixels.
    reg [7:0] top_shift_0, top_shift_1, top_shift_2;
    reg [7:0] mid_shift_0, mid_shift_1, mid_shift_2;
    reg [7:0] bot_shift_0, bot_shift_1, bot_shift_2;

    reg [31:0] column_count;
    reg [31:0] row_count;
    reg        previous_href;
    reg        write_bank;

    // Pending input metadata is delayed with the synchronous RAM data.
    reg        pending_vsync;
    reg        pending_hsync;
    reg        pending_href;
    reg        pending_window_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            column_count  <= 0;
            row_count     <= 0;
            previous_href <= 1'b0;
            write_bank    <= 1'b0;

            top_read_q  <= 0;
            mid_read_q  <= 0;
            gray_data_q <= 0;

            top_shift_0 <= 0;
            top_shift_1 <= 0;
            top_shift_2 <= 0;
            mid_shift_0 <= 0;
            mid_shift_1 <= 0;
            mid_shift_2 <= 0;
            bot_shift_0 <= 0;
            bot_shift_1 <= 0;
            bot_shift_2 <= 0;

            pending_vsync <= 1'b0;
            pending_hsync <= 1'b0;
            pending_href  <= 1'b0;
            pending_window_valid <= 1'b0;

            p00 <= 0; p01 <= 0; p02 <= 0;
            p10 <= 0; p11 <= 0; p12 <= 0;
            p20 <= 0; p21 <= 0; p22 <= 0;
            out_vsync <= 0;
            out_hsync <= 0;
            out_href  <= 0;
            window_valid <= 0;
        end else if (!in_vsync) begin
            // Current project convention: low VSYNC is the frame-sync interval.
            column_count  <= 0;
            row_count     <= 0;
            previous_href <= 1'b0;
            write_bank    <= 1'b0;

            top_read_q  <= 0;
            mid_read_q  <= 0;
            gray_data_q <= 0;

            top_shift_0 <= 0;
            top_shift_1 <= 0;
            top_shift_2 <= 0;
            mid_shift_0 <= 0;
            mid_shift_1 <= 0;
            mid_shift_2 <= 0;
            bot_shift_0 <= 0;
            bot_shift_1 <= 0;
            bot_shift_2 <= 0;

            pending_vsync <= 1'b0;
            pending_hsync <= 1'b0;
            pending_href  <= 1'b0;
            pending_window_valid <= 1'b0;

            p00 <= 0; p01 <= 0; p02 <= 0;
            p10 <= 0; p11 <= 0; p12 <= 0;
            p20 <= 0; p21 <= 0; p22 <= 0;
            out_vsync <= 0;
            out_hsync <= 0;
            out_href  <= 0;
            window_valid <= 0;
        end else begin
            // Emit all window and timing signals from the same delayed stage.
            out_vsync    <= pending_vsync;
            out_hsync    <= pending_hsync;
            out_href     <= pending_href;
            window_valid <= pending_window_valid;

            if (pending_window_valid) begin
                p00 <= top_shift_1;
                p01 <= top_shift_2;
                p02 <= top_read_q;
                p10 <= mid_shift_1;
                p11 <= mid_shift_2;
                p12 <= mid_read_q;
                p20 <= bot_shift_1;
                p21 <= bot_shift_2;
                p22 <= gray_data_q;
            end else begin
                p00 <= 0; p01 <= 0; p02 <= 0;
                p10 <= 0; p11 <= 0; p12 <= 0;
                p20 <= 0; p21 <= 0; p22 <= 0;
            end

            // Capture current timing metadata for the common one-cycle delay.
            pending_vsync <= in_vsync;
            pending_hsync <= in_hsync;
            pending_href  <= in_href;

            if (!in_href) begin
                // An href gap ends the row and resets the next column to zero.
                if (previous_href) begin
                    row_count  <= row_count + 1;
                    write_bank <= ~write_bank;
                end
                column_count <= 0;
                previous_href <= 1'b0;

                top_read_q  <= 0;
                mid_read_q  <= 0;
                gray_data_q <= 0;
                top_shift_0 <= 0;
                top_shift_1 <= 0;
                top_shift_2 <= 0;
                mid_shift_0 <= 0;
                mid_shift_1 <= 0;
                mid_shift_2 <= 0;
                bot_shift_0 <= 0;
                bot_shift_1 <= 0;
                bot_shift_2 <= 0;
                pending_window_valid <= 1'b0;
            end else begin
                previous_href <= 1'b1;

                // One synchronous read from each history row at this column.
                if (!write_bank) begin
                    top_read_q <= line_buffer_0[column_count];
                    mid_read_q <= line_buffer_1[column_count];
                    line_buffer_0[column_count] <= gray_data;
                end else begin
                    top_read_q <= line_buffer_1[column_count];
                    mid_read_q <= line_buffer_0[column_count];
                    line_buffer_1[column_count] <= gray_data;
                end
                gray_data_q <= gray_data;

                // Shift the delayed row data and delayed current-row pixels.
                top_shift_0 <= top_shift_1;
                top_shift_1 <= top_shift_2;
                top_shift_2 <= top_read_q;
                mid_shift_0 <= mid_shift_1;
                mid_shift_1 <= mid_shift_2;
                mid_shift_2 <= mid_read_q;
                bot_shift_0 <= bot_shift_1;
                bot_shift_1 <= bot_shift_2;
                bot_shift_2 <= gray_data_q;

                // Two complete previous rows and two previous columns are needed.
                pending_window_valid <= (row_count >= 2) && (column_count >= 2);

                if (column_count < IMAGE_WIDTH - 1)
                    column_count <= column_count + 1;
                else
                    column_count <= 0;
            end
        end
    end

endmodule
