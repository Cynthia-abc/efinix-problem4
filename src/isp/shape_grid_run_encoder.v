 
 
 
 
 
 
module shape_grid_run_encoder #(
    parameter integer X_WIDTH = 9,
    parameter integer Y_WIDTH = 9
) (
    input                    clk,
    input                    rst_n,
    input                    grid_valid,
    input                    grid_edge,
    input                    grid_row_last,
    input                    grid_frame_last,
    input      [4:0]         grid_edge_weight,
    input      [X_WIDTH-1:0] grid_x,
    input      [Y_WIDTH-1:0] grid_y,
    output reg               run_valid,
    output reg [X_WIDTH-1:0] run_x_start,
    output reg [X_WIDTH-1:0] run_x_end,
    output reg [Y_WIDTH-1:0] run_y,
    output reg [31:0]        run_weight,
    output reg               row_done,
    output reg               frame_done_i
);
    reg run_active;
    reg [X_WIDTH-1:0] work_start, work_end;
    reg [Y_WIDTH-1:0] work_y;
    reg [31:0] work_weight;
    reg row_done_pending;
    reg frame_done_pending;
    reg pending_run_valid;
    reg [X_WIDTH-1:0] pending_run_start, pending_run_end;
    reg [Y_WIDTH-1:0] pending_run_y;
    reg [31:0] pending_run_weight;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            run_active <= 1'b0;
            work_start <= 0;
            work_end <= 0;
            work_y <= 0;
            work_weight <= 0;
            row_done_pending <= 1'b0;
            frame_done_pending <= 1'b0;
            pending_run_valid <= 1'b0;
            pending_run_start <= 0;
            pending_run_end <= 0;
            pending_run_y <= 0;
            pending_run_weight <= 0;
            run_valid <= 1'b0;
            run_x_start <= 0;
            run_x_end <= 0;
            run_y <= 0;
            row_done <= 1'b0;
            frame_done_i <= 1'b0;
        end else begin
            run_valid <= 1'b0;
            row_done <= 1'b0;
            frame_done_i <= 1'b0;

            if (pending_run_valid) begin
                run_valid <= 1'b1;
                run_x_start <= pending_run_start;
                run_x_end <= pending_run_end;
                run_y <= pending_run_y;
                run_weight <= pending_run_weight;
                pending_run_valid <= 1'b0;
            end else if (row_done_pending) begin
                row_done <= 1'b1;
                row_done_pending <= 1'b0;
            end else if (frame_done_pending) begin
                frame_done_i <= 1'b1;
                frame_done_pending <= 1'b0;
            end

            if (grid_valid && !pending_run_valid && !row_done_pending &&
                !frame_done_pending) begin
                if (grid_edge) begin
                    if (!run_active) begin
                        if (grid_row_last) begin
                             
                             
                            run_valid <= 1'b1;
                            run_x_start <= grid_x;
                            run_x_end <= grid_x;
                            run_y <= grid_y;
                            run_weight <= {27'd0,grid_edge_weight};
                            row_done_pending <= 1'b1;
                            if (grid_frame_last)
                                frame_done_pending <= 1'b1;
                        end else begin
                            run_active <= 1'b1;
                            work_start <= grid_x;
                            work_end <= grid_x;
                            work_y <= grid_y;
                            work_weight <= {27'd0,grid_edge_weight};
                        end
                    end else if (grid_x == (work_end + 1'b1)) begin
                        if (grid_row_last) begin
                            run_valid <= 1'b1;
                            run_x_start <= work_start;
                            run_x_end <= grid_x;
                            run_y <= work_y;
                            run_weight <= work_weight + {27'd0,grid_edge_weight};
                            run_active <= 1'b0;
                            row_done_pending <= 1'b1;
                            if (grid_frame_last)
                                frame_done_pending <= 1'b1;
                        end else begin
                            work_end <= grid_x;
                            work_weight <= work_weight + {27'd0,grid_edge_weight};
                        end
                    end else begin
                         
                         
                        run_valid <= 1'b1;
                        run_x_start <= work_start;
                        run_x_end <= work_end;
                        run_y <= work_y;
                        run_weight <= work_weight;
                        if (grid_row_last) begin
                            pending_run_valid <= 1'b1;
                            pending_run_start <= grid_x;
                            pending_run_end <= grid_x;
                            pending_run_y <= grid_y;
                            pending_run_weight <= {27'd0,grid_edge_weight};
                            row_done_pending <= 1'b1;
                            if (grid_frame_last)
                                frame_done_pending <= 1'b1;
                            run_active <= 1'b0;
                        end else begin
                            work_start <= grid_x;
                            work_end <= grid_x;
                            work_y <= grid_y;
                            work_weight <= {27'd0,grid_edge_weight};
                        end
                    end
                end else if (run_active) begin
                    run_valid <= 1'b1;
                    run_x_start <= work_start;
                    run_x_end <= work_end;
                    run_y <= work_y;
                    run_weight <= work_weight;
                    run_active <= 1'b0;
                    if (grid_row_last) begin
                        row_done_pending <= 1'b1;
                        if (grid_frame_last)
                            frame_done_pending <= 1'b1;
                    end
                end else if (grid_row_last) begin
                    row_done_pending <= 1'b1;
                    if (grid_frame_last)
                        frame_done_pending <= 1'b1;
                end
            end

        end
    end
endmodule
