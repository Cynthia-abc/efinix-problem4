`timescale 1ns/1ps

 
 
 
 
 
 
 
 
module canny_multiround_frame #(
    parameter IMAGE_WIDTH  = 1920,
    parameter IMAGE_HEIGHT = 1080,
    parameter WORK_WIDTH   = IMAGE_WIDTH / 2,
    parameter WORK_HEIGHT  = IMAGE_HEIGHT / 2,
    parameter THRESHOLD    = 8'd64,
    parameter MAX_ROUNDS   = 16
) (
    input        clk,
    input        rst_n,
    input  [7:0] nms_data,
    input        nms_valid,
    input        in_vsync,
    input        in_hsync,
    input        in_href,
    input  [7:0] threshold_i,
    input        threshold_i_valid,
    output reg [7:0] edge_data,
    output reg       edge_valid,
    output           out_vsync,
    output           out_hsync,
    output           out_href
);

    localparam integer WORK_PIXELS = WORK_WIDTH * WORK_HEIGHT;
    localparam integer ADDR_WIDTH  = 19;
    localparam [1:0] CLASS_NONE      = 2'b00;
    localparam [1:0] CLASS_WEAK      = 2'b01;
    localparam [1:0] CLASS_CONNECTED = 2'b10;

    localparam [3:0] ST_CAPTURE      = 4'd0;
    localparam [3:0] ST_LOAD_FWD     = 4'd1;
    localparam [3:0] ST_PROCESS_FWD  = 4'd2;
    localparam [3:0] ST_LOAD_BWD     = 4'd3;
    localparam [3:0] ST_PROCESS_BWD  = 4'd4;
    localparam [3:0] ST_WAIT_OUTPUT  = 4'd5;
    localparam [3:0] ST_OUTPUT       = 4'd6;

    wire [1:0] class_ram_rdata;
    reg  [1:0] class_ram_wdata;
    reg  [ADDR_WIDTH-1:0] class_ram_waddr;
    reg  [ADDR_WIDTH-1:0] class_ram_raddr;
    reg                    class_ram_we;
    reg                    class_ram_re;

    simple_dual_port_ram #(
        .DATA_WIDTH (2),
        .ADDR_WIDTH(ADDR_WIDTH),
        .OUTPUT_REG ("FALSE")
    ) u_class_map_ram (
        .wdata(class_ram_wdata),
        .waddr(class_ram_waddr),
        .raddr(class_ram_raddr),
        .we   (class_ram_we),
        .wclk (clk),
        .re   (class_ram_re),
        .rclk (clk),
        .rdata(class_ram_rdata)
    );

     
    reg [1:0] row_buf0 [0:WORK_WIDTH-1];
    reg [1:0] row_buf1 [0:WORK_WIDTH-1];
    reg       prev_sel;

    reg [3:0] state;
    reg       frame_seen;
    reg       output_seen;
    reg       map_ready;
    reg       wait_frame_low;
    reg       pass_changed;

    reg [31:0] in_x;
    reg [31:0] in_y;
    reg [31:0] cap_addr;
    reg [31:0] out_x;
    reg [31:0] out_y;
    reg [ADDR_WIDTH-1:0] row_base_addr;
    reg [31:0] proc_x;
    reg [31:0] proc_y;
    reg [31:0] load_count;
    reg        load_pending;
    reg [7:0]  round_count;
    reg [7:0]  frame_high_threshold;
    reg [ADDR_WIDTH-1:0] out_row_base;

    reg [1:0] capture_class;
    reg [7:0] capture_high_threshold;
    reg [1:0] center_class;
    reg       has_connected_neighbor;
    reg       promote_now;
    reg [1:0] next_class;
    reg [1:0] output_class;

    wire cap_sample = in_vsync && in_href && (in_x[0] == 1'b0) &&
                      (in_y[0] == 1'b0);
    wire [ADDR_WIDTH-1:0] cap_word_addr = cap_addr[ADDR_WIDTH-1:0];
    wire [ADDR_WIDTH-1:0] proc_addr = row_base_addr + proc_x[ADDR_WIDTH-1:0];
    wire [ADDR_WIDTH-1:0] load_addr = row_base_addr + load_count[ADDR_WIDTH-1:0];
    wire [ADDR_WIDTH-1:0] out_current_addr = out_row_base + out_x[ADDR_WIDTH-1:1];

     
     
    reg [ADDR_WIDTH-1:0] out_next_addr;
    always @* begin
        if (out_x == IMAGE_WIDTH-1) begin
            if (out_y[0] == 1'b0)
                out_next_addr = out_row_base;
            else
                out_next_addr = out_row_base + WORK_WIDTH;
        end else if (out_x[0] == 1'b1) begin
            out_next_addr = out_current_addr + 1'b1;
        end else begin
            out_next_addr = out_current_addr;
        end
    end

     
     
    always @* begin
        center_class           = CLASS_NONE;
        has_connected_neighbor = 1'b0;

        if (prev_sel == 1'b0) begin
            center_class = row_buf1[proc_x];
            if ((proc_x > 0) && (row_buf1[proc_x - 1'b1] == CLASS_CONNECTED))
                has_connected_neighbor = 1'b1;
            if ((proc_y > 0) && (row_buf0[proc_x] == CLASS_CONNECTED))
                has_connected_neighbor = 1'b1;
            if ((proc_y > 0) && (proc_x > 0) &&
                (row_buf0[proc_x - 1'b1] == CLASS_CONNECTED))
                has_connected_neighbor = 1'b1;
            if ((proc_y > 0) && (proc_x + 1 < WORK_WIDTH) &&
                (row_buf0[proc_x + 1'b1] == CLASS_CONNECTED))
                has_connected_neighbor = 1'b1;
        end else begin
            center_class = row_buf0[proc_x];
            if ((proc_x > 0) && (row_buf0[proc_x - 1'b1] == CLASS_CONNECTED))
                has_connected_neighbor = 1'b1;
            if ((proc_y > 0) && (row_buf1[proc_x] == CLASS_CONNECTED))
                has_connected_neighbor = 1'b1;
            if ((proc_y > 0) && (proc_x > 0) &&
                (row_buf1[proc_x - 1'b1] == CLASS_CONNECTED))
                has_connected_neighbor = 1'b1;
            if ((proc_y > 0) && (proc_x + 1 < WORK_WIDTH) &&
                (row_buf1[proc_x + 1'b1] == CLASS_CONNECTED))
                has_connected_neighbor = 1'b1;
        end

        if (state == ST_PROCESS_BWD) begin
            has_connected_neighbor = 1'b0;
            if (prev_sel == 1'b0) begin
                center_class = row_buf1[proc_x];
                if ((proc_x + 1 < WORK_WIDTH) &&
                    (row_buf1[proc_x + 1'b1] == CLASS_CONNECTED))
                    has_connected_neighbor = 1'b1;
                if ((proc_y + 1 < WORK_HEIGHT) &&
                    (row_buf0[proc_x] == CLASS_CONNECTED))
                    has_connected_neighbor = 1'b1;
                if ((proc_y + 1 < WORK_HEIGHT) && (proc_x > 0) &&
                    (row_buf0[proc_x - 1'b1] == CLASS_CONNECTED))
                    has_connected_neighbor = 1'b1;
                if ((proc_y + 1 < WORK_HEIGHT) &&
                    (proc_x + 1 < WORK_WIDTH) &&
                    (row_buf0[proc_x + 1'b1] == CLASS_CONNECTED))
                    has_connected_neighbor = 1'b1;
            end else begin
                center_class = row_buf0[proc_x];
                if ((proc_x + 1 < WORK_WIDTH) &&
                    (row_buf0[proc_x + 1'b1] == CLASS_CONNECTED))
                    has_connected_neighbor = 1'b1;
                if ((proc_y + 1 < WORK_HEIGHT) &&
                    (row_buf1[proc_x] == CLASS_CONNECTED))
                    has_connected_neighbor = 1'b1;
                if ((proc_y + 1 < WORK_HEIGHT) && (proc_x > 0) &&
                    (row_buf1[proc_x - 1'b1] == CLASS_CONNECTED))
                    has_connected_neighbor = 1'b1;
                if ((proc_y + 1 < WORK_HEIGHT) &&
                    (proc_x + 1 < WORK_WIDTH) &&
                    (row_buf1[proc_x + 1'b1] == CLASS_CONNECTED))
                    has_connected_neighbor = 1'b1;
            end
        end

        promote_now = ((state == ST_PROCESS_FWD) ||
                       (state == ST_PROCESS_BWD)) &&
                      (center_class == CLASS_WEAK) &&
                      has_connected_neighbor;
        next_class = center_class;
        if (promote_now)
            next_class = CLASS_CONNECTED;
    end

    always @* begin
        if (cap_addr == 0) begin
            if (threshold_i_valid)
                capture_high_threshold = threshold_i;
            else
                capture_high_threshold = THRESHOLD;
        end else begin
            capture_high_threshold = frame_high_threshold;
        end

        if (!nms_valid)
            capture_class = CLASS_NONE;
        else if (nms_data >= capture_high_threshold)
            capture_class = CLASS_CONNECTED;
        else if (nms_data >= (capture_high_threshold >> 1))
            capture_class = CLASS_WEAK;
        else
            capture_class = CLASS_NONE;
    end

    always @* begin
        class_ram_wdata = CLASS_NONE;
        class_ram_waddr = {ADDR_WIDTH{1'b0}};
        class_ram_we    = 1'b0;
        class_ram_raddr = {ADDR_WIDTH{1'b0}};
        class_ram_re    = 1'b0;

        if (state == ST_CAPTURE) begin
            class_ram_wdata = capture_class;
            class_ram_waddr = cap_word_addr;
            class_ram_we    = cap_sample;
        end else if ((state == ST_PROCESS_FWD) ||
                     (state == ST_PROCESS_BWD)) begin
            class_ram_wdata = next_class;
            class_ram_waddr = proc_addr;
            class_ram_we    = 1'b1;
        end

        if ((state == ST_LOAD_FWD) || (state == ST_LOAD_BWD)) begin
            if (load_count < WORK_WIDTH) begin
                class_ram_raddr = load_addr;
                class_ram_re    = 1'b1;
            end
        end else if (state == ST_WAIT_OUTPUT) begin
            if (!in_vsync && wait_frame_low) begin
                class_ram_raddr = {ADDR_WIDTH{1'b0}};
                class_ram_re    = 1'b1;
            end
        end else if (state == ST_OUTPUT) begin
            if (in_vsync && in_href) begin
                class_ram_raddr = out_next_addr;
                class_ram_re    = 1'b1;
            end
        end
    end

    assign out_vsync = in_vsync;
    assign out_hsync = in_hsync;
    assign out_href  = in_href;

    always @* begin
        output_class = class_ram_rdata;
        edge_valid = (state == ST_OUTPUT) && map_ready && in_vsync && in_href;
        edge_data  = (edge_valid && (output_class == CLASS_CONNECTED)) ? 8'hff : 8'd0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state                <= ST_CAPTURE;
            frame_seen           <= 1'b0;
            output_seen          <= 1'b0;
            map_ready            <= 1'b0;
            wait_frame_low       <= 1'b0;
            pass_changed         <= 1'b0;
            in_x                 <= 32'd0;
            in_y                 <= 32'd0;
            cap_addr             <= 32'd0;
            out_x                <= 32'd0;
            out_y                <= 32'd0;
            out_row_base         <= {ADDR_WIDTH{1'b0}};
            row_base_addr        <= {ADDR_WIDTH{1'b0}};
            proc_x               <= 32'd0;
            proc_y               <= 32'd0;
            load_count           <= 32'd0;
            load_pending         <= 1'b0;
            prev_sel              <= 1'b0;
            round_count           <= 8'd0;
            frame_high_threshold <= THRESHOLD;
        end else begin
            case (state)
                ST_CAPTURE: begin
                    if (in_vsync && in_href) begin
                        frame_seen <= 1'b1;
                        if (cap_sample) begin
                            if (cap_addr == 0) begin
                                if (threshold_i_valid)
                                    frame_high_threshold <= threshold_i;
                                else
                                    frame_high_threshold <= THRESHOLD;
                            end
                            if (cap_addr < WORK_PIXELS-1)
                                cap_addr <= cap_addr + 1'b1;
                        end
                        if (in_x < IMAGE_WIDTH-1)
                            in_x <= in_x + 1'b1;
                    end else if (in_vsync && !in_href) begin
                        in_x <= 32'd0;
                        if (in_y < IMAGE_HEIGHT-1)
                            in_y <= in_y + 1'b1;
                    end

                    if (!in_vsync && frame_seen) begin
                        state          <= ST_LOAD_FWD;
                        row_base_addr  <= {ADDR_WIDTH{1'b0}};
                        proc_x         <= 32'd0;
                        proc_y         <= 32'd0;
                        load_count     <= 32'd0;
                        load_pending   <= 1'b0;
                        prev_sel       <= 1'b0;
                        pass_changed   <= 1'b0;
                        round_count    <= 8'd0;
                        map_ready      <= 1'b0;
                        frame_seen     <= 1'b0;
                        in_x           <= 32'd0;
                        in_y           <= 32'd0;
                    end
                end

                ST_LOAD_FWD: begin
                    if (load_count < WORK_WIDTH) begin
                        if (load_pending) begin
                            if (prev_sel == 1'b0)
                                row_buf1[load_count - 1'b1] <= class_ram_rdata;
                            else
                                row_buf0[load_count - 1'b1] <= class_ram_rdata;
                        end
                        load_count   <= load_count + 1'b1;
                        load_pending <= 1'b1;
                    end else begin
                        if (load_pending) begin
                            if (prev_sel == 1'b0)
                                row_buf1[WORK_WIDTH-1] <= class_ram_rdata;
                            else
                                row_buf0[WORK_WIDTH-1] <= class_ram_rdata;
                        end
                        load_count   <= 32'd0;
                        load_pending <= 1'b0;
                        proc_x       <= 32'd0;
                        state        <= ST_PROCESS_FWD;
                    end
                end

                ST_PROCESS_FWD: begin
                    if (prev_sel == 1'b0)
                        row_buf1[proc_x] <= next_class;
                    else
                        row_buf0[proc_x] <= next_class;
                    if (promote_now)
                        pass_changed <= 1'b1;

                    if (proc_x == WORK_WIDTH-1) begin
                        if (proc_y == WORK_HEIGHT-1) begin
                            state          <= ST_LOAD_BWD;
                            row_base_addr  <= WORK_PIXELS - WORK_WIDTH;
                            proc_x         <= WORK_WIDTH-1;
                            proc_y         <= WORK_HEIGHT-1;
                            load_count     <= 32'd0;
                            load_pending   <= 1'b0;
                            prev_sel       <= 1'b0;
                        end else begin
                            state          <= ST_LOAD_FWD;
                            row_base_addr  <= row_base_addr + WORK_WIDTH;
                            proc_x         <= 32'd0;
                            proc_y         <= proc_y + 1'b1;
                            load_count     <= 32'd0;
                            load_pending   <= 1'b0;
                            prev_sel       <= ~prev_sel;
                        end
                    end else begin
                        proc_x <= proc_x + 1'b1;
                    end
                end

                ST_LOAD_BWD: begin
                    if (load_count < WORK_WIDTH) begin
                        if (load_pending) begin
                            if (prev_sel == 1'b0)
                                row_buf1[load_count - 1'b1] <= class_ram_rdata;
                            else
                                row_buf0[load_count - 1'b1] <= class_ram_rdata;
                        end
                        load_count   <= load_count + 1'b1;
                        load_pending <= 1'b1;
                    end else begin
                        if (load_pending) begin
                            if (prev_sel == 1'b0)
                                row_buf1[WORK_WIDTH-1] <= class_ram_rdata;
                            else
                                row_buf0[WORK_WIDTH-1] <= class_ram_rdata;
                        end
                        load_count   <= 32'd0;
                        load_pending <= 1'b0;
                        proc_x       <= WORK_WIDTH-1;
                        state        <= ST_PROCESS_BWD;
                    end
                end

                ST_PROCESS_BWD: begin
                    if (prev_sel == 1'b0)
                        row_buf1[proc_x] <= next_class;
                    else
                        row_buf0[proc_x] <= next_class;
                    if (promote_now)
                        pass_changed <= 1'b1;

                    if (proc_x == 0) begin
                        if (proc_y == 0) begin
                            if ((pass_changed || promote_now) &&
                                (round_count < MAX_ROUNDS-1)) begin
                                state          <= ST_LOAD_FWD;
                                row_base_addr  <= {ADDR_WIDTH{1'b0}};
                                proc_x         <= 32'd0;
                                proc_y         <= 32'd0;
                                load_count     <= 32'd0;
                                load_pending   <= 1'b0;
                                prev_sel       <= 1'b0;
                                pass_changed   <= 1'b0;
                                round_count    <= round_count + 1'b1;
                            end else begin
                                state          <= ST_WAIT_OUTPUT;
                                map_ready      <= 1'b1;
                                output_seen    <= 1'b0;
                                wait_frame_low <= !in_vsync;
                                out_x          <= 32'd0;
                                out_y          <= 32'd0;
                                out_row_base   <= {ADDR_WIDTH{1'b0}};
                            end
                        end else begin
                            state          <= ST_LOAD_BWD;
                            row_base_addr  <= row_base_addr - WORK_WIDTH;
                            proc_x         <= WORK_WIDTH-1;
                            proc_y         <= proc_y - 1'b1;
                            load_count     <= 32'd0;
                            load_pending   <= 1'b0;
                            prev_sel       <= ~prev_sel;
                        end
                    end else begin
                        proc_x <= proc_x - 1'b1;
                    end
                end

                ST_WAIT_OUTPUT: begin
                    if (!in_vsync) begin
                        wait_frame_low <= 1'b1;
                    end else if (wait_frame_low) begin
                        state        <= ST_OUTPUT;
                        output_seen  <= 1'b0;
                        out_x        <= 32'd0;
                        out_y        <= 32'd0;
                        out_row_base <= {ADDR_WIDTH{1'b0}};
                    end
                end

                ST_OUTPUT: begin
                    if (in_vsync && in_href) begin
                        output_seen <= 1'b1;
                        if (out_x < IMAGE_WIDTH-1)
                            out_x <= out_x + 1'b1;
                    end else if (in_vsync && !in_href) begin
                        out_x <= 32'd0;
                        if (out_y < IMAGE_HEIGHT-1) begin
                            out_y <= out_y + 1'b1;
                            if (out_y[0] == 1'b1)
                                out_row_base <= out_row_base + WORK_WIDTH;
                        end
                    end

                    if (!in_vsync && output_seen) begin
                        state          <= ST_CAPTURE;
                        map_ready      <= 1'b0;
                        output_seen    <= 1'b0;
                        wait_frame_low <= 1'b0;
                        frame_seen     <= 1'b0;
                        cap_addr       <= 32'd0;
                        in_x           <= 32'd0;
                        in_y           <= 32'd0;
                    end
                end

                default: state <= ST_CAPTURE;
            endcase
        end
    end
endmodule
