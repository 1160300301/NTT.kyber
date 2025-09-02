module mod_subtractor_pipeline #(
    parameter DATA_WIDTH = 12,
    parameter MODULUS = 3329
)(
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire valid_in,
    input wire [DATA_WIDTH-1:0] a,
    input wire [DATA_WIDTH-1:0] b,
    output reg [DATA_WIDTH-1:0] result,
    output reg valid_out
);

    // 流水线寄存器 - Stage 1
    reg signed [DATA_WIDTH:0] diff_s1;          // 13位有符号，存储a-b
    reg [DATA_WIDTH:0] pre_add_s1;              // 13位，存储a-b+q
    reg valid_s1;
    
    // 流水线寄存器 - Stage 2  
    reg negative_s2;                            // 判断是否为负数
    reg signed [DATA_WIDTH:0] diff_s2;          // 传递diff
    reg [DATA_WIDTH:0] pre_add_s2;              // 传递pre_add
    reg valid_s2;
    
    // Stage 1: 并行计算阶段
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            diff_s1 <= 0;
            pre_add_s1 <= 0;
            valid_s1 <= 0;
        end else begin
            // 并行计算两个可能的结果
            diff_s1 <= $signed({1'b0, a}) - $signed({1'b0, b});     // 普通减法
            pre_add_s1 <= $signed({1'b0, a}) - $signed({1'b0, b}) + MODULUS;  // 预加模数
            valid_s1 <= enable & valid_in;
        end
    end
    
    // Stage 2: 符号判断阶段
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            negative_s2 <= 0;
            diff_s2 <= 0;
            pre_add_s2 <= 0;
            valid_s2 <= 0;
        end else begin
            // 判断差值是否为负
            negative_s2 <= (diff_s1 < 0);
            // 传递计算结果到下一级
            diff_s2 <= diff_s1;
            pre_add_s2 <= pre_add_s1;
            valid_s2 <= valid_s1;
        end
    end
    
    // Stage 3: 最终选择阶段
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            valid_out <= 0;
        end else begin
            // 根据符号选择最终输出
            if (negative_s2)
                result <= pre_add_s2[DATA_WIDTH-1:0];  // 负数时使用a-b+q
            else
                result <= diff_s2[DATA_WIDTH-1:0];     // 非负时使用a-b
            valid_out <= valid_s2;
        end
    end

endmodule