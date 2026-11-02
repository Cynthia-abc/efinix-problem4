 
 
 
 
 
 
 
module hu_features (
    input clk, input rst_n, input start,
    input [47:0] m00, m10, m01, m20, m11, m02,
    output reg busy, output reg done, output reg feature_valid,
    output reg [31:0] hu1_q24, hu2_q24, hu_det_q24
);
    reg [47:0] a, sx, sy, sxx, sxy, syy;
    reg [5:0] state, operation;
    reg [127:0] cxx, cyy, cxy_abs, a2, a3, a6;
    reg [127:0] temp, xy_square, diagonal_product, difference_square;
    reg [127:0] operand_a, operand_b;
    reg arith_start, divide;
    wire arith_done, arith_busy, divzero;
    wire [127:0] value;
    hu_serial_arithmetic u_math (
        .clk(clk), .rst_n(rst_n), .start(arith_start), .divide(divide),
        .operand_a(operand_a), .operand_b(operand_b),
        .busy(arith_busy), .done(arith_done), .divide_by_zero(divzero), .result(value)
    );
    localparam IDLE=0, ISSUE=1, WAIT_RESULT=2, FINISH=3;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state<=IDLE; operation<=0; busy<=0; done<=0; feature_valid<=0;
            a<=0; sx<=0; sy<=0; sxx<=0; sxy<=0; syy<=0;
            cxx<=0; cyy<=0; cxy_abs<=0; a2<=0; a3<=0; a6<=0;
            temp<=0; xy_square<=0; diagonal_product<=0; difference_square<=0;
            operand_a<=0; operand_b<=0; arith_start<=0; divide<=0;
            hu1_q24<=0; hu2_q24<=0; hu_det_q24<=0;
        end else begin
            done<=0; arith_start<=0;
            case(state)
                IDLE: if(start) begin
                    a<=m00; sx<=m10; sy<=m01; sxx<=m20; sxy<=m11; syy<=m02;
                    busy<=1; feature_valid<=0; operation<=0;
                    hu1_q24<=0; hu2_q24<=0; hu_det_q24<=0;
                    if(m00==0 || m00>65536) state<=FINISH;
                    else state<=ISSUE;
                end
                ISSUE: begin
                    divide<=0; arith_start<=1; state<=WAIT_RESULT;
                    case(operation)
                        0: begin operand_a<=a; operand_b<=sxx; end
                        1: begin operand_a<=sx; operand_b<=sx; end
                        2: begin operand_a<=a; operand_b<=syy; end
                        3: begin operand_a<=sy; operand_b<=sy; end
                        4: begin operand_a<=a; operand_b<=sxy; end
                        5: begin operand_a<=sx; operand_b<=sy; end
                        6: begin operand_a<=a; operand_b<=a; end
                        7: begin operand_a<=a2; operand_b<=a; end
                        8: begin operand_a<=a3; operand_b<=a3; end
                        9: begin operand_a<=cxy_abs; operand_b<=cxy_abs; end
                        10: begin operand_a<=cxx; operand_b<=cyy; end
                        11: begin
                            operand_a<=(cxx>=cyy)?cxx-cyy:cyy-cxx;
                            operand_b<=(cxx>=cyy)?cxx-cyy:cyy-cxx;
                        end
                        12: begin divide<=1; operand_a<=(cxx+cyy)<<24; operand_b<=a3; end
                        13: begin divide<=1; operand_a<=(difference_square+(xy_square<<2))<<24; operand_b<=a6; end
                        14: begin divide<=1; operand_a<=(diagonal_product-xy_square)<<26; operand_b<=a6; end
                        default: begin arith_start<=0; state<=FINISH; end
                    endcase
                end
                WAIT_RESULT: if(arith_done) begin
                    case(operation)
                        0,2,4: temp<=value;
                        1: cxx<=temp-value;
                        3: cyy<=temp-value;
                        5: cxy_abs<=(temp>=value)?temp-value:value-temp;
                        6: a2<=value;
                        7: a3<=value;
                        8: a6<=value;
                        9: xy_square<=value;
                        10: diagonal_product<=value;
                        11: difference_square<=value;
                        12: hu1_q24<= (|value[127:32])?32'hffffffff:value[31:0];
                        13: hu2_q24<= (|value[127:32])?32'hffffffff:value[31:0];
                        14: begin
                            hu_det_q24<=(|value[127:32])?32'hffffffff:value[31:0];
                            feature_valid<=!divzero && diagonal_product>=xy_square;
                        end
                    endcase
                    if(operation==14) state<=FINISH;
                    else begin operation<=operation+1'b1; state<=ISSUE; end
                end
                FINISH: begin busy<=0; done<=1; state<=IDLE; end
            endcase
        end
    end
endmodule
