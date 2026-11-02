 
 
 
 
 
 
 
 
 
module shape_run_ccl_candidate #(
    parameter integer MAX_RUNS_PER_ROW = 16,
    parameter integer MAX_LABELS       = 16,
    parameter integer X_WIDTH          = 11,
    parameter integer Y_WIDTH          = 11
) (
    input                    clk,
    input                    rst_n,
    input                    run_valid,
    input      [X_WIDTH-1:0] run_x_start,
    input      [X_WIDTH-1:0] run_x_end,
    input      [Y_WIDTH-1:0] run_y,
    input                    row_done,
    input                    frame_done_i,
    output reg               run_component_valid,
    output reg [((MAX_LABELS <= 2) ? 1 : $clog2(MAX_LABELS))-1:0] run_component_label,
    output reg               frame_done,
    output reg               candidate_valid,
    output reg [31:0]        candidate_edge_count,
    output reg [X_WIDTH-1:0] candidate_x_min,
    output reg [X_WIDTH-1:0] candidate_x_max,
    output reg [Y_WIDTH-1:0] candidate_y_min,
    output reg [Y_WIDTH-1:0] candidate_y_max,
    output reg [((MAX_LABELS <= 2) ? 1 : $clog2(MAX_LABELS))-1:0] candidate_label
);
    localparam integer LABEL_WIDTH = (MAX_LABELS <= 2) ? 1 : $clog2(MAX_LABELS);
    localparam [LABEL_WIDTH-1:0] TARGET_LABEL = {{(LABEL_WIDTH-1){1'b0}}, 1'b1};

    reg                    have_candidate;
    reg [31:0]             edge_count_acc;
    reg [X_WIDTH-1:0]      x_min_acc, x_max_acc;
    reg [Y_WIDTH-1:0]      y_min_acc, y_max_acc;
    wire [31:0] run_length = {21'd0, run_x_end} -
                             {21'd0, run_x_start} + 32'd1;
    wire [31:0] final_edge_count = edge_count_acc +
                                    (run_valid ? run_length : 32'd0);
    wire [X_WIDTH-1:0] final_x_min =
        (run_valid && (!have_candidate || (run_x_start < x_min_acc))) ?
        run_x_start : x_min_acc;
    wire [X_WIDTH-1:0] final_x_max =
        (run_valid && (!have_candidate || (run_x_end > x_max_acc))) ?
        run_x_end : x_max_acc;
    wire [Y_WIDTH-1:0] final_y_min =
        (run_valid && (!have_candidate || (run_y < y_min_acc))) ?
        run_y : y_min_acc;
    wire [Y_WIDTH-1:0] final_y_max =
        (run_valid && (!have_candidate || (run_y > y_max_acc))) ?
        run_y : y_max_acc;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            have_candidate      <= 1'b0;
            edge_count_acc      <= 32'd0;
            x_min_acc           <= {X_WIDTH{1'b1}};
            x_max_acc           <= {X_WIDTH{1'b0}};
            y_min_acc           <= {Y_WIDTH{1'b1}};
            y_max_acc           <= {Y_WIDTH{1'b0}};
            run_component_valid <= 1'b0;
            run_component_label <= {LABEL_WIDTH{1'b0}};
            frame_done          <= 1'b0;
            candidate_valid     <= 1'b0;
            candidate_edge_count <= 32'd0;
            candidate_x_min     <= {X_WIDTH{1'b0}};
            candidate_x_max     <= {X_WIDTH{1'b0}};
            candidate_y_min     <= {Y_WIDTH{1'b0}};
            candidate_y_max     <= {Y_WIDTH{1'b0}};
            candidate_label     <= {LABEL_WIDTH{1'b0}};
        end else begin
            run_component_valid <= 1'b0;
            frame_done          <= 1'b0;
            candidate_valid     <= 1'b0;

            if (run_valid) begin
                have_candidate      <= 1'b1;
                run_component_valid <= 1'b1;
                run_component_label <= TARGET_LABEL;
                edge_count_acc      <= edge_count_acc + run_length;
                if (!have_candidate || (run_x_start < x_min_acc))
                    x_min_acc <= run_x_start;
                if (!have_candidate || (run_x_end > x_max_acc))
                    x_max_acc <= run_x_end;
                if (!have_candidate || (run_y < y_min_acc))
                    y_min_acc <= run_y;
                if (!have_candidate || (run_y > y_max_acc))
                    y_max_acc <= run_y;
            end

             
             
            if (frame_done_i) begin
                frame_done           <= 1'b1;
                candidate_valid      <= have_candidate;
                candidate_edge_count <= final_edge_count;
                candidate_x_min      <= final_x_min;
                candidate_x_max      <= final_x_max;
                candidate_y_min      <= final_y_min;
                candidate_y_max      <= final_y_max;
                candidate_label      <= have_candidate ? TARGET_LABEL : {LABEL_WIDTH{1'b0}};

                have_candidate <= 1'b0;
                edge_count_acc <= 32'd0;
                x_min_acc      <= {X_WIDTH{1'b1}};
                x_max_acc      <= {X_WIDTH{1'b0}};
                y_min_acc      <= {Y_WIDTH{1'b1}};
                y_max_acc      <= {Y_WIDTH{1'b0}};
            end
        end
    end
endmodule
