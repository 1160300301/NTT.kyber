`timescale 1ns / 1ps

module tb_mod_subtractor_pipeline;

    // 参数
    parameter DATA_WIDTH = 12;
    parameter MODULUS = 3329;
    parameter CLK_PERIOD = 10;
    
    // 测试信号
    reg clk;
    reg rst_n;
    reg enable;
    reg valid_in;
    reg [DATA_WIDTH-1:0] a;
    reg [DATA_WIDTH-1:0] b;
    wire [DATA_WIDTH-1:0] result;
    wire valid_out;
    
    // 实例化被测模块
    mod_subtractor_pipeline #(
        .DATA_WIDTH(DATA_WIDTH),
        .MODULUS(MODULUS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .valid_in(valid_in),
        .a(a),
        .b(b),
        .result(result),
        .valid_out(valid_out)
    );
    
    // 时钟生成
    always #(CLK_PERIOD/2) clk = ~clk;
    
    // 参考模型
    function [DATA_WIDTH-1:0] ref_mod_sub;
        input [DATA_WIDTH-1:0] x, y;
        reg signed [DATA_WIDTH:0] temp;
        begin
            temp = $signed({1'b0, x}) - $signed({1'b0, y});
            if (temp < 0)
                ref_mod_sub = temp + MODULUS;
            else
                ref_mod_sub = temp;
        end
    endfunction
    
    // 测试任务
    task test_mod_sub;
        input [DATA_WIDTH-1:0] test_a, test_b;
        input [DATA_WIDTH-1:0] expected;
        begin
            a = test_a;
            b = test_b;
            valid_in = 1;
            @(posedge clk);
            valid_in = 0;
            
            // 等待结果
            repeat(6) begin
                @(posedge clk);
                if (valid_out) begin
                    if (result == expected)
                        $display("PASS: %d - %d = %d", test_a, test_b, result);
                    else
                        $display("FAIL: %d - %d = %d (期望: %d)", test_a, test_b, result, expected);
                end
            end
        end
    endtask
    
    // 主测试序列
    initial begin
        // 初始化
        clk = 0;
        rst_n = 0;
        enable = 0;
        valid_in = 0;
        a = 0;
        b = 0;
        
        $display("========================================");
        $display("3级流水线模减法器测试");
        $display("========================================");
        
        // 复位
        #(CLK_PERIOD * 3);
        rst_n = 1;
        enable = 1;
        #(CLK_PERIOD * 2);
        
        // 测试1: 基础减法测试
        $display("\n--- 基础减法测试 ---");
        
        // 正常减法（无需模运算）
        test_mod_sub(200, 100, ref_mod_sub(200, 100));   // 200 - 100 = 100
        test_mod_sub(1000, 500, ref_mod_sub(1000, 500)); // 1000 - 500 = 500
        test_mod_sub(100, 100, ref_mod_sub(100, 100));   // 100 - 100 = 0
        
        // 需要模运算的减法（结果为负）
        $display("\n--- 负数结果测试（需要模运算） ---");
        test_mod_sub(100, 200, ref_mod_sub(100, 200));   // 100 - 200 = -100 -> 3229
        test_mod_sub(0, 1, ref_mod_sub(0, 1));           // 0 - 1 = -1 -> 3328
        test_mod_sub(500, 1000, ref_mod_sub(500, 1000)); // 500 - 1000 = -500 -> 2829
        
        // 边界条件测试
        $display("\n--- 边界条件测试 ---");
        test_mod_sub(3328, 0, ref_mod_sub(3328, 0));     // 最大值 - 0
        test_mod_sub(0, 3328, ref_mod_sub(0, 3328));     // 0 - 最大值
        test_mod_sub(3328, 3328, ref_mod_sub(3328, 3328)); // 最大值 - 最大值 = 0
        
        // 手动验证几个关键结果
        $display("\n--- 手动验证 ---");
        $display("参考计算:");
        $display("100 - 200 = -100, -100 + 3329 = 3229");
        $display("0 - 1 = -1, -1 + 3329 = 3328"); 
        $display("0 - 3328 = -3328, -3328 + 3329 = 1");
        
        $display("\n========================================");
        $display("模减法器测试完成");
        $display("关键特性:");
        $display("- 3级流水线延迟");
        $display("- 自动处理负数情况");
        $display("- 与模加法器兼容的接口");
        $display("========================================");
        
        #(CLK_PERIOD * 5);
        $finish;
    end
    
    // 波形文件
    initial begin
        $dumpfile("mod_subtractor_pipeline.vcd");
        $dumpvars(0, tb_mod_subtractor_pipeline);
    end

endmodule