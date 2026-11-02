 
 
 
 
 
 
 
 
 
 
 
 
module shape_run_ccl_topk #(
    parameter integer MAX_RUNS_PER_ROW = 64,
    parameter integer MAX_LABELS       = 64,
    parameter integer TOP_K            = 3,
    parameter integer X_WIDTH          = 9,
    parameter integer Y_WIDTH          = 9
) (
    input                    clk,
    input                    rst_n,
    input                    run_valid,
    input      [X_WIDTH-1:0] run_x_start,
    input      [X_WIDTH-1:0] run_x_end,
    input      [Y_WIDTH-1:0] run_y,
    input      [31:0]        run_weight,
    input                    row_done,
    input                    frame_done_i,
    output reg               record_valid,
    output reg               record_last,
    output reg [((TOP_K <= 2) ? 1 : $clog2(TOP_K))-1:0] record_index,
    output reg [((MAX_LABELS <= 2) ? 1 : $clog2(MAX_LABELS))-1:0] record_label,
    output reg [31:0]        record_edge_count,
    output reg [X_WIDTH-1:0] record_x_min,
    output reg [X_WIDTH-1:0] record_x_max,
    output reg [Y_WIDTH-1:0] record_y_min,
    output reg [Y_WIDTH-1:0] record_y_max,
    output reg [31:0]        record_aspect_ratio_x1000,
    output reg               records_done,
    output reg               overflow
);
    localparam integer LABEL_WIDTH = (MAX_LABELS <= 2) ? 1 : $clog2(MAX_LABELS);
    localparam integer INDEX_WIDTH = (TOP_K <= 2) ? 1 : $clog2(TOP_K);
    localparam [1:0] ST_CAPTURE = 2'd0;
    localparam [1:0] ST_SCAN    = 2'd1;
    localparam [1:0] ST_EMIT    = 2'd2;
    reg [1:0] state;

    reg [X_WIDTH-1:0] prev_start [0:MAX_RUNS_PER_ROW-1];
    reg [X_WIDTH-1:0] prev_end   [0:MAX_RUNS_PER_ROW-1];
    reg [LABEL_WIDTH-1:0] prev_label [0:MAX_RUNS_PER_ROW-1];
    reg [X_WIDTH-1:0] curr_start [0:MAX_RUNS_PER_ROW-1];
    reg [X_WIDTH-1:0] curr_end   [0:MAX_RUNS_PER_ROW-1];
    reg [LABEL_WIDTH-1:0] curr_label [0:MAX_RUNS_PER_ROW-1];
    reg [LABEL_WIDTH:0] prev_count, curr_count;

    reg [LABEL_WIDTH-1:0] parent [0:MAX_LABELS-1];
    reg [31:0] comp_count [0:MAX_LABELS-1];
    reg [X_WIDTH-1:0] comp_x_min [0:MAX_LABELS-1];
    reg [X_WIDTH-1:0] comp_x_max [0:MAX_LABELS-1];
    reg [Y_WIDTH-1:0] comp_y_min [0:MAX_LABELS-1];
    reg [Y_WIDTH-1:0] comp_y_max [0:MAX_LABELS-1];
    reg [LABEL_WIDTH-1:0] next_label;

    reg [31:0] top_count [0:TOP_K-1];
    reg [LABEL_WIDTH-1:0] top_label [0:TOP_K-1];
    reg [X_WIDTH-1:0] top_x_min [0:TOP_K-1];
    reg [X_WIDTH-1:0] top_x_max [0:TOP_K-1];
    reg [Y_WIDTH-1:0] top_y_min [0:TOP_K-1];
    reg [Y_WIDTH-1:0] top_y_max [0:TOP_K-1];
    reg [LABEL_WIDTH-1:0] scan_index;
    reg [INDEX_WIDTH-1:0] emit_index;

    integer i;
    integer j;
    reg [LABEL_WIDTH-1:0] tmp_base;
    reg [LABEL_WIDTH-1:0] tmp_root;
    reg tmp_found;
    reg [31:0] tmp_count;
    reg [X_WIDTH-1:0] tmp_x_min, tmp_x_max;
    reg [Y_WIDTH-1:0] tmp_y_min, tmp_y_max;
    reg [31:0] tmp_run_length;
    reg [LABEL_WIDTH-1:0] scan_root;
    reg [31:0] scan_count;
    reg [X_WIDTH-1:0] scan_x_min, scan_x_max;
    reg [Y_WIDTH-1:0] scan_y_min, scan_y_max;
    reg [31:0] swap_count;
    reg [LABEL_WIDTH-1:0] swap_label;
    reg [X_WIDTH-1:0] swap_x_min, swap_x_max;
    reg [Y_WIDTH-1:0] swap_y_min, swap_y_max;

    function automatic [LABEL_WIDTH-1:0] find_root;
        input [LABEL_WIDTH-1:0] start_label;
        integer k;
        reg [LABEL_WIDTH-1:0] r;
        begin
            r = start_label;
            for (k = 0; k < MAX_LABELS; k = k + 1)
                if (parent[r] != r) r = parent[r];
            find_root = r;
        end
    endfunction

     
    function automatic [31:0] ratio_x1000;
        input [X_WIDTH:0] width_i;
        input [Y_WIDTH:0] height_i;
        reg [X_WIDTH:0] max_dim;
        reg [Y_WIDTH:0] min_dim;
        reg [31:0] dividend;
        reg [31:0] divisor;
        reg [32:0] remainder;
        reg [31:0] quotient;
        integer bit_no;
        begin
            if (width_i >= height_i) begin
                max_dim = width_i;
                min_dim = height_i;
            end else begin
                max_dim = height_i;
                min_dim = width_i;
            end
             
            dividend = ({21'd0, max_dim} << 10) -
                       ({21'd0, max_dim} << 4) -
                       ({21'd0, max_dim} << 3);
            divisor = {20'd0, min_dim};
            remainder = 0;
            quotient = 0;
            if (divisor != 0) begin
                for (bit_no = 31; bit_no >= 0; bit_no = bit_no - 1) begin
                    remainder = {remainder[31:0], dividend[bit_no]};
                    if (remainder >= {1'b0, divisor}) begin
                        remainder = remainder - {1'b0, divisor};
                        quotient[bit_no] = 1'b1;
                    end
                end
            end
            ratio_x1000 = quotient;
        end
    endfunction

    wire [31:0] run_length = {{(32-X_WIDTH){1'b0}}, run_x_end} -
                              {{(32-X_WIDTH){1'b0}}, run_x_start} + 32'd1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_CAPTURE;
            prev_count <= 0;
            curr_count <= 0;
            next_label <= {{(LABEL_WIDTH-1){1'b0}},1'b1};
            scan_index <= 0;
            emit_index <= 0;
            record_valid <= 1'b0;
            record_last <= 1'b0;
            record_index <= 0;
            record_label <= 0;
            record_edge_count <= 0;
            record_x_min <= 0;
            record_x_max <= 0;
            record_y_min <= 0;
            record_y_max <= 0;
            record_aspect_ratio_x1000 <= 0;
            records_done <= 1'b0;
            overflow <= 1'b0;
            for (j = 0; j < MAX_RUNS_PER_ROW; j = j + 1) begin
                prev_start[j] <= 0; prev_end[j] <= 0; prev_label[j] <= 0;
                curr_start[j] <= 0; curr_end[j] <= 0; curr_label[j] <= 0;
            end
            for (j = 0; j < MAX_LABELS; j = j + 1) begin
                parent[j] <= j[LABEL_WIDTH-1:0];
                comp_count[j] <= 0;
                comp_x_min[j] <= {X_WIDTH{1'b1}};
                comp_x_max[j] <= 0;
                comp_y_min[j] <= {Y_WIDTH{1'b1}};
                comp_y_max[j] <= 0;
            end
            for (j = 0; j < TOP_K; j = j + 1) begin
                top_count[j] <= 0; top_label[j] <= 0;
                top_x_min[j] <= 0; top_x_max[j] <= 0;
                top_y_min[j] <= 0; top_y_max[j] <= 0;
            end
        end else begin
            record_valid <= 1'b0;
            record_last <= 1'b0;
            records_done <= 1'b0;

            if (state == ST_CAPTURE) begin
                if (run_valid) begin
                    tmp_found = 1'b0;
                    tmp_base = 0;
                    tmp_count = 0;
                    tmp_x_min = {X_WIDTH{1'b1}};
                    tmp_x_max = 0;
                    tmp_y_min = {Y_WIDTH{1'b1}};
                    tmp_y_max = 0;

                     
                     
                    for (i = 0; i < MAX_RUNS_PER_ROW; i = i + 1) begin
                        if ((i < prev_count) &&
                            ({1'b0,run_x_end} + 1'b1 >= {1'b0,prev_start[i]}) &&
                            ({1'b0,run_x_start} <= {1'b0,prev_end[i]} + 1'b1)) begin
                            tmp_root = find_root(prev_label[i]);
                            if (!tmp_found) begin
                                tmp_found = 1'b1;
                                tmp_base = tmp_root;
                                tmp_count = comp_count[tmp_root];
                                tmp_x_min = comp_x_min[tmp_root];
                                tmp_x_max = comp_x_max[tmp_root];
                                tmp_y_min = comp_y_min[tmp_root];
                                tmp_y_max = comp_y_max[tmp_root];
                            end else if (tmp_root != tmp_base) begin
                                parent[tmp_root] <= tmp_base;
                                tmp_count = tmp_count + comp_count[tmp_root];
                                if (comp_x_min[tmp_root] < tmp_x_min) tmp_x_min = comp_x_min[tmp_root];
                                if (comp_x_max[tmp_root] > tmp_x_max) tmp_x_max = comp_x_max[tmp_root];
                                if (comp_y_min[tmp_root] < tmp_y_min) tmp_y_min = comp_y_min[tmp_root];
                                if (comp_y_max[tmp_root] > tmp_y_max) tmp_y_max = comp_y_max[tmp_root];
                            end
                        end
                    end

                    if (!tmp_found) begin
                        if ((next_label < MAX_LABELS) && (next_label != 0)) begin
                            tmp_base = next_label;
                            next_label <= next_label + 1'b1;
                            tmp_count = 0;
                            tmp_x_min = {X_WIDTH{1'b1}};
                            tmp_x_max = 0;
                            tmp_y_min = {Y_WIDTH{1'b1}};
                            tmp_y_max = 0;
                        end else begin
                            tmp_base = 0;
                            overflow <= 1'b1;
                        end
                    end

                    if ((tmp_base != 0) && (curr_count < MAX_RUNS_PER_ROW)) begin
                         
                         
                         
                        tmp_count = tmp_count + run_weight;
                        if (run_x_start < tmp_x_min) tmp_x_min = run_x_start;
                        if (run_x_end > tmp_x_max) tmp_x_max = run_x_end;
                        if (run_y < tmp_y_min) tmp_y_min = run_y;
                        if (run_y > tmp_y_max) tmp_y_max = run_y;
                        comp_count[tmp_base] <= tmp_count;
                        comp_x_min[tmp_base] <= tmp_x_min;
                        comp_x_max[tmp_base] <= tmp_x_max;
                        comp_y_min[tmp_base] <= tmp_y_min;
                        comp_y_max[tmp_base] <= tmp_y_max;
                        curr_start[curr_count] <= run_x_start;
                        curr_end[curr_count] <= run_x_end;
                        curr_label[curr_count] <= tmp_base;
                        curr_count <= curr_count + 1'b1;
                    end else if (tmp_base != 0) begin
                        overflow <= 1'b1;
                    end
                end

                if (row_done) begin
                    for (j = 0; j < MAX_RUNS_PER_ROW; j = j + 1) begin
                        prev_start[j] <= curr_start[j];
                        prev_end[j] <= curr_end[j];
                        prev_label[j] <= curr_label[j];
                    end
                    prev_count <= curr_count;
                    curr_count <= 0;
                end

                if (frame_done_i) begin
                    state <= ST_SCAN;
                    scan_index <= {{(LABEL_WIDTH-1){1'b0}},1'b1};
                    for (j = 0; j < TOP_K; j = j + 1) begin
                        top_count[j] <= 0; top_label[j] <= 0;
                        top_x_min[j] <= 0; top_x_max[j] <= 0;
                        top_y_min[j] <= 0; top_y_max[j] <= 0;
                    end
                end
            end else if (state == ST_SCAN) begin
                 
                scan_root = find_root(scan_index);
                scan_count = (scan_root == scan_index) ? comp_count[scan_root] : 0;
                scan_x_min = comp_x_min[scan_root];
                scan_x_max = comp_x_max[scan_root];
                scan_y_min = comp_y_min[scan_root];
                scan_y_max = comp_y_max[scan_root];
                if (scan_count != 0) begin
                    for (i = 0; i < TOP_K; i = i + 1) begin
                        if (scan_count > top_count[i]) begin
                            swap_count = top_count[i];
                            swap_label = top_label[i];
                            swap_x_min = top_x_min[i]; swap_x_max = top_x_max[i];
                            swap_y_min = top_y_min[i]; swap_y_max = top_y_max[i];
                            top_count[i] <= scan_count;
                            top_label[i] <= scan_root;
                            top_x_min[i] <= scan_x_min;
                            top_x_max[i] <= scan_x_max;
                            top_y_min[i] <= scan_y_min;
                            top_y_max[i] <= scan_y_max;
                            scan_count = swap_count;
                            scan_root = swap_label;
                            swap_x_min = top_x_min[i];
                            swap_x_max = top_x_max[i];
                            swap_y_min = top_y_min[i];
                            swap_y_max = top_y_max[i];
                            scan_x_min = swap_x_min;
                            scan_x_max = swap_x_max;
                            scan_y_min = swap_y_min;
                            scan_y_max = swap_y_max;
                        end
                    end
                end
                if (scan_index == MAX_LABELS-1) begin
                    state <= ST_EMIT;
                    emit_index <= 0;
                end else begin
                    scan_index <= scan_index + 1'b1;
                end
            end else begin
                 
                 
                 
                record_index <= emit_index;
                record_label <= top_label[emit_index];
                record_edge_count <= top_count[emit_index];
                record_x_min <= top_x_min[emit_index];
                record_x_max <= top_x_max[emit_index];
                record_y_min <= top_y_min[emit_index];
                record_y_max <= top_y_max[emit_index];
                record_aspect_ratio_x1000 <= ratio_x1000(
                    {1'b0,top_x_max[emit_index]} - {1'b0,top_x_min[emit_index]} + 1'b1,
                    {1'b0,top_y_max[emit_index]} - {1'b0,top_y_min[emit_index]} + 1'b1);
                record_valid <= (top_count[emit_index] != 0);
                record_last <= (emit_index == TOP_K-1);
                if (emit_index == TOP_K-1) begin
                    records_done <= 1'b1;
                    state <= ST_CAPTURE;
                    prev_count <= 0;
                    curr_count <= 0;
                    next_label <= {{(LABEL_WIDTH-1){1'b0}},1'b1};
                    for (j = 0; j < MAX_LABELS; j = j + 1) begin
                        parent[j] <= j[LABEL_WIDTH-1:0];
                        comp_count[j] <= 0;
                        comp_x_min[j] <= {X_WIDTH{1'b1}};
                        comp_x_max[j] <= 0;
                        comp_y_min[j] <= {Y_WIDTH{1'b1}};
                        comp_y_max[j] <= 0;
                    end
                end else begin
                    emit_index <= emit_index + 1'b1;
                end
            end
        end
    end
endmodule
