 
 
 
module median_filter_3x3 (
    input  [7:0] p00,
    input  [7:0] p01,
    input  [7:0] p02,
    input  [7:0] p10,
    input  [7:0] p11,
    input  [7:0] p12,
    input  [7:0] p20,
    input  [7:0] p21,
    input  [7:0] p22,
    input        window_valid,
    output reg [7:0] median_data,
    output reg       median_valid
);

    reg [7:0] row0_min, row0_mid, row0_max;
    reg [7:0] row1_min, row1_mid, row1_max;
    reg [7:0] row2_min, row2_mid, row2_max;
    reg [7:0] row0_a, row0_b, row0_c;
    reg [7:0] row1_a, row1_b, row1_c;
    reg [7:0] row2_a, row2_b, row2_c;
    reg [7:0] swap_value;
    reg [7:0] max_of_mins;
    reg [7:0] min_of_maxs;
    reg [7:0] median_of_mids;
    reg [7:0] median_value;

    function [7:0] min3;
        input [7:0] a;
        input [7:0] b;
        input [7:0] c;
        begin
            min3 = (a < b) ? ((a < c) ? a : c) :
                   ((b < c) ? b : c);
        end
    endfunction

    function [7:0] max3;
        input [7:0] a;
        input [7:0] b;
        input [7:0] c;
        begin
            max3 = (a > b) ? ((a > c) ? a : c) :
                   ((b > c) ? b : c);
        end
    endfunction

    function [7:0] median3;
        input [7:0] a;
        input [7:0] b;
        input [7:0] c;
        reg [7:0] x;
        reg [7:0] y;
        reg [7:0] z;
        reg [7:0] t;
        begin
            x = a;
            y = b;
            z = c;
            if (x > y) begin t = x; x = y; y = t; end
            if (y > z) begin t = y; y = z; z = t; end
            if (x > y) begin t = x; x = y; y = t; end
            median3 = y;
        end
    endfunction

    always @* begin
         
        row0_a = p00;
        row0_b = p01;
        row0_c = p02;
        if (row0_a > row0_b) begin swap_value = row0_a; row0_a = row0_b; row0_b = swap_value; end
        if (row0_b > row0_c) begin swap_value = row0_b; row0_b = row0_c; row0_c = swap_value; end
        if (row0_a > row0_b) begin swap_value = row0_a; row0_a = row0_b; row0_b = swap_value; end
        row0_min = row0_a;
        row0_mid = row0_b;
        row0_max = row0_c;

         
        row1_a = p10;
        row1_b = p11;
        row1_c = p12;
        if (row1_a > row1_b) begin swap_value = row1_a; row1_a = row1_b; row1_b = swap_value; end
        if (row1_b > row1_c) begin swap_value = row1_b; row1_b = row1_c; row1_c = swap_value; end
        if (row1_a > row1_b) begin swap_value = row1_a; row1_a = row1_b; row1_b = swap_value; end
        row1_min = row1_a;
        row1_mid = row1_b;
        row1_max = row1_c;

         
        row2_a = p20;
        row2_b = p21;
        row2_c = p22;
        if (row2_a > row2_b) begin swap_value = row2_a; row2_a = row2_b; row2_b = swap_value; end
        if (row2_b > row2_c) begin swap_value = row2_b; row2_b = row2_c; row2_c = swap_value; end
        if (row2_a > row2_b) begin swap_value = row2_a; row2_a = row2_b; row2_b = swap_value; end
        row2_min = row2_a;
        row2_mid = row2_b;
        row2_max = row2_c;

         
        max_of_mins  = max3(row0_min, row1_min, row2_min);
        min_of_maxs  = min3(row0_max, row1_max, row2_max);
        median_of_mids = median3(row0_mid, row1_mid, row2_mid);
        median_value = median3(max_of_mins, min_of_maxs, median_of_mids);
        swap_value = 8'd0;

        if (window_valid) begin
            median_data  = median_value;
            median_valid = 1'b1;
        end else begin
            median_data  = 8'd0;
            median_valid = 1'b0;
        end
    end

endmodule
