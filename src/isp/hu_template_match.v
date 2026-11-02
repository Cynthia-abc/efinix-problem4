 
 
 
 
 
 
 
module hu_template_match #(
    parameter [31:0] CIRCLE_DET_Q24=32'd424972,
    parameter [31:0] RECT_DET_Q24=32'd466034,
    parameter [31:0] MAX_DISTANCE_Q24=32'd17000,
    parameter [31:0] MIN_DISTANCE_GAP_Q24=32'd6000
) (
    input clk, input rst_n, input feature_done, input feature_valid,
    input [31:0] hu1_q24, hu2_q24, hu_det_q24,
    output reg done, output reg target_valid, output reg [2:0] shape,
    output reg [31:0] match_distance_q24
);
    wire [31:0] dc=(hu_det_q24>=CIRCLE_DET_Q24)?
        hu_det_q24-CIRCLE_DET_Q24:CIRCLE_DET_Q24-hu_det_q24;
    wire [31:0] dr=(hu_det_q24>=RECT_DET_Q24)?
        hu_det_q24-RECT_DET_Q24:RECT_DET_Q24-hu_det_q24;
    wire [31:0] gap=(dc>=dr)?dc-dr:dr-dc;
     
    wire sane=hu1_q24>=32'd2300000 && hu1_q24<=32'd12000000 &&
              hu2_q24<32'd10000000;
     
     
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin done<=0; target_valid<=0; shape<=0; match_distance_q24<=0; end
        else begin
            done<=0;
            if(feature_done) begin
                done<=1; target_valid<=0; shape<=0;
                match_distance_q24<=(dc<dr)?dc:dr;
                if(feature_valid && sane && gap>=MIN_DISTANCE_GAP_Q24 &&
                   ((dc<dr?dc:dr)<=MAX_DISTANCE_Q24)) begin
                    target_valid<=1; shape<=(dc<dr)?3'd1:3'd2;
                end
            end
        end
    end
endmodule
