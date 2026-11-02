 
 
 
 
module stream_window_3x3 #(
    parameter IMAGE_WIDTH = 1920,
    parameter DATA_WIDTH = 8,
    parameter RAM_ADDR_WIDTH = 11
) (
    input                       clk,
    input                       rst_n,
    input      [DATA_WIDTH-1:0] in_data,
    input                       in_vsync,
    input                       in_hsync,
    input                       in_href,
    output reg [DATA_WIDTH-1:0] p00,
    output reg [DATA_WIDTH-1:0] p01,
    output reg [DATA_WIDTH-1:0] p02,
    output reg [DATA_WIDTH-1:0] p10,
    output reg [DATA_WIDTH-1:0] p11,
    output reg [DATA_WIDTH-1:0] p12,
    output reg [DATA_WIDTH-1:0] p20,
    output reg [DATA_WIDTH-1:0] p21,
    output reg [DATA_WIDTH-1:0] p22,
    output reg                  out_vsync,
    output reg                  out_hsync,
    output reg                  out_href,
    output reg                  window_valid,
    output reg [10:0]           center_x,
    output reg [10:0]           center_y
);

    reg [31:0] column_count;
    reg [31:0] row_count;
    reg        previous_href;
    reg        row_phase;

    wire active_pixel = in_vsync && in_href;
    wire [RAM_ADDR_WIDTH-1:0] ram_addr =
        column_count[RAM_ADDR_WIDTH-1:0];
    wire ram0_we = active_pixel && (row_phase == 1'b0);
    wire ram1_we = active_pixel && (row_phase == 1'b1);
    wire [DATA_WIDTH-1:0] ram0_rdata;
    wire [DATA_WIDTH-1:0] ram1_rdata;

    simple_dual_port_ram #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH(RAM_ADDR_WIDTH),
        .OUTPUT_REG("FALSE")
    ) u_line_ram0 (
        .wdata(in_data), .waddr(ram_addr), .raddr(ram_addr),
        .we(ram0_we), .wclk(clk), .re(active_pixel), .rclk(clk),
        .rdata(ram0_rdata)
    );

    simple_dual_port_ram #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH(RAM_ADDR_WIDTH),
        .OUTPUT_REG("FALSE")
    ) u_line_ram1 (
        .wdata(in_data), .waddr(ram_addr), .raddr(ram_addr),
        .we(ram1_we), .wclk(clk), .re(active_pixel), .rclk(clk),
        .rdata(ram1_rdata)
    );

    reg [DATA_WIDTH-1:0] top_shift_1, top_shift_2;
    reg [DATA_WIDTH-1:0] mid_shift_1, mid_shift_2;
    reg [DATA_WIDTH-1:0] bot_shift_1, bot_shift_2;
    reg [DATA_WIDTH-1:0] in_data_d;
    reg                  history_valid_d;

    wire [DATA_WIDTH-1:0] top_ram_data =
        (row_phase == 1'b0) ? ram0_rdata : ram1_rdata;
    wire [DATA_WIDTH-1:0] mid_ram_data =
        (row_phase == 1'b0) ? ram1_rdata : ram0_rdata;
    wire [DATA_WIDTH-1:0] top_pixel_d =
        history_valid_d ? top_ram_data : {DATA_WIDTH{1'b0}};
    wire [DATA_WIDTH-1:0] mid_pixel_d =
        history_valid_d ? mid_ram_data : {DATA_WIDTH{1'b0}};

    reg pending_vsync;
    reg pending_hsync;
    reg pending_href;
    reg pending_window_valid;
    reg [10:0] pending_center_x;
    reg [10:0] pending_center_y;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            column_count <= 32'd0;
            row_count <= 32'd0;
            previous_href <= 1'b0;
            row_phase <= 1'b0;
            history_valid_d <= 1'b0;
            in_data_d <= {DATA_WIDTH{1'b0}};
            top_shift_1 <= {DATA_WIDTH{1'b0}};
            top_shift_2 <= {DATA_WIDTH{1'b0}};
            mid_shift_1 <= {DATA_WIDTH{1'b0}};
            mid_shift_2 <= {DATA_WIDTH{1'b0}};
            bot_shift_1 <= {DATA_WIDTH{1'b0}};
            bot_shift_2 <= {DATA_WIDTH{1'b0}};
            pending_vsync <= 1'b0;
            pending_hsync <= 1'b0;
            pending_href <= 1'b0;
            pending_window_valid <= 1'b0;
            pending_center_x <= 11'd0;
            pending_center_y <= 11'd0;
            p00 <= {DATA_WIDTH{1'b0}};
            p01 <= {DATA_WIDTH{1'b0}};
            p02 <= {DATA_WIDTH{1'b0}};
            p10 <= {DATA_WIDTH{1'b0}};
            p11 <= {DATA_WIDTH{1'b0}};
            p12 <= {DATA_WIDTH{1'b0}};
            p20 <= {DATA_WIDTH{1'b0}};
            p21 <= {DATA_WIDTH{1'b0}};
            p22 <= {DATA_WIDTH{1'b0}};
            out_vsync <= 1'b0;
            out_hsync <= 1'b0;
            out_href <= 1'b0;
            window_valid <= 1'b0;
            center_x <= 11'd0;
            center_y <= 11'd0;
        end else if (!in_vsync) begin
            column_count <= 32'd0;
            row_count <= 32'd0;
            previous_href <= 1'b0;
            row_phase <= 1'b0;
            history_valid_d <= 1'b0;
            in_data_d <= {DATA_WIDTH{1'b0}};
            top_shift_1 <= {DATA_WIDTH{1'b0}};
            top_shift_2 <= {DATA_WIDTH{1'b0}};
            mid_shift_1 <= {DATA_WIDTH{1'b0}};
            mid_shift_2 <= {DATA_WIDTH{1'b0}};
            bot_shift_1 <= {DATA_WIDTH{1'b0}};
            bot_shift_2 <= {DATA_WIDTH{1'b0}};
            pending_vsync <= 1'b0;
            pending_hsync <= 1'b0;
            pending_href <= 1'b0;
            pending_window_valid <= 1'b0;
            p00 <= {DATA_WIDTH{1'b0}};
            p01 <= {DATA_WIDTH{1'b0}};
            p02 <= {DATA_WIDTH{1'b0}};
            p10 <= {DATA_WIDTH{1'b0}};
            p11 <= {DATA_WIDTH{1'b0}};
            p12 <= {DATA_WIDTH{1'b0}};
            p20 <= {DATA_WIDTH{1'b0}};
            p21 <= {DATA_WIDTH{1'b0}};
            p22 <= {DATA_WIDTH{1'b0}};
            out_vsync <= 1'b0;
            out_hsync <= 1'b0;
            out_href <= 1'b0;
            window_valid <= 1'b0;
            center_x <= 11'd0;
            center_y <= 11'd0;
        end else begin
            out_vsync <= pending_vsync;
            out_hsync <= pending_hsync;
            out_href <= pending_href;
            window_valid <= pending_window_valid;
            center_x <= pending_center_x;
            center_y <= pending_center_y;

            if (pending_window_valid) begin
                p00 <= top_shift_1;
                p01 <= top_shift_2;
                p02 <= top_pixel_d;
                p10 <= mid_shift_1;
                p11 <= mid_shift_2;
                p12 <= mid_pixel_d;
                p20 <= bot_shift_1;
                p21 <= bot_shift_2;
                p22 <= in_data_d;
            end else begin
                p00 <= {DATA_WIDTH{1'b0}};
                p01 <= {DATA_WIDTH{1'b0}};
                p02 <= {DATA_WIDTH{1'b0}};
                p10 <= {DATA_WIDTH{1'b0}};
                p11 <= {DATA_WIDTH{1'b0}};
                p12 <= {DATA_WIDTH{1'b0}};
                p20 <= {DATA_WIDTH{1'b0}};
                p21 <= {DATA_WIDTH{1'b0}};
                p22 <= {DATA_WIDTH{1'b0}};
            end

            pending_vsync <= in_vsync;
            pending_hsync <= in_hsync;
            pending_href <= in_href;
            pending_window_valid <= active_pixel &&
                                    (row_count >= 32'd2) &&
                                    (column_count >= 32'd2);
            pending_center_x <= column_count[10:0] - 1'b1;
            pending_center_y <= row_count[10:0] - 1'b1;

            if (!in_href) begin
                if (previous_href) begin
                    row_count <= row_count + 1'b1;
                    row_phase <= ~row_phase;
                end
                column_count <= 32'd0;
                previous_href <= 1'b0;
                history_valid_d <= 1'b0;
                in_data_d <= {DATA_WIDTH{1'b0}};
                top_shift_1 <= {DATA_WIDTH{1'b0}};
                top_shift_2 <= {DATA_WIDTH{1'b0}};
                mid_shift_1 <= {DATA_WIDTH{1'b0}};
                mid_shift_2 <= {DATA_WIDTH{1'b0}};
                bot_shift_1 <= {DATA_WIDTH{1'b0}};
                bot_shift_2 <= {DATA_WIDTH{1'b0}};
                pending_window_valid <= 1'b0;
            end else begin
                previous_href <= 1'b1;
                history_valid_d <= 1'b1;
                in_data_d <= in_data;
                top_shift_1 <= top_shift_2;
                top_shift_2 <= top_pixel_d;
                mid_shift_1 <= mid_shift_2;
                mid_shift_2 <= mid_pixel_d;
                bot_shift_1 <= bot_shift_2;
                bot_shift_2 <= in_data_d;
                if (column_count < IMAGE_WIDTH - 1)
                    column_count <= column_count + 1'b1;
                else
                    column_count <= 32'd0;
            end
        end
    end

endmodule
