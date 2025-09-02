module mod_adder_sync #(
    parameter DATA_WIDTH = 12,
    parameter MODULUS = 3329
)(
    input wire clk,                        // 时钟信号
    input wire rst_n,                      // 复位信号（低有效）
    input wire enable,                     // 使能信号
    input wire [DATA_WIDTH-1:0] a,
    input wire [DATA_WIDTH-1:0] b,
    output reg [DATA_WIDTH-1:0] result,
    output reg valid                       // 结果有效信号
);

    // 内部信号
    wire [DATA_WIDTH:0] sum;
    reg [DATA_WIDTH-1:0] temp_result;
    
    // 组合逻辑：计算模加法
    assign sum = a + b;
    
    always @(*) begin
        if (sum >= MODULUS)
            temp_result = sum - MODULUS;
        else
            temp_result = sum[DATA_WIDTH-1:0];
    end
    
    // 时序逻辑：在时钟边沿更新输出
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 异步复位
            result <= 0;
            valid <= 0;
        end else if (enable) begin
            // 时钟上升沿且使能时更新结果
            result <= temp_result;
            valid <= 1;
        end else begin
            valid <= 0;  // 不使能时清除valid信号
        end
    end

endmodule