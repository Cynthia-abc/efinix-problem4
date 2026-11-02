 
 
 
 
 
 
 
module shape_multi_candidate_feature_pipeline #(
    parameter integer GRID_WIDTH = 480,
    parameter integer GRID_HEIGHT = 270,
    parameter integer TOP_K = 3,
    parameter integer MAX_RUNS_PER_ROW = 96,
    parameter integer MAX_LABELS = 96,
    parameter integer MAX_CONTOUR_STEPS = 65536,
    parameter integer X_WIDTH = 9,
    parameter integer Y_WIDTH = 9,
    parameter integer ADDR_WIDTH = 17
) (
    input                    clk,
    input                    rst_n,
    input                    grid_valid,
    input                    grid_edge,
    input      [4:0]         grid_edge_weight,
    input                    grid_row_last,
    input                    grid_frame_last,
    input      [X_WIDTH-1:0] grid_x,
    input      [Y_WIDTH-1:0] grid_y,
    output reg               feature_valid,
    output reg               feature_last,
    output reg [((TOP_K <= 2) ? 1 : $clog2(TOP_K))-1:0] feature_index,
    output reg [31:0]        feature_edge_count,
    output reg [X_WIDTH-1:0] feature_x_min,
    output reg [X_WIDTH-1:0] feature_x_max,
    output reg [Y_WIDTH-1:0] feature_y_min,
    output reg [Y_WIDTH-1:0] feature_y_max,
    output reg [31:0]        feature_aspect_ratio_x1000,
    output reg [31:0]        feature_contour_steps,
    output reg               feature_contour_valid,
    output reg               analysis_done,
    output reg               overrun
);
    localparam integer INDEX_WIDTH = (TOP_K <= 2) ? 1 : $clog2(TOP_K);
    localparam [1:0] A_IDLE = 2'd0, A_START = 2'd1,
                     A_WAIT_FEATURE = 2'd2, A_FINISH = 2'd3;

    wire run_valid, row_done, frame_done_i;
    wire [X_WIDTH-1:0] run_x_start, run_x_end;
    wire [Y_WIDTH-1:0] run_y;
    wire [31:0] run_weight;
    shape_grid_run_encoder #(.X_WIDTH(X_WIDTH), .Y_WIDTH(Y_WIDTH)) u_encoder (
        .clk(clk), .rst_n(rst_n), .grid_valid(grid_valid), .grid_edge(grid_edge),
        .grid_edge_weight(grid_edge_weight), .grid_row_last(grid_row_last),
        .grid_frame_last(grid_frame_last), .grid_x(grid_x), .grid_y(grid_y),
        .run_valid(run_valid), .run_x_start(run_x_start), .run_x_end(run_x_end),
        .run_y(run_y), .run_weight(run_weight), .row_done(row_done),
        .frame_done_i(frame_done_i)
    );

    wire ccl_record_valid, ccl_record_last, ccl_records_done;
    wire [INDEX_WIDTH-1:0] ccl_record_index;
    wire [((MAX_LABELS <= 2) ? 1 : $clog2(MAX_LABELS))-1:0] ccl_record_label;
    wire [31:0] ccl_edge_count, ccl_aspect;
    wire [X_WIDTH-1:0] ccl_x_min, ccl_x_max;
    wire [Y_WIDTH-1:0] ccl_y_min, ccl_y_max;
    wire ccl_overflow;
    shape_run_ccl_topk #(
        .MAX_RUNS_PER_ROW(MAX_RUNS_PER_ROW), .MAX_LABELS(MAX_LABELS),
        .TOP_K(TOP_K), .X_WIDTH(X_WIDTH), .Y_WIDTH(Y_WIDTH)
    ) u_ccl (
        .clk(clk), .rst_n(rst_n), .run_valid(run_valid),
        .run_x_start(run_x_start), .run_x_end(run_x_end), .run_y(run_y),
        .run_weight(run_weight), .row_done(row_done), .frame_done_i(frame_done_i),
        .record_valid(ccl_record_valid), .record_last(ccl_record_last),
        .record_index(ccl_record_index), .record_label(ccl_record_label),
        .record_edge_count(ccl_edge_count), .record_x_min(ccl_x_min),
        .record_x_max(ccl_x_max), .record_y_min(ccl_y_min),
        .record_y_max(ccl_y_max),
        .record_aspect_ratio_x1000(ccl_aspect),
        .records_done(ccl_records_done), .overflow(ccl_overflow)
    );

    reg write_buffer, completed_buffer;
    reg capture_enable;
    reg bank0_busy, bank1_busy;
    wire frame_first_cell = grid_valid && (grid_x == 0) && (grid_y == 0);
    wire frame_last_cell = grid_valid && grid_frame_last;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_buffer <= 1'b0;
            completed_buffer <= 1'b0;
            capture_enable <= 1'b0;
            bank0_busy <= 1'b0;
            bank1_busy <= 1'b0;
            overrun <= 1'b0;
        end else begin
            if (frame_first_cell) begin
                if ((!write_buffer && bank0_busy) ||
                    (write_buffer && bank1_busy)) begin
                    capture_enable <= 1'b0;
                    overrun <= 1'b1;
                end else begin
                    capture_enable <= 1'b1;
                end
            end
            if (frame_last_cell) begin
                completed_buffer <= write_buffer;
                capture_enable <= 1'b0;
                write_buffer <= ~write_buffer;
            end
            if (ccl_records_done) begin
                if (completed_buffer) bank1_busy <= 1'b1;
                else bank0_busy <= 1'b1;
            end
            if (ccl_overflow) overrun <= 1'b1;
            if (analysis_done) begin
                if (completed_buffer) bank1_busy <= 1'b0;
                else bank0_busy <= 1'b0;
            end
        end
    end

    reg cand_valid [0:TOP_K-1];
    reg [31:0] cand_edge_count [0:TOP_K-1];
    reg [X_WIDTH-1:0] cand_x_min [0:TOP_K-1];
    reg [X_WIDTH-1:0] cand_x_max [0:TOP_K-1];
    reg [Y_WIDTH-1:0] cand_y_min [0:TOP_K-1];
    reg [Y_WIDTH-1:0] cand_y_max [0:TOP_K-1];
    reg [31:0] cand_aspect [0:TOP_K-1];
    integer n;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (n = 0; n < TOP_K; n = n + 1) begin
                cand_valid[n] <= 1'b0;
                cand_edge_count[n] <= 0;
                cand_x_min[n] <= 0; cand_x_max[n] <= 0;
                cand_y_min[n] <= 0; cand_y_max[n] <= 0;
                cand_aspect[n] <= 0;
            end
        end else begin
            if (ccl_record_valid) begin
                cand_valid[ccl_record_index] <= 1'b1;
                cand_edge_count[ccl_record_index] <= ccl_edge_count;
                cand_x_min[ccl_record_index] <= ccl_x_min;
                cand_x_max[ccl_record_index] <= ccl_x_max;
                cand_y_min[ccl_record_index] <= ccl_y_min;
                cand_y_max[ccl_record_index] <= ccl_y_max;
                cand_aspect[ccl_record_index] <= ccl_aspect;
            end
            if (frame_first_cell) begin
                 
                 
                 
                for (n = 0; n < TOP_K; n = n + 1)
                    cand_valid[n] <= 1'b0;
            end
        end
    end

    wire replay_valid, replay_edge, replay_done;
    wire [X_WIDTH-1:0] replay_x, replay_y;
    wire random_read_req;
    wire [X_WIDTH-1:0] random_read_x, random_read_y;
    wire random_read_valid, random_read_data;
    reg [X_WIDTH-1:0] active_x_min, active_x_max;
    reg [Y_WIDTH-1:0] active_y_min, active_y_max;
    reg [INDEX_WIDTH-1:0] active_index;
    reg process_buffer;
    reg replay_start;
    shape_grid_edge_pingpong #(
        .GRID_WIDTH(GRID_WIDTH), .GRID_HEIGHT(GRID_HEIGHT),
        .X_WIDTH(X_WIDTH), .Y_WIDTH(Y_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)
    ) u_grid_mem (
        .clk(clk), .rst_n(rst_n), .grid_valid(grid_valid),
        .capture_enable(capture_enable), .write_buffer(write_buffer),
        .grid_edge(grid_edge), .grid_x(grid_x), .grid_y(grid_y),
        .process_buffer(process_buffer), .replay_start(replay_start),
        .replay_x_min_i(active_x_min), .replay_x_max_i(active_x_max),
        .replay_y_min_i(active_y_min), .replay_y_max_i(active_y_max),
        .replay_valid(replay_valid), .replay_edge(replay_edge),
        .replay_x(replay_x), .replay_y(replay_y), .replay_done(replay_done),
        .random_read_req(random_read_req), .random_read_x(random_read_x),
        .random_read_y(random_read_y), .random_read_valid(random_read_valid),
        .random_read_data(random_read_data)
    );

    wire contour_feature_valid, contour_valid;
    wire [31:0] contour_steps;
    wire [31:0] direction_total, orthogonal_count, vertex_count;
    wire [31:0] convex_turns, concave_turns;
    wire radial_valid;
    wire [31:0] radial_error_permille;
    shape_contour_feature_engine #(
        .X_WIDTH(X_WIDTH), .Y_WIDTH(Y_WIDTH),
        .MAX_CONTOUR_STEPS(MAX_CONTOUR_STEPS)
    ) u_contour (
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

    reg [1:0] analysis_state;
    reg have_candidate;
    reg later_candidate;
    always @* begin
        have_candidate = 1'b0;
        later_candidate = 1'b0;
        if (active_index < TOP_K)
            have_candidate = cand_valid[active_index];
        for (m = 0; m < TOP_K; m = m + 1)
            if ((m > active_index) && cand_valid[m])
                later_candidate = 1'b1;
    end

    integer m;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            analysis_state <= A_IDLE;
            active_index <= 0;
            process_buffer <= 0;
            replay_start <= 1'b0;
            active_x_min <= 0; active_x_max <= 0;
            active_y_min <= 0; active_y_max <= 0;
            feature_valid <= 1'b0;
            feature_last <= 1'b0;
            feature_index <= 0;
            feature_edge_count <= 0;
            feature_x_min <= 0; feature_x_max <= 0;
            feature_y_min <= 0; feature_y_max <= 0;
            feature_aspect_ratio_x1000 <= 0;
            feature_contour_steps <= 0;
            feature_contour_valid <= 1'b0;
            analysis_done <= 1'b0;
        end else begin
            replay_start <= 1'b0;
            feature_valid <= 1'b0;
            feature_last <= 1'b0;
            analysis_done <= 1'b0;

            if (ccl_records_done && (analysis_state == A_IDLE)) begin
                process_buffer <= completed_buffer;
                active_index <= 0;
                analysis_state <= A_START;
            end

            if (analysis_state == A_START) begin
                if (have_candidate) begin
                    active_x_min <= cand_x_min[active_index];
                    active_x_max <= cand_x_max[active_index];
                    active_y_min <= cand_y_min[active_index];
                    active_y_max <= cand_y_max[active_index];
                    replay_start <= 1'b1;
                    analysis_state <= A_WAIT_FEATURE;
                end else if (active_index == TOP_K-1) begin
                    analysis_state <= A_FINISH;
                end else begin
                    active_index <= active_index + 1'b1;
                end
            end

            if (contour_feature_valid && (analysis_state == A_WAIT_FEATURE)) begin
                feature_valid <= 1'b1;
                feature_index <= active_index;
                feature_edge_count <= cand_edge_count[active_index];
                feature_x_min <= cand_x_min[active_index];
                feature_x_max <= cand_x_max[active_index];
                feature_y_min <= cand_y_min[active_index];
                feature_y_max <= cand_y_max[active_index];
                feature_aspect_ratio_x1000 <= cand_aspect[active_index];
                feature_contour_steps <= contour_steps;
                feature_contour_valid <= contour_valid;
                if (!later_candidate) begin
                    feature_last <= 1'b1;
                    analysis_state <= A_FINISH;
                end else begin
                    active_index <= active_index + 1'b1;
                    analysis_state <= A_START;
                end
            end

            if (analysis_state == A_FINISH) begin
                analysis_done <= 1'b1;
                analysis_state <= A_IDLE;
            end
        end
    end
endmodule
