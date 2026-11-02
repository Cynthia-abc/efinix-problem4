 
 
 
 
 
 
 
module shape_multi_candidate_adapter #(
    parameter integer IMAGE_WIDTH = 1920,
    parameter integer IMAGE_HEIGHT = 1080,
    parameter integer POOL = 4,
    parameter integer TOP_K = 3,
    parameter integer MAX_RUNS_PER_ROW = 96,
    parameter integer MAX_LABELS = 96
) (
    input                    clk,
    input                    rst_n,
    input                    in_vsync,
    input                    in_href,
    input                    edge_valid,
    input      [7:0]         edge_data,
    output                   record_valid,
    output                   record_last,
    output [$clog2(TOP_K)-1:0] record_index,
    output [$clog2(MAX_LABELS)-1:0] record_label,
    output [31:0]            record_edge_count,
    output [10:0]            record_x_min,
    output [10:0]            record_x_max,
    output [10:0]            record_y_min,
    output [10:0]            record_y_max,
    output [31:0]            record_aspect_ratio_x1000,
    output                   records_done,
    output                   ccl_overflow
);
    localparam integer GRID_WIDTH = IMAGE_WIDTH / POOL;
    localparam integer GRID_HEIGHT = IMAGE_HEIGHT / POOL;
    localparam integer GX_WIDTH = (GRID_WIDTH <= 2) ? 1 : $clog2(GRID_WIDTH);
    localparam integer GY_WIDTH = (GRID_HEIGHT <= 2) ? 1 : $clog2(GRID_HEIGHT);
    localparam integer POOL_SHIFT = (POOL <= 1) ? 0 : $clog2(POOL);

    reg [10:0] pixel_x, pixel_y;
    reg href_d, vsync_d;
    reg horizontal_or;
    reg [4:0] horizontal_count;
    reg [GRID_WIDTH-1:0] vertical_or;
    reg [4:0] vertical_count [0:GRID_WIDTH-1];
    reg grid_valid_r, grid_edge_r, grid_row_last_r, grid_frame_last_r;
    reg [4:0] grid_edge_weight_r;
    reg [GX_WIDTH-1:0] grid_x_r;
    reg [GY_WIDTH-1:0] grid_y_r;
    wire edge_bit = edge_valid && (edge_data == 8'hff);
    wire horizontal_value = horizontal_or || edge_bit;
    wire [4:0] horizontal_count_value = horizontal_count + edge_bit;
    wire [GX_WIDTH-1:0] current_grid_x = pixel_x >> POOL_SHIFT;
    wire [GY_WIDTH-1:0] current_grid_y = pixel_y >> POOL_SHIFT;
    wire cell_edge = ((pixel_y % POOL) == 0) ?
                     horizontal_value :
                     (vertical_or[current_grid_x] || horizontal_value);
    wire [4:0] cell_weight = ((pixel_y % POOL) == 0) ?
                              horizontal_count_value :
                              (vertical_count[current_grid_x] +
                               horizontal_count_value);

    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_x <= 0;
            pixel_y <= 0;
            href_d <= 1'b0;
            vsync_d <= 1'b0;
            horizontal_or <= 1'b0;
            horizontal_count <= 0;
            vertical_or <= 0;
            for (k = 0; k < GRID_WIDTH; k = k + 1)
                vertical_count[k] <= 0;
            grid_valid_r <= 1'b0;
            grid_edge_r <= 1'b0;
            grid_edge_weight_r <= 0;
            grid_row_last_r <= 1'b0;
            grid_frame_last_r <= 1'b0;
            grid_x_r <= 0;
            grid_y_r <= 0;
        end else begin
            href_d <= in_href;
            vsync_d <= in_vsync;
            grid_valid_r <= 1'b0;
            grid_row_last_r <= 1'b0;
            grid_frame_last_r <= 1'b0;

            if (!in_vsync) begin
                pixel_x <= 0;
                pixel_y <= 0;
                horizontal_or <= 1'b0;
                horizontal_count <= 0;
            end else if (in_href) begin
                if (pixel_x == IMAGE_WIDTH-1)
                    pixel_x <= 0;
                else
                    pixel_x <= pixel_x + 1'b1;

                if (((pixel_x % POOL) == POOL-1) &&
                    ((pixel_y % POOL) == POOL-1)) begin
                     
                    grid_valid_r <= 1'b1;
                    grid_edge_r <= cell_edge;
                    grid_edge_weight_r <= cell_weight;
                    grid_x_r <= current_grid_x;
                    grid_y_r <= current_grid_y;
                    grid_row_last_r <= (current_grid_x == GRID_WIDTH-1);
                    grid_frame_last_r <= (current_grid_x == GRID_WIDTH-1) &&
                                         (current_grid_y == GRID_HEIGHT-1);
                    vertical_or[current_grid_x] <= cell_edge;
                    vertical_count[current_grid_x] <= cell_weight;
                    horizontal_or <= 1'b0;
                    horizontal_count <= 0;
                end else if ((pixel_x % POOL) == POOL-1) begin
                    vertical_or[current_grid_x] <= cell_edge;
                    vertical_count[current_grid_x] <= cell_weight;
                    horizontal_or <= 1'b0;
                    horizontal_count <= 0;
                end else if ((pixel_x % POOL) == 0) begin
                    horizontal_or <= edge_bit;
                    horizontal_count <= edge_bit;
                end else begin
                    horizontal_or <= horizontal_value;
                    horizontal_count <= horizontal_count_value;
                end
            end else if (href_d) begin
                pixel_x <= 0;
                if (pixel_y == IMAGE_HEIGHT-1)
                    pixel_y <= 0;
                else
                    pixel_y <= pixel_y + 1'b1;
                horizontal_or <= 1'b0;
                horizontal_count <= 0;
            end
        end
    end

    wire run_valid, row_done, frame_done_i;
    wire [GX_WIDTH-1:0] run_x_start, run_x_end;
    wire [GY_WIDTH-1:0] run_y;
    wire [31:0] run_weight;
    shape_grid_run_encoder #(.X_WIDTH(GX_WIDTH), .Y_WIDTH(GY_WIDTH)) u_encoder (
        .clk(clk), .rst_n(rst_n), .grid_valid(grid_valid_r),
        .grid_edge(grid_edge_r), .grid_row_last(grid_row_last_r),
        .grid_frame_last(grid_frame_last_r), .grid_edge_weight(grid_edge_weight_r),
        .grid_x(grid_x_r), .grid_y(grid_y_r),
        .run_valid(run_valid), .run_x_start(run_x_start), .run_x_end(run_x_end),
        .run_y(run_y), .run_weight(run_weight),
        .row_done(row_done), .frame_done_i(frame_done_i)
    );

    shape_run_ccl_topk #(
        .MAX_RUNS_PER_ROW(MAX_RUNS_PER_ROW),
        .MAX_LABELS(MAX_LABELS), .TOP_K(TOP_K),
        .X_WIDTH(GX_WIDTH), .Y_WIDTH(GY_WIDTH)
    ) u_topk (
        .clk(clk), .rst_n(rst_n), .run_valid(run_valid),
        .run_x_start(run_x_start), .run_x_end(run_x_end), .run_y(run_y),
        .run_weight(run_weight),
        .row_done(row_done), .frame_done_i(frame_done_i),
        .record_valid(record_valid), .record_last(record_last),
        .record_index(record_index), .record_label(record_label),
        .record_edge_count(record_edge_count), .record_x_min(record_x_min_grid),
        .record_x_max(record_x_max_grid), .record_y_min(record_y_min_grid),
        .record_y_max(record_y_max_grid),
        .record_aspect_ratio_x1000(record_aspect_ratio_x1000),
        .records_done(records_done), .overflow(ccl_overflow)
    );
    wire [GX_WIDTH-1:0] record_x_min_grid, record_x_max_grid;
    wire [GY_WIDTH-1:0] record_y_min_grid, record_y_max_grid;
    assign record_x_min = {{(11-GX_WIDTH){1'b0}}, record_x_min_grid} << 2;
    assign record_x_max = ({{(11-GX_WIDTH){1'b0}}, record_x_max_grid} << 2) + 11'd3;
    assign record_y_min = {{(11-GY_WIDTH){1'b0}}, record_y_min_grid} << 2;
    assign record_y_max = ({{(11-GY_WIDTH){1'b0}}, record_y_max_grid} << 2) + 11'd3;
endmodule
