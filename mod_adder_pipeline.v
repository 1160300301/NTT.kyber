module mod_adder_pipeline #(
    parameter DATA_WIDTH = 12,
    parameter MODULUS = 3329
)(
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire valid_in,                    // 输入数据有效信号
    input wire [DATA_WIDTH-1:0] a,
    input wire [DATA_WIDTH-1:0] b,
    output reg [DATA_WIDTH-1:0] result,
    output reg valid_out                    // 输出数据有效信号
);

    // 流水线寄存器 - Stage 1
    reg [DATA_WIDTH:0] sum_s1;              // 13位，存储a+b
    reg [DATA_WIDTH:0] pre_sub_s1;          // 13位，存储a+b-q
    reg valid_s1;
    
    // 流水线寄存器 - Stage 2  
    reg comparison_s2;                      // 比较结果：sum >= MODULUS
    reg [DATA_WIDTH:0] sum_s2;              // 传递sum
    reg [DATA_WIDTH:0] pre_sub_s2;          // 传递pre_sub
    reg valid_s2;
    
    // Stage 1: 并行计算阶段
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum_s1 <= 0;
            pre_sub_s1 <= 0;
            valid_s1 <= 0;
        end else begin
            sum_s1 <= {1'b0, a} + {1'b0, b};
            pre_sub_s1 <= {1'b0, a} + {1'b0, b} - MODULUS;
            valid_s1 <= enable & valid_in;
        end
    end
    
    // Stage 2: 比较和选择准备阶段
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            comparison_s2 <= 0;
            sum_s2 <= 0;
            pre_sub_s2 <= 0;
            valid_s2 <= 0;
        end else begin
            comparison_s2 <= (sum_s1 >= MODULUS);
            sum_s2 <= sum_s1;
            pre_sub_s2 <= pre_sub_s1;
            valid_s2 <= valid_s1;
        end
    end
    
    // Stage 3: 最终选择阶段
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            valid_out <= 0;
        end else begin
            if (comparison_s2)
                result <= pre_sub_s2[DATA_WIDTH-1:0];
            else
                result <= sum_s2[DATA_WIDTH-1:0];
            valid_out <= valid_s2 & ~valid_out;
        end
    end

endmodule