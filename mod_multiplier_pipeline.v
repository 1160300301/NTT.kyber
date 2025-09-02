// ========================================================================
// 修正版DSP48优化的5级流水线模乘法器
// 使用修正的Barrett约简算法
// 文件: mod_multiplier_pipeline.v
// ========================================================================

module mod_multiplier_pipeline #(
    parameter DATA_WIDTH = 12,
    parameter MODULUS = 3329,
    // 修正的Barrett约简预计算常数
    parameter BARRETT_MU = 5040,        // floor(2^24/3329) = 5040
    parameter BARRETT_K = 12
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

    // 临时计算变量
    reg [31:0] temp_result;

    // 流水线寄存器 - Stage 1-2: DSP48乘法
    reg [23:0] product_s1;
    reg valid_s1;
    
    reg [23:0] product_s2;
    reg valid_s2;
    
    // 流水线寄存器 - Stage 3: Barrett预约简
    reg [23:0] product_s3;
    reg [23:0] barrett_est_s3;
    reg valid_s3;
    
    // 流水线寄存器 - Stage 4: 约简计算
    reg [31:0] reduction_s4;            // 增加位宽避免溢出
    reg [23:0] product_s4;
    reg valid_s4;
    
    // Stage 1: 乘法计算（DSP48第一级）
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product_s1 <= 0;
            valid_s1 <= 0;
        end else begin
            product_s1 <= a * b;
            valid_s1 <= enable & valid_in;
        end
    end
    
    // Stage 2: 乘法流水线（DSP48第二级）
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product_s2 <= 0;
            valid_s2 <= 0;
        end else begin
            product_s2 <= product_s1;
            valid_s2 <= valid_s1;
        end
    end
    
    // Stage 3: 修正的Barrett预约简
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product_s3 <= 0;
            barrett_est_s3 <= 0;
            valid_s3 <= 0;
        end else begin
            product_s3 <= product_s2;
            // 修正的Barrett估算，避免溢出
            barrett_est_s3 <= ((product_s2 >> (BARRETT_K - 2)) * BARRETT_MU) >> (BARRETT_K + 2);
            valid_s3 <= valid_s2;
        end
    end
    
    // Stage 4: 约简计算
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reduction_s4 <= 0;
            product_s4 <= 0;
            valid_s4 <= 0;
        end else begin
            reduction_s4 <= barrett_est_s3 * MODULUS;
            product_s4 <= product_s3;
            valid_s4 <= valid_s3;
        end
    end
    
    // Stage 5: 最终约简和双重条件修正
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            valid_out <= 0;
        end else begin
            // Barrett约简
            temp_result = product_s4 - reduction_s4;
            
            // 双重条件修正：Barrett约简最多需要2次修正
            if (temp_result >= (2 * MODULUS))
                result <= temp_result - (2 * MODULUS);
            else if (temp_result >= MODULUS)
                result <= temp_result - MODULUS;
            else
                result <= temp_result[DATA_WIDTH-1:0];
                
            valid_out <= valid_s4;
        end
    end

endmodule