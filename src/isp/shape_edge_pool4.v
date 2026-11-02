 
 
 
 
 
 
module shape_edge_pool4 #(
    parameter integer IMAGE_WIDTH = 1920,
    parameter integer IMAGE_HEIGHT = 1080,
    parameter integer POOL = 4
) (
    input                    clk,
    input                    rst_n,
    input                    in_vsync,
    input                    in_href,
    input                    edge_valid,
    input      [7:0]         edge_data,
    output reg               grid_valid,
    output reg               grid_edge,
    output reg [4:0]         grid_edge_weight,
    output reg               grid_row_last,
    output reg               grid_frame_last,
    output reg [((IMAGE_WIDTH/POOL <= 2) ? 1 : $clog2(IMAGE_WIDTH/POOL))-1:0] grid_x,
    output reg [((IMAGE_HEIGHT/POOL <= 2) ? 1 : $clog2(IMAGE_HEIGHT/POOL))-1:0] grid_y
);
    localparam integer GRID_WIDTH = IMAGE_WIDTH / POOL;
    localparam integer GRID_HEIGHT = IMAGE_HEIGHT / POOL;
    localparam integer XW = (GRID_WIDTH <= 2) ? 1 : $clog2(GRID_WIDTH);
    localparam integer YW = (GRID_HEIGHT <= 2) ? 1 : $clog2(GRID_HEIGHT);
    localparam integer POOL_SHIFT = (POOL <= 1) ? 0 : $clog2(POOL);
    reg [10:0] pixel_x, pixel_y;
    reg href_d;
    reg horizontal_or;
    reg [4:0] horizontal_count;
    reg [GRID_WIDTH-1:0] vertical_or;
    reg [4:0] vertical_count [0:GRID_WIDTH-1];
    wire edge_bit = edge_valid && (edge_data == 8'hff);
    wire horizontal_value = horizontal_or || edge_bit;
    wire [4:0] horizontal_count_value = horizontal_count + edge_bit;
    wire [XW-1:0] current_grid_x = pixel_x >> POOL_SHIFT;
    wire [YW-1:0] current_grid_y = pixel_y >> POOL_SHIFT;
    wire first_row_in_block = ((pixel_y % POOL) == 0);
    wire cell_edge = first_row_in_block ? horizontal_value :
                     (vertical_or[current_grid_x] || horizontal_value);
    wire [4:0] cell_weight = first_row_in_block ? horizontal_count_value :
                              (vertical_count[current_grid_x] +
                               horizontal_count_value);
    integer k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_x <= 0; pixel_y <= 0; href_d <= 0;
            horizontal_or <= 0; horizontal_count <= 0;
            vertical_or <= 0;
            for (k = 0; k < GRID_WIDTH; k = k + 1)
                vertical_count[k] <= 0;
            grid_valid <= 0; grid_edge <= 0; grid_edge_weight <= 0;
            grid_row_last <= 0; grid_frame_last <= 0;
            grid_x <= 0; grid_y <= 0;
        end else begin
            href_d <= in_href;
            grid_valid <= 1'b0;
            grid_row_last <= 1'b0;
            grid_frame_last <= 1'b0;
            if (!in_vsync) begin
                pixel_x <= 0; pixel_y <= 0;
                horizontal_or <= 0; horizontal_count <= 0;
            end else if (in_href) begin
                if (pixel_x == IMAGE_WIDTH-1) pixel_x <= 0;
                else pixel_x <= pixel_x + 1'b1;
                if (((pixel_x % POOL) == POOL-1) &&
                    ((pixel_y % POOL) == POOL-1)) begin
                    grid_valid <= 1'b1;
                    grid_edge <= cell_edge;
                    grid_edge_weight <= cell_weight;
                    grid_x <= current_grid_x;
                    grid_y <= current_grid_y;
                    grid_row_last <= (current_grid_x == GRID_WIDTH-1);
                    grid_frame_last <= (current_grid_x == GRID_WIDTH-1) &&
                                       (current_grid_y == GRID_HEIGHT-1);
                    vertical_or[current_grid_x] <= cell_edge;
                    vertical_count[current_grid_x] <= cell_weight;
                    horizontal_or <= 0;
                    horizontal_count <= 0;
                end else if ((pixel_x % POOL) == POOL-1) begin
                    vertical_or[current_grid_x] <= cell_edge;
                    vertical_count[current_grid_x] <= cell_weight;
                    horizontal_or <= 0;
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
                if (pixel_y == IMAGE_HEIGHT-1) pixel_y <= 0;
                else pixel_y <= pixel_y + 1'b1;
                horizontal_or <= 0;
                horizontal_count <= 0;
            end
        end
    end
endmodule
