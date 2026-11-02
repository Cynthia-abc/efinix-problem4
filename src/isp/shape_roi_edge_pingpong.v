 
 
 
 

module shape_roi_bit_ram #(
    parameter integer MEM_DEPTH = 480000,
    parameter integer ADDR_WIDTH = 19
) (
    input                     clk,
    input                     wr_en,
    input      [ADDR_WIDTH-1:0] wr_addr,
    input                     wr_data,
    input                     rd_en,
    input      [ADDR_WIDTH-1:0] rd_addr,
    output reg                rd_data
);
    reg mem [0:MEM_DEPTH-1];
    always @(posedge clk) begin
        if (wr_en)
            mem[wr_addr] <= wr_data;
        if (rd_en)
            rd_data <= mem[rd_addr];
    end
endmodule

module shape_roi_edge_pingpong #(
    parameter integer ROI_X_MIN = 560,
    parameter integer ROI_Y_MIN = 240,
    parameter integer ROI_WIDTH  = 800,
    parameter integer ROI_HEIGHT = 600,
    parameter integer X_WIDTH = 11,
    parameter integer Y_WIDTH = 11,
    parameter integer ADDR_WIDTH = 19
) (
    input                    clk,
    input                    rst_n,
    input                    in_vsync,
    input                    in_href,
    input                    capture_enable,
    input                    write_buffer,
    input                    edge_pixel,
    input      [X_WIDTH-1:0] pixel_x,
    input      [Y_WIDTH-1:0] pixel_y,
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
    localparam integer MEM_DEPTH = ROI_WIDTH * ROI_HEIGHT;
    localparam [1:0] ST_IDLE = 2'd0, ST_REPLAY = 2'd1, ST_DRAIN = 2'd2;
    reg [1:0] state;
    reg [X_WIDTH-1:0] replay_x_min, replay_x_max;
    reg [Y_WIDTH-1:0] replay_y_min, replay_y_max;
    reg [X_WIDTH-1:0] work_x;
    reg [Y_WIDTH-1:0] work_y;
    reg random_process_buffer;
    reg replay_pending, replay_pending_last;
    reg [X_WIDTH-1:0] replay_pending_x;
    reg [Y_WIDTH-1:0] replay_pending_y;
    reg random_pending, random_response_pending;
    reg random_addr_valid;
    reg [ADDR_WIDTH-1:0] random_addr;

    wire capture_pixel = capture_enable && in_vsync && in_href &&
        (pixel_x >= ROI_X_MIN) && (pixel_x < ROI_X_MIN + ROI_WIDTH) &&
        (pixel_y >= ROI_Y_MIN) && (pixel_y < ROI_Y_MIN + ROI_HEIGHT);
    wire [ADDR_WIDTH-1:0] capture_addr =
        (pixel_y - ROI_Y_MIN) * ROI_WIDTH + (pixel_x - ROI_X_MIN);
    wire [ADDR_WIDTH-1:0] replay_addr =
        (work_y - ROI_Y_MIN) * ROI_WIDTH + (work_x - ROI_X_MIN);
    wire replay_rd_en = (state == ST_REPLAY);
    wire bank0_data, bank1_data;
    wire random_rd_en = random_pending && random_addr_valid;
    wire bank_read_en = replay_rd_en || random_rd_en;
    wire [ADDR_WIDTH-1:0] bank_read_addr = replay_rd_en ? replay_addr : random_addr;

     
     
     
    always @* begin
        random_read_valid = random_response_pending && random_addr_valid;
        random_read_data = random_process_buffer ? bank1_data : bank0_data;
    end

    shape_roi_bit_ram #(.MEM_DEPTH(MEM_DEPTH), .ADDR_WIDTH(ADDR_WIDTH))
    u_bank_ram0 (
        .clk(clk), .wr_en(capture_pixel && !write_buffer),
        .wr_addr(capture_addr), .wr_data(edge_pixel),
        .rd_en(bank_read_en && !random_process_buffer),
        .rd_addr(bank_read_addr), .rd_data(bank0_data)
    );
    shape_roi_bit_ram #(.MEM_DEPTH(MEM_DEPTH), .ADDR_WIDTH(ADDR_WIDTH))
    u_bank_ram1 (
        .clk(clk), .wr_en(capture_pixel && write_buffer),
        .wr_addr(capture_addr), .wr_data(edge_pixel),
        .rd_en(bank_read_en && random_process_buffer),
        .rd_addr(bank_read_addr), .rd_data(bank1_data)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            replay_x_min <= 0; replay_x_max <= 0;
            replay_y_min <= 0; replay_y_max <= 0;
            work_x <= 0; work_y <= 0;
            random_process_buffer <= 1'b0;
            replay_pending <= 1'b0; replay_pending_last <= 1'b0;
            replay_pending_x <= 0; replay_pending_y <= 0;
            replay_valid <= 1'b0; replay_edge <= 1'b0;
            replay_x <= 0; replay_y <= 0; replay_done <= 1'b0;
            random_pending <= 1'b0; random_response_pending <= 1'b0;
            random_addr_valid <= 1'b0; random_addr <= 0;
        end else begin
            replay_valid <= 1'b0;
            replay_done <= 1'b0;

            if (replay_pending) begin
                replay_valid <= 1'b1;
                replay_edge <= random_process_buffer ? bank1_data : bank0_data;
                replay_x <= replay_pending_x;
                replay_y <= replay_pending_y;
                replay_pending <= 1'b0;
                if (replay_pending_last) begin
                    replay_done <= 1'b1;
                    state <= ST_IDLE;
                end
            end

            if (random_pending) begin
                random_pending <= 1'b0;
                random_response_pending <= 1'b1;
            end
            if (random_response_pending) begin
                random_response_pending <= 1'b0;
            end
            if (random_read_req) begin
                random_pending <= 1'b1;
                if ((random_read_x >= ROI_X_MIN) &&
                    (random_read_x < ROI_X_MIN + ROI_WIDTH) &&
                    (random_read_y >= ROI_Y_MIN) &&
                    (random_read_y < ROI_Y_MIN + ROI_HEIGHT)) begin
                    random_addr <= (random_read_y - ROI_Y_MIN) * ROI_WIDTH +
                                   (random_read_x - ROI_X_MIN);
                    random_addr_valid <= 1'b1;
                end else begin
                    random_addr <= 0;
                    random_addr_valid <= 1'b0;
                end
            end

            if (replay_start) begin
                replay_x_min <= (replay_x_min_i < ROI_X_MIN) ? ROI_X_MIN : replay_x_min_i;
                replay_x_max <= (replay_x_max_i >= ROI_X_MIN + ROI_WIDTH) ? ROI_X_MIN + ROI_WIDTH - 1 : replay_x_max_i;
                replay_y_min <= (replay_y_min_i < ROI_Y_MIN) ? ROI_Y_MIN : replay_y_min_i;
                replay_y_max <= (replay_y_max_i >= ROI_Y_MIN + ROI_HEIGHT) ? ROI_Y_MIN + ROI_HEIGHT - 1 : replay_y_max_i;
                work_x <= (replay_x_min_i < ROI_X_MIN) ? ROI_X_MIN : replay_x_min_i;
                work_y <= (replay_y_min_i < ROI_Y_MIN) ? ROI_Y_MIN : replay_y_min_i;
                random_process_buffer <= process_buffer;
                replay_pending <= 1'b0;
                state <= ST_REPLAY;
            end else if (state == ST_REPLAY) begin
                replay_pending <= 1'b1;
                replay_pending_x <= work_x;
                replay_pending_y <= work_y;
                replay_pending_last <= (work_x >= replay_x_max) && (work_y >= replay_y_max);
                if (work_x >= replay_x_max) begin
                    work_x <= replay_x_min;
                    if (work_y >= replay_y_max)
                        state <= ST_DRAIN;
                    else
                        work_y <= work_y + 1'b1;
                end else begin
                    work_x <= work_x + 1'b1;
                end
            end
        end
    end
endmodule
