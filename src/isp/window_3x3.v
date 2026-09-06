// Registered 3x3 window generator using three synchronous line buffers.
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

    // Three RAMs rotate by row: one current-row write and two history reads.
    reg [7:0] line_buffer_0 [0:IMAGE_WIDTH-1];
    reg [7:0] line_buffer_1 [0:IMAGE_WIDTH-1];
    reg [7:0] line_buffer_2 [0:IMAGE_WIDTH-1];

    // Synchronous RAM read results and the delayed current-row pixel.
    reg [7:0] top_read_q;
    reg [7:0] mid_read_q;
    reg [7:0] gray_data_q;

    // Horizontal history for the top, middle, and current rows.
    reg [7:0] top_shift_0, top_shift_1, top_shift_2;
    reg [7:0] mid_shift_0, mid_shift_1, mid_shift_2;
    reg [7:0] bot_shift_0, bot_shift_1, bot_shift_2;

    reg [31:0] column_count;
    reg [31:0] row_count;
    reg        previous_href;
    reg [1:0]  row_phase;

    // Timing and validity metadata share the same one-cycle pipeline.
    reg        pending_vsync;
    reg        pending_hsync;
    reg        pending_href;
    reg        pending_window_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            column_count  <= 0;
            row_count     <= 0;
            previous_href <= 1'b0;
            row_phase     <= 2'd0;

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
            // Low VSYNC is the frame-sync/vertical-blank interval in this project.
            column_count  <= 0;
            row_count     <= 0;
            previous_href <= 1'b0;
            row_phase     <= 2'd0;

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
            // Emit all window data and timing from the same delayed stage.
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

            // Timing metadata is delayed exactly like the RAM data.
            pending_vsync <= in_vsync;
            pending_hsync <= in_hsync;
            pending_href  <= in_href;

            if (!in_href) begin
                // An href gap ends a row and starts the next at column zero.
                if (previous_href) begin
                    row_count <= row_count + 1;
                    if (row_phase == 2'd2)
                        row_phase <= 2'd0;
                    else
                        row_phase <= row_phase + 1'b1;
                end
                column_count  <= 0;
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

                // Phase 0: write RAM0, read top RAM1 and middle RAM2.
                // Phase 1: write RAM1, read top RAM2 and middle RAM0.
                // Phase 2: write RAM2, read top RAM0 and middle RAM1.
                case (row_phase)
                    2'd0: begin
                        top_read_q <= line_buffer_1[column_count];
                        mid_read_q <= line_buffer_2[column_count];
                        line_buffer_0[column_count] <= gray_data;
                    end
                    2'd1: begin
                        top_read_q <= line_buffer_2[column_count];
                        mid_read_q <= line_buffer_0[column_count];
                        line_buffer_1[column_count] <= gray_data;
                    end
                    default: begin
                        top_read_q <= line_buffer_0[column_count];
                        mid_read_q <= line_buffer_1[column_count];
                        line_buffer_2[column_count] <= gray_data;
                    end
                endcase
                gray_data_q <= gray_data;

                // Shift the delayed top, middle, and current row samples.
                top_shift_0 <= top_shift_1;
                top_shift_1 <= top_shift_2;
                top_shift_2 <= top_read_q;
                mid_shift_0 <= mid_shift_1;
                mid_shift_1 <= mid_shift_2;
                mid_shift_2 <= mid_read_q;
                bot_shift_0 <= bot_shift_1;
                bot_shift_1 <= bot_shift_2;
                bot_shift_2 <= gray_data_q;

                // Two complete rows and two previous columns are required.
                pending_window_valid <= (row_count >= 2) && (column_count >= 2);

                if (column_count < IMAGE_WIDTH - 1)
                    column_count <= column_count + 1;
                else
                    column_count <= 0;
            end
        end
    end

endmodule
