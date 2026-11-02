 
 
module shape_erosion_multi_candidate_top #(
    parameter IMAGE_WIDTH=1920, IMAGE_HEIGHT=1080, POOL=4, TOP_K=3,
    parameter LABEL_BITS=12, MIN_EDGES=64, MAX_WALK=65536
)(
    input clk,rst_n,in_vsync,in_href,edge_valid,
    input [7:0] edge_data,
    output feature_valid,feature_last,
    output [1:0] feature_index,
    output [31:0] feature_edge_count,
    output [10:0] feature_x_min,feature_x_max,feature_y_min,feature_y_max,
    output [31:0] feature_aspect_ratio_x1000,feature_contour_steps_grid,
    output feature_contour_valid,analysis_done,analysis_overrun,
    output [1:0] feature_walk_status,
    output analysis_busy,
    output [31:0] processing_cycles
);
    localparam GW=IMAGE_WIDTH/4,GH=IMAGE_HEIGHT/4,GXW=$clog2(GW),GYW=$clog2(GH);
    wire gv,ge,gl,gf;
    wire [4:0] weight;
    wire [GXW-1:0] gx,x0,x1;
    wire [GYW-1:0] gy,y0,y1;
    wire [15:0] aspect;
    shape_edge_pool4 #(.IMAGE_WIDTH(IMAGE_WIDTH),.IMAGE_HEIGHT(IMAGE_HEIGHT),.POOL(4)) u_pool (
        .clk(clk),.rst_n(rst_n),.in_vsync(in_vsync),.in_href(in_href),
        .edge_valid(edge_valid),.edge_data(edge_data),.grid_valid(gv),.grid_edge(ge),
        .grid_edge_weight(weight),.grid_row_last(gl),.grid_frame_last(gf),.grid_x(gx),.grid_y(gy)
    );
    erosion_run_analyzer #(.W(GW),.H(GH),.LB(LABEL_BITS),.MIN_EDGES(MIN_EDGES),.MAX_WALK(MAX_WALK)) u_analyzer (
        .clk(clk),.rst_n(rst_n),.grid_valid(gv),.grid_weight(weight),.grid_x(gx),.grid_y(gy),
        .feature_valid(feature_valid),.feature_index(feature_index),.feature_edges(feature_edge_count),
        .feature_x0(x0),.feature_x1(x1),.feature_y0(y0),.feature_y1(y1),
        .feature_aspect(aspect),.feature_steps(feature_contour_steps_grid),
        .feature_walk_status(feature_walk_status),.analysis_done(analysis_done),
        .analysis_error(analysis_overrun),.busy(analysis_busy),.processing_cycles(processing_cycles)
    );
    assign feature_x_min={{(11-GXW){1'b0}},x0}<<2;
    assign feature_x_max=({{(11-GXW){1'b0}},x1}<<2)+11'd3;
    assign feature_y_min={{(11-GYW){1'b0}},y0}<<2;
    assign feature_y_max=({{(11-GYW){1'b0}},y1}<<2)+11'd3;
    assign feature_aspect_ratio_x1000={16'd0,aspect};
    assign feature_contour_valid=feature_walk_status==0;
    assign feature_last=feature_index==2;
endmodule
