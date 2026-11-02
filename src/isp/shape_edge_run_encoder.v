 
 
 
 
 
 
module shape_edge_run_encoder #(
    parameter integer X_WIDTH = 11,
    parameter integer Y_WIDTH = 11
) (
    input                    clk,
    input                    rst_n,
    input                    in_vsync,
    input                    in_href,
    input                    edge_pixel,
    input      [X_WIDTH-1:0] pixel_x,
    input      [Y_WIDTH-1:0] pixel_y,
    output reg               run_valid,
    output reg [X_WIDTH-1:0] run_x_start,
    output reg [X_WIDTH-1:0] run_x_end,
    output reg [Y_WIDTH-1:0] run_y,
    output reg               row_done,
    output reg               frame_done_i
);
    reg previous_href;
    reg previous_vsync;
    reg run_active;
    reg [X_WIDTH-1:0] work_start;
    reg [X_WIDTH-1:0] work_end;
    reg [Y_WIDTH-1:0] work_y;
    reg row_done_pending;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            previous_href <= 1'b0;
            previous_vsync <= 1'b0;
            run_active <= 1'b0;
            work_start <= 0;
            work_end <= 0;
            work_y <= 0;
            row_done_pending <= 1'b0;
            run_valid <= 1'b0;
            run_x_start <= 0;
            run_x_end <= 0;
            run_y <= 0;
            row_done <= 1'b0;
            frame_done_i <= 1'b0;
        end else begin
            previous_href <= in_href;
            previous_vsync <= in_vsync;
            run_valid <= 1'b0;
            row_done <= 1'b0;
            frame_done_i <= 1'b0;

            if (row_done_pending) begin
                row_done <= 1'b1;
                row_done_pending <= 1'b0;
            end
            if (previous_vsync && !in_vsync)
                frame_done_i <= 1'b1;

            if (in_vsync && in_href) begin
                if (edge_pixel) begin
                    if (!run_active) begin
                        run_active <= 1'b1;
                        work_start <= pixel_x;
                        work_end <= pixel_x;
                        work_y <= pixel_y;
                    end else if (pixel_x == (work_end + 1'b1)) begin
                        work_end <= pixel_x;
                    end else begin
                         
                         
                        run_valid <= 1'b1;
                        run_x_start <= work_start;
                        run_x_end <= work_end;
                        run_y <= work_y;
                        work_start <= pixel_x;
                        work_end <= pixel_x;
                        work_y <= pixel_y;
                    end
                end else if (run_active) begin
                    run_valid <= 1'b1;
                    run_x_start <= work_start;
                    run_x_end <= work_end;
                    run_y <= work_y;
                    run_active <= 1'b0;
                end
            end

            if (previous_href && !in_href) begin
                if (run_active) begin
                    run_valid <= 1'b1;
                    run_x_start <= work_start;
                    run_x_end <= work_end;
                    run_y <= work_y;
                    run_active <= 1'b0;
                end
                row_done_pending <= 1'b1;
            end
        end
    end
endmodule
