 
 
 
 
 
 
 
 
 
 
module shape_moore_contour_tracker #(
    parameter integer X_WIDTH = 11,
    parameter integer Y_WIDTH = 11,
    parameter integer MAX_CONTOUR_STEPS = 65536
) (
    input                    clk,
    input                    rst_n,
    input                    replay_start,
    input                    replay_valid,
    input                    replay_edge,
    input      [X_WIDTH-1:0] replay_x,
    input      [Y_WIDTH-1:0] replay_y,
    input                    replay_done,
    output reg               random_read_req,
    output reg [X_WIDTH-1:0] random_read_x,
    output reg [Y_WIDTH-1:0] random_read_y,
    input                    random_read_valid,
    input                    random_read_data,
    output reg               contour_start,
    output reg               contour_step_valid,
    output reg [X_WIDTH-1:0] contour_point_x,
    output reg [Y_WIDTH-1:0] contour_point_y,
    output reg [2:0]         contour_direction,
    output reg               contour_done,
    output reg               contour_valid,
    output reg [31:0]        contour_steps
);
    localparam [2:0] ST_IDLE = 3'd0;
    localparam [2:0] ST_SCAN = 3'd1;
     
     
     
    localparam [2:0] ST_WAIT_REPLAY = 3'd2;
    localparam [2:0] ST_READ_REQ = 3'd3;
    localparam [2:0] ST_READ_WAIT = 3'd4;
    localparam [2:0] ST_FINISH = 3'd5;

    reg [2:0] state;
    reg found_start;
    reg [X_WIDTH-1:0] start_x, current_x, back_x;
    reg [Y_WIDTH-1:0] start_y, current_y, back_y;
    reg [X_WIDTH-1:0] start_back_x;
    reg [Y_WIDTH-1:0] start_back_y;
    reg [2:0] back_direction;
    reg [2:0] search_offset;
    reg [2:0] search_direction;
    reg [31:0] steps;

    integer signed dx;
    integer signed dy;
    integer signed dir_x;
    integer signed dir_y;

    function automatic [2:0] add_direction;
        input [2:0] base;
        input [2:0] offset;
        integer sum;
        begin
            sum = base + offset;
            if (sum >= 8) sum = sum - 8;
            add_direction = sum[2:0];
        end
    endfunction

    task automatic direction_delta;
        input [2:0] d;
        begin
            dir_x = 0;
            dir_y = 0;
            case (d)
                3'd0: dir_x = 1;
                3'd1: begin dir_x = 1; dir_y = 1; end
                3'd2: dir_y = 1;
                3'd3: begin dir_x = -1; dir_y = 1; end
                3'd4: dir_x = -1;
                3'd5: begin dir_x = -1; dir_y = -1; end
                3'd6: dir_y = -1;
                default: begin dir_x = 1; dir_y = -1; end
            endcase
        end
    endtask

    function automatic [2:0] direction_between;
        input [X_WIDTH-1:0] from_x;
        input [Y_WIDTH-1:0] from_y;
        input [X_WIDTH-1:0] to_x;
        input [Y_WIDTH-1:0] to_y;
        integer signed ddx;
        integer signed ddy;
        begin
            ddx = to_x - from_x;
            ddy = to_y - from_y;
            if (ddx > 0 && ddy == 0) direction_between = 3'd0;
            else if (ddx > 0 && ddy > 0) direction_between = 3'd1;
            else if (ddx == 0 && ddy > 0) direction_between = 3'd2;
            else if (ddx < 0 && ddy > 0) direction_between = 3'd3;
            else if (ddx < 0 && ddy == 0) direction_between = 3'd4;
            else if (ddx < 0 && ddy < 0) direction_between = 3'd5;
            else if (ddx == 0 && ddy < 0) direction_between = 3'd6;
            else direction_between = 3'd7;
        end
    endfunction

    wire at_start = found_start && (current_x == start_x) &&
                    (current_y == start_y) &&
                    (back_x == start_back_x) &&
                    (back_y == start_back_y) && (steps != 0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            found_start <= 1'b0;
            start_x <= 0; start_y <= 0;
            start_back_x <= 0; start_back_y <= 0;
            current_x <= 0; current_y <= 0;
            back_x <= 0; back_y <= 0;
            back_direction <= 0;
            search_offset <= 0;
            search_direction <= 0;
            steps <= 0;
            random_read_req <= 1'b0;
            random_read_x <= 0; random_read_y <= 0;
            contour_start <= 1'b0;
            contour_step_valid <= 1'b0;
            contour_point_x <= 0;
            contour_point_y <= 0;
            contour_direction <= 0;
            contour_done <= 1'b0;
            contour_valid <= 1'b0;
            contour_steps <= 0;
        end else begin
            random_read_req <= 1'b0;
            contour_start <= 1'b0;
            contour_step_valid <= 1'b0;
            contour_done <= 1'b0;

            if (replay_start) begin
                state <= ST_SCAN;
                found_start <= 1'b0;
                steps <= 0;
                contour_valid <= 1'b0;
                contour_steps <= 0;
            end

            case (state)
                ST_IDLE: begin end
                ST_SCAN: begin
                    if (replay_valid && replay_edge && !found_start) begin
                        found_start <= 1'b1;
                        start_x <= replay_x;
                        start_y <= replay_y;
                         
                         
                        start_back_x <= replay_x - 1'b1;
                        start_back_y <= replay_y;
                        current_x <= replay_x;
                        current_y <= replay_y;
                        back_x <= replay_x - 1'b1;
                        back_y <= replay_y;
                        back_direction <= 3'd4;
                        contour_start <= 1'b1;
                        state <= ST_WAIT_REPLAY;
                    end else if (replay_done && !found_start) begin
                        contour_valid <= 1'b0;
                        contour_done <= 1'b1;
                        state <= ST_IDLE;
                    end
                end
                ST_WAIT_REPLAY: begin
                    if (replay_done)
                        state <= ST_READ_REQ;
                end
                ST_READ_REQ: begin
                    if (at_start || (steps >= MAX_CONTOUR_STEPS)) begin
                        state <= ST_FINISH;
                    end else begin
                        search_offset <= 0;
                        search_direction <= add_direction(back_direction, 3'd1);
                        direction_delta(add_direction(back_direction, 3'd1));
                        random_read_x <= current_x + dir_x;
                        random_read_y <= current_y + dir_y;
                        random_read_req <= 1'b1;
                        state <= ST_READ_WAIT;
                    end
                end
                ST_READ_WAIT: begin
                    if (random_read_valid) begin
                        if (random_read_data) begin
                             
                             
                             
                             
                             
                            if ((random_read_x == start_x) &&
                                (random_read_y == start_y) && (steps >= 3)) begin
                                state <= ST_FINISH;
                            end else begin
                             
                             
                            back_x <= current_x;
                            back_y <= current_y;
                             
                             
                             
                            back_direction <= direction_between(
                                random_read_x, random_read_y, current_x, current_y);
                            current_x <= random_read_x;
                            current_y <= random_read_y;
                            contour_step_valid <= 1'b1;
                            contour_point_x <= random_read_x;
                            contour_point_y <= random_read_y;
                            contour_direction <= direction_between(
                                current_x, current_y, random_read_x, random_read_y);
                            steps <= steps + 1'b1;
                            state <= ST_READ_REQ;
                            end
                        end else if (search_offset == 3'd7) begin
                            state <= ST_FINISH;
                        end else begin
                            search_offset <= search_offset + 1'b1;
                            search_direction <= add_direction(back_direction,
                                                              search_offset + 2);
                            direction_delta(add_direction(back_direction,
                                                          search_offset + 2));
                            random_read_x <= current_x + dir_x;
                            random_read_y <= current_y + dir_y;
                            random_read_req <= 1'b1;
                        end
                    end
                end
                ST_FINISH: begin
                    contour_done <= 1'b1;
                    contour_valid <= found_start && (steps < MAX_CONTOUR_STEPS);
                    contour_steps <= steps;
                    state <= ST_IDLE;
                end
                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
