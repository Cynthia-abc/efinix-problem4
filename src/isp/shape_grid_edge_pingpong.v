 
 
 
 
 
module shape_grid_bit_ram #(
    parameter integer MEM_DEPTH = 129600,
    parameter integer ADDR_WIDTH = 17
) (
    input                    clk,
    input                    wr_en,
    input      [ADDR_WIDTH-1:0] wr_addr,
    input                    wr_data,
    input                    rd_en,
    input      [ADDR_WIDTH-1:0] rd_addr,
    output reg               rd_data
);
    reg mem [0:MEM_DEPTH-1];
    always @(posedge clk) begin
        if (wr_en) mem[wr_addr] <= wr_data;
        if (rd_en) rd_data <= mem[rd_addr];
    end
endmodule

module shape_grid_edge_pingpong #(
    parameter integer GRID_WIDTH = 480,
    parameter integer GRID_HEIGHT = 270,
    parameter integer X_WIDTH = 9,
    parameter integer Y_WIDTH = 9,
    parameter integer ADDR_WIDTH = 17
) (
    input                    clk,
    input                    rst_n,
    input                    grid_valid,
    input                    capture_enable,
    input                    write_buffer,
    input                    grid_edge,
    input      [X_WIDTH-1:0] grid_x,
    input      [Y_WIDTH-1:0] grid_y,
    input                    process_buffer,
    input                    replay_start,
    input      [X_WIDTH-1:0] replay_x_min_i,
    input      [X_WIDTH-1:0] replay_x_max_i,
    input      [Y_WIDTH-1:0] replay_y_min_i,
    input      [Y_WIDTH-1:0] replay_y_max_i,
    output reg               replay_valid,
    output reg               replay_edge,
    output reg [X_WIDTH-1:0] replay_x,
    output reg [Y_WIDTH-1:0] replay_y,
    output reg               replay_done,
    input                    random_read_req,
    input      [X_WIDTH-1:0] random_read_x,
    input      [Y_WIDTH-1:0] random_read_y,
    output reg               random_read_valid,
    output reg               random_read_data
);
    localparam integer MEM_DEPTH = GRID_WIDTH * GRID_HEIGHT;
    localparam [1:0] ST_IDLE = 2'd0, ST_REPLAY = 2'd1;
    reg [1:0] state;
    reg [X_WIDTH-1:0] replay_x_min, replay_x_max, work_x;
    reg [Y_WIDTH-1:0] replay_y_min, replay_y_max, work_y;
    reg random_process_buffer;
    reg random_pending;
    reg random_response_pending;
    reg [ADDR_WIDTH-1:0] random_addr;
    reg random_addr_valid;
    reg replay_pending, replay_pending_last;
    reg [X_WIDTH-1:0] replay_pending_x;
    reg [Y_WIDTH-1:0] replay_pending_y;
    reg bank0_rd_data, bank1_rd_data;
    integer write_addr;
    integer replay_addr;

    wire [ADDR_WIDTH-1:0] capture_addr = grid_y * GRID_WIDTH + grid_x;
    wire [ADDR_WIDTH-1:0] current_replay_addr =
        work_y * GRID_WIDTH + work_x;
    wire [ADDR_WIDTH-1:0] selected_replay_addr =
        random_process_buffer ? current_replay_addr : current_replay_addr;

    shape_grid_bit_ram #(.MEM_DEPTH(MEM_DEPTH), .ADDR_WIDTH(ADDR_WIDTH))
    u_bank0 (
        .clk(clk), .wr_en(capture_enable && grid_valid && !write_buffer),
        .wr_addr(capture_addr), .wr_data(grid_edge),
        .rd_en((((state == ST_REPLAY) && !replay_pending) || random_pending) &&
               !random_process_buffer),
        .rd_addr(random_pending ? random_addr : current_replay_addr),
        .rd_data(bank0_rd_data)
    );
    shape_grid_bit_ram #(.MEM_DEPTH(MEM_DEPTH), .ADDR_WIDTH(ADDR_WIDTH))
    u_bank1 (
        .clk(clk), .wr_en(capture_enable && grid_valid && write_buffer),
        .wr_addr(capture_addr), .wr_data(grid_edge),
        .rd_en((((state == ST_REPLAY) && !replay_pending) || random_pending) &&
               random_process_buffer),
        .rd_addr(random_pending ? random_addr : current_replay_addr),
        .rd_data(bank1_rd_data)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            replay_x_min <= 0; replay_x_max <= 0;
            replay_y_min <= 0; replay_y_max <= 0;
            work_x <= 0; work_y <= 0;
            random_process_buffer <= 0;
            replay_valid <= 0; replay_edge <= 0;
            replay_x <= 0; replay_y <= 0; replay_done <= 0;
            random_pending <= 0; random_addr <= 0; random_addr_valid <= 0;
            random_response_pending <= 1'b0;
            replay_pending <= 1'b0;
            replay_pending_last <= 1'b0;
            replay_pending_x <= 0;
            replay_pending_y <= 0;
            random_read_valid <= 0; random_read_data <= 0;
        end else begin
            replay_valid <= 1'b0;
            replay_done <= 1'b0;
            random_read_valid <= 1'b0;

            if (random_pending) begin
                random_pending <= 1'b0;
                random_response_pending <= 1'b1;
            end
            if (random_response_pending) begin
                random_read_valid <= random_addr_valid;
                random_read_data <= random_process_buffer ? bank1_rd_data : bank0_rd_data;
                random_response_pending <= 1'b0;
            end
            if (random_read_req) begin
                random_pending <= 1'b1;
                if ((random_read_x < GRID_WIDTH) &&
                    (random_read_y < GRID_HEIGHT)) begin
                    random_addr <= random_read_y * GRID_WIDTH + random_read_x;
                    random_addr_valid <= 1'b1;
                end else begin
                    random_addr <= 0;
                    random_addr_valid <= 1'b0;
                end
            end

            if (replay_pending) begin
                replay_valid <= 1'b1;
                replay_edge <= process_buffer ? bank1_rd_data : bank0_rd_data;
                replay_x <= replay_pending_x;
                replay_y <= replay_pending_y;
                replay_pending <= 1'b0;
                if (replay_pending_last) begin
                    replay_done <= 1'b1;
                    state <= ST_IDLE;
                end
            end

            if (replay_start) begin
                replay_x_min <= (replay_x_min_i >= GRID_WIDTH) ? GRID_WIDTH-1 : replay_x_min_i;
                replay_x_max <= (replay_x_max_i >= GRID_WIDTH) ? GRID_WIDTH-1 : replay_x_max_i;
                replay_y_min <= (replay_y_min_i >= GRID_HEIGHT) ? GRID_HEIGHT-1 : replay_y_min_i;
                replay_y_max <= (replay_y_max_i >= GRID_HEIGHT) ? GRID_HEIGHT-1 : replay_y_max_i;
                work_x <= (replay_x_min_i >= GRID_WIDTH) ? GRID_WIDTH-1 : replay_x_min_i;
                work_y <= (replay_y_min_i >= GRID_HEIGHT) ? GRID_HEIGHT-1 : replay_y_min_i;
                random_process_buffer <= process_buffer;
                state <= ST_REPLAY;
            end else if ((state == ST_REPLAY) && !replay_pending) begin
                replay_pending <= 1'b1;
                replay_pending_x <= work_x;
                replay_pending_y <= work_y;
                replay_pending_last <= (work_x >= replay_x_max) &&
                                        (work_y >= replay_y_max);
                if (work_x >= replay_x_max) begin
                    work_x <= replay_x_min;
                    if (work_y >= replay_y_max) begin
                         
                         
                    end else begin
                        work_y <= work_y + 1'b1;
                    end
                end else begin
                    work_x <= work_x + 1'b1;
                end
            end
        end
    end
endmodule
