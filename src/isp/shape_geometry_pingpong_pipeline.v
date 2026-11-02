 
 
 
 
 
 
module shape_geometry_pingpong_pipeline #(
    parameter integer ROI_X_MIN = 560,
    parameter integer ROI_Y_MIN = 240,
    parameter integer ROI_WIDTH = 800,
    parameter integer ROI_HEIGHT = 600,
    parameter integer X_WIDTH = 11,
    parameter integer Y_WIDTH = 11,
    parameter integer ADDR_WIDTH = 19,
    parameter integer MAX_RUNS_PER_ROW = 64,
    parameter integer MAX_LABELS = 64,
    parameter integer MAX_CONTOUR_STEPS = 65536,
    parameter integer MIN_EDGE_COUNT = 128,
    parameter integer MIN_CONTOUR_LENGTH = 32,
    parameter integer STABLE_FRAMES = 2,
    parameter integer FRAME_ID_WIDTH = 16
) (
    input                    clk,
    input                    rst_n,
    input                    in_vsync,
    input                    in_href,
    input                    edge_pixel,
    input      [X_WIDTH-1:0] pixel_x,
    input      [Y_WIDTH-1:0] pixel_y,
    output                   candidate_ready,
    output                   result_valid,
    output [2:0]             result_shape,
    output [7:0]             result_confidence,
    output [X_WIDTH-1:0]     result_x_min,
    output [X_WIDTH-1:0]     result_x_max,
    output [Y_WIDTH-1:0]     result_y_min,
    output [Y_WIDTH-1:0]     result_y_max,
    output [FRAME_ID_WIDTH-1:0] result_frame_id,
    output [FRAME_ID_WIDTH-1:0] input_frame_id,
    output [FRAME_ID_WIDTH-1:0] processing_frame_id,
    output [1:0]             buffer0_state,
    output [1:0]             buffer1_state,
    output                   recognition_busy,
    output                   input_overrun,
    output [31:0]            last_processing_cycles
);
    localparam [1:0] BUF_EMPTY = 2'd0;
    localparam [1:0] BUF_CAPTURING = 2'd1;
    localparam [1:0] BUF_READY = 2'd2;
    localparam [1:0] BUF_PROCESSING = 2'd3;
    localparam integer LABEL_WIDTH = (MAX_LABELS <= 2) ? 1 : $clog2(MAX_LABELS);

    wire run_valid, row_done, frame_done_i;
    wire [X_WIDTH-1:0] run_x_start, run_x_end;
    wire [Y_WIDTH-1:0] run_y;
    shape_edge_run_encoder #(.X_WIDTH(X_WIDTH), .Y_WIDTH(Y_WIDTH)) u_encoder (
        .clk(clk), .rst_n(rst_n), .in_vsync(in_vsync), .in_href(in_href),
        .edge_pixel(edge_pixel), .pixel_x(pixel_x), .pixel_y(pixel_y),
        .run_valid(run_valid), .run_x_start(run_x_start), .run_x_end(run_x_end),
        .run_y(run_y), .row_done(row_done), .frame_done_i(frame_done_i)
    );

    wire run_in_roi = (run_x_end >= ROI_X_MIN) &&
                      (run_x_start < ROI_X_MIN + ROI_WIDTH) &&
                      (run_y >= ROI_Y_MIN) &&
                      (run_y < ROI_Y_MIN + ROI_HEIGHT);
    wire run_valid_roi = run_valid && run_in_roi;
    wire [X_WIDTH-1:0] run_x_start_roi =
        (run_x_start < ROI_X_MIN) ? ROI_X_MIN : run_x_start;
    wire [X_WIDTH-1:0] run_x_end_roi =
        (run_x_end >= ROI_X_MIN + ROI_WIDTH) ?
        (ROI_X_MIN + ROI_WIDTH - 1) : run_x_end;

    wire ccl_run_component_valid;
    wire [LABEL_WIDTH-1:0] ccl_run_component_label;
    wire ccl_frame_done;
    wire ccl_candidate_valid;
    wire [31:0] ccl_candidate_edge_count;
    wire [X_WIDTH-1:0] ccl_x_min, ccl_x_max;
    wire [Y_WIDTH-1:0] ccl_y_min, ccl_y_max;
    wire [LABEL_WIDTH-1:0] ccl_candidate_label;
    shape_run_ccl_candidate #(
        .MAX_RUNS_PER_ROW(MAX_RUNS_PER_ROW), .MAX_LABELS(MAX_LABELS),
        .X_WIDTH(X_WIDTH), .Y_WIDTH(Y_WIDTH)
    ) u_ccl (
        .clk(clk), .rst_n(rst_n), .run_valid(run_valid_roi),
        .run_x_start(run_x_start_roi), .run_x_end(run_x_end_roi), .run_y(run_y),
        .row_done(row_done), .frame_done_i(frame_done_i),
        .run_component_valid(ccl_run_component_valid),
        .run_component_label(ccl_run_component_label), .frame_done(ccl_frame_done),
        .candidate_valid(ccl_candidate_valid),
        .candidate_edge_count(ccl_candidate_edge_count),
        .candidate_x_min(ccl_x_min), .candidate_x_max(ccl_x_max),
        .candidate_y_min(ccl_y_min), .candidate_y_max(ccl_y_max),
        .candidate_label(ccl_candidate_label)
    );

    reg write_buffer;
    reg capture_enable;
    reg [1:0] state0, state1;
    reg vsync_d;
    reg [FRAME_ID_WIDTH-1:0] frame_counter;
    reg [FRAME_ID_WIDTH-1:0] completed_frame_id;
    reg completed_buffer;
    reg [FRAME_ID_WIDTH-1:0] active_frame_id;
    reg active_buffer;
    reg [X_WIDTH-1:0] active_x_min, active_x_max;
    reg [Y_WIDTH-1:0] active_y_min, active_y_max;
    reg [31:0] active_edge_count;
    reg start_pending;
    reg busy;
    reg pending_valid;
    reg pending_buffer;
    reg [FRAME_ID_WIDTH-1:0] pending_frame_id;
    reg [X_WIDTH-1:0] pending_x_min, pending_x_max;
    reg [Y_WIDTH-1:0] pending_y_min, pending_y_max;
    reg [31:0] pending_edge_count;
    reg overrun;
    reg [31:0] cycle_counter;
    reg [31:0] start_cycle;
    reg [31:0] processing_cycles;
    reg [FRAME_ID_WIDTH-1:0] result_frame_id_reg;

    wire frame_start = in_vsync && !vsync_d;
    wire frame_end = vsync_d && !in_vsync;
    wire contour_feature_valid;
    wire contour_valid;
    wire [31:0] contour_steps;
    wire [31:0] direction_total;
    wire [31:0] orthogonal_count;
    wire [31:0] vertex_count;
    wire [31:0] convex_turns;
    wire [31:0] concave_turns;
    wire radial_valid;
    wire [31:0] radial_error_permille;

    wire replay_valid, replay_edge, replay_done;
    wire [X_WIDTH-1:0] replay_x, replay_y;
    wire random_read_req;
    wire [X_WIDTH-1:0] random_read_x;
    wire [Y_WIDTH-1:0] random_read_y;
    wire random_read_valid, random_read_data;
    wire replay_start = start_pending;

    shape_roi_edge_pingpong #(
        .ROI_X_MIN(ROI_X_MIN), .ROI_Y_MIN(ROI_Y_MIN),
        .ROI_WIDTH(ROI_WIDTH), .ROI_HEIGHT(ROI_HEIGHT),
        .X_WIDTH(X_WIDTH), .Y_WIDTH(Y_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)
    ) u_pingpong_mem (
        .clk(clk), .rst_n(rst_n), .in_vsync(in_vsync), .in_href(in_href),
        .capture_enable(capture_enable), .write_buffer(write_buffer),
        .edge_pixel(edge_pixel), .pixel_x(pixel_x), .pixel_y(pixel_y),
        .process_buffer(active_buffer), .replay_start(replay_start),
        .replay_x_min_i(active_x_min), .replay_x_max_i(active_x_max),
        .replay_y_min_i(active_y_min), .replay_y_max_i(active_y_max),
        .replay_valid(replay_valid), .replay_edge(replay_edge),
        .replay_x(replay_x), .replay_y(replay_y), .replay_done(replay_done),
        .random_read_req(random_read_req), .random_read_x(random_read_x),
        .random_read_y(random_read_y), .random_read_valid(random_read_valid),
        .random_read_data(random_read_data)
    );

    shape_contour_feature_engine #(
        .X_WIDTH(X_WIDTH), .Y_WIDTH(Y_WIDTH),
        .MAX_CONTOUR_STEPS(MAX_CONTOUR_STEPS)
    ) u_contour_engine (
        .clk(clk), .rst_n(rst_n), .replay_start(replay_start),
        .replay_valid(replay_valid), .replay_edge(replay_edge),
        .replay_x(replay_x), .replay_y(replay_y), .replay_done(replay_done),
        .random_read_req(random_read_req), .random_read_x(random_read_x),
        .random_read_y(random_read_y), .random_read_valid(random_read_valid),
        .random_read_data(random_read_data),
        .bbox_x_min(active_x_min), .bbox_x_max(active_x_max),
        .bbox_y_min(active_y_min), .bbox_y_max(active_y_max),
        .feature_valid(contour_feature_valid), .contour_valid(contour_valid),
        .contour_steps(contour_steps), .direction_total(direction_total),
        .orthogonal_count(orthogonal_count), .vertex_count(vertex_count),
        .convex_turns(convex_turns), .concave_turns(concave_turns),
        .radial_valid(radial_valid), .radial_error_permille(radial_error_permille)
    );

    wire classifier_result_valid;
    shape_geometry_classifier #(
        .X_WIDTH(X_WIDTH), .Y_WIDTH(Y_WIDTH),
        .MIN_EDGE_COUNT(MIN_EDGE_COUNT),
        .MIN_CONTOUR_LENGTH(MIN_CONTOUR_LENGTH),
        .STABLE_FRAMES(STABLE_FRAMES)
    ) u_classifier (
        .clk(clk), .rst_n(rst_n), .feature_valid(contour_feature_valid),
        .feature_component_valid(contour_valid), .edge_count(active_edge_count),
        .direction_total(direction_total), .orthogonal_count(orthogonal_count),
        .vertex_count(vertex_count), .convex_turns(convex_turns),
        .concave_turns(concave_turns), .contour_length(contour_steps),
        .contour_closed(contour_valid), .radial_valid(radial_valid),
        .radial_error_permille(radial_error_permille),
        .bbox_x_min(active_x_min), .bbox_x_max(active_x_max),
        .bbox_y_min(active_y_min), .bbox_y_max(active_y_max),
        .result_valid(classifier_result_valid), .result_shape(result_shape),
        .result_confidence(result_confidence), .result_x_min(result_x_min),
        .result_x_max(result_x_max), .result_y_min(result_y_min),
        .result_y_max(result_y_max)
    );

    assign candidate_ready = !pending_valid && !overrun;
    assign result_valid = classifier_result_valid;
    assign result_frame_id = result_frame_id_reg;
    assign input_frame_id = frame_counter;
    assign processing_frame_id = active_frame_id;
    assign buffer0_state = state0;
    assign buffer1_state = state1;
    assign recognition_busy = busy;
    assign input_overrun = overrun;
    assign last_processing_cycles = processing_cycles;

     
     
     
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_buffer <= 1'b0;
            capture_enable <= 1'b0;
            state0 <= BUF_EMPTY;
            state1 <= BUF_EMPTY;
            vsync_d <= 1'b0;
            frame_counter <= {FRAME_ID_WIDTH{1'b0}};
            completed_frame_id <= {FRAME_ID_WIDTH{1'b0}};
            completed_buffer <= 1'b0;
            active_frame_id <= {FRAME_ID_WIDTH{1'b0}};
            active_buffer <= 1'b0;
            active_x_min <= 0;
            active_x_max <= 0;
            active_y_min <= 0;
            active_y_max <= 0;
            active_edge_count <= 0;
            start_pending <= 1'b0;
            busy <= 1'b0;
            pending_valid <= 1'b0;
            pending_buffer <= 1'b0;
            pending_frame_id <= 0;
            pending_x_min <= 0;
            pending_x_max <= 0;
            pending_y_min <= 0;
            pending_y_max <= 0;
            pending_edge_count <= 0;
            overrun <= 1'b0;
            cycle_counter <= 0;
            start_cycle <= 0;
            processing_cycles <= 0;
            result_frame_id_reg <= 0;
        end else begin
            vsync_d <= in_vsync;
            cycle_counter <= cycle_counter + 1'b1;
            start_pending <= 1'b0;

            if (frame_start) begin
                frame_counter <= frame_counter + 1'b1;
                if ((write_buffer == 1'b0 && state0 == BUF_EMPTY) ||
                    (write_buffer == 1'b1 && state1 == BUF_EMPTY)) begin
                    capture_enable <= 1'b1;
                    if (write_buffer == 1'b0) state0 <= BUF_CAPTURING;
                    else state1 <= BUF_CAPTURING;
                end else begin
                    capture_enable <= 1'b0;
                    overrun <= 1'b1;
                end
            end

            if (frame_end) begin
                completed_buffer <= write_buffer;
                completed_frame_id <= frame_counter;
                if (capture_enable) begin
                    if (write_buffer == 1'b0) state0 <= BUF_READY;
                    else state1 <= BUF_READY;
                end
                capture_enable <= 1'b0;
                write_buffer <= ~write_buffer;
            end

             
             
             
            if (ccl_frame_done && ccl_candidate_valid) begin
                if ((completed_buffer == 1'b0 && state0 == BUF_READY) ||
                    (completed_buffer == 1'b1 && state1 == BUF_READY)) begin
                    if (!busy && !start_pending) begin
                        active_buffer <= completed_buffer;
                        active_frame_id <= completed_frame_id;
                        active_x_min <= ccl_x_min;
                        active_x_max <= ccl_x_max;
                        active_y_min <= ccl_y_min;
                        active_y_max <= ccl_y_max;
                        active_edge_count <= ccl_candidate_edge_count;
                        start_pending <= 1'b1;
                        busy <= 1'b1;
                        start_cycle <= cycle_counter;
                        if (completed_buffer == 1'b0) state0 <= BUF_PROCESSING;
                        else state1 <= BUF_PROCESSING;
                    end else if (!pending_valid) begin
                        pending_valid <= 1'b1;
                        pending_buffer <= completed_buffer;
                        pending_frame_id <= completed_frame_id;
                        pending_x_min <= ccl_x_min;
                        pending_x_max <= ccl_x_max;
                        pending_y_min <= ccl_y_min;
                        pending_y_max <= ccl_y_max;
                        pending_edge_count <= ccl_candidate_edge_count;
                    end else begin
                        overrun <= 1'b1;
                    end
                end
            end

             
             
             
             
            if (ccl_frame_done && !ccl_candidate_valid) begin
                if (completed_buffer == 1'b0 && state0 == BUF_READY)
                    state0 <= BUF_EMPTY;
                if (completed_buffer == 1'b1 && state1 == BUF_READY)
                    state1 <= BUF_EMPTY;
            end

            if (contour_feature_valid) begin
                processing_cycles <= cycle_counter - start_cycle;
                if (active_buffer == 1'b0) state0 <= BUF_EMPTY;
                else state1 <= BUF_EMPTY;
                busy <= 1'b0;
                if (pending_valid) begin
                    active_buffer <= pending_buffer;
                    active_frame_id <= pending_frame_id;
                    active_x_min <= pending_x_min;
                    active_x_max <= pending_x_max;
                    active_y_min <= pending_y_min;
                    active_y_max <= pending_y_max;
                    active_edge_count <= pending_edge_count;
                    start_pending <= 1'b1;
                    busy <= 1'b1;
                    start_cycle <= cycle_counter;
                    pending_valid <= 1'b0;
                    if (pending_buffer == 1'b0) state0 <= BUF_PROCESSING;
                    else state1 <= BUF_PROCESSING;
                end
            end

             
             
             
             
            if (contour_feature_valid)
                result_frame_id_reg <= active_frame_id;
        end
    end
endmodule
