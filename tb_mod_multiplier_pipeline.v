`timescale 1ns / 1ps

module tb_mod_multiplier_pipeline;

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
    mod_multiplier_pipeline #(
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
    function [DATA_WIDTH-1:0] ref_mod_mul;
        input [DATA_WIDTH-1:0] x, y;
        reg [23:0] temp;
        begin
            temp = x * y;
            ref_mod_mul = temp % MODULUS;
        end
    endfunction
    
    // 测试任务
    task test_mod_mul;
        input [DATA_WIDTH-1:0] test_a, test_b;
        input [DATA_WIDTH-1:0] expected;
        begin
            a = test_a;
            b = test_b;
            valid_in = 1;
            @(posedge clk);
            valid_in = 0;
            
            // 等待5级流水线结果
            repeat(8) begin
                @(posedge clk);
                if (valid_out) begin
                    if (result == expected)
                        $display("PASS: %d * %d = %d", test_a, test_b, result);
                    else
                        $display("FAIL: %d * %d = %d (期望: %d)", test_a, test_b, result, expected);
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
        $display("DSP48优化模乘法器测试");
        $display("Barrett约简算法 (q=%d)", MODULUS);
        $display("========================================");
        
        // 复位
        #(CLK_PERIOD * 3);
        rst_n = 1;
        enable = 1;
        #(CLK_PERIOD * 2);
        
        // 测试1: 基础乘法测试
        $display("\n--- 基础乘法测试 ---");
        test_mod_mul(0, 100, ref_mod_mul(0, 100));       // 0 * 100 = 0
        test_mod_mul(1, 200, ref_mod_mul(1, 200));       // 1 * 200 = 200
        test_mod_mul(10, 20, ref_mod_mul(10, 20));       // 10 * 20 = 200
        test_mod_mul(100, 30, ref_mod_mul(100, 30));     // 100 * 30 = 3000
        
        // 测试2: 需要模运算的乘法
        $display("\n--- 大数乘法测试（需要模运算） ---");
        test_mod_mul(100, 100, ref_mod_mul(100, 100));   // 10000
        test_mod_mul(200, 200, ref_mod_mul(200, 200));   // 40000 mod 3329
        test_mod_mul(1000, 5, ref_mod_mul(1000, 5));     // 5000 mod 3329
        test_mod_mul(3328, 2, ref_mod_mul(3328, 2));     // 6656 mod 3329 = 6656-3329 = 3327
        
        // 测试3: 边界条件
        $display("\n--- 边界条件测试 ---");
        test_mod_mul(3328, 1, ref_mod_mul(3328, 1));     // 最大值 * 1
        test_mod_mul(3328, 3328, ref_mod_mul(3328, 3328)); // 最大值 * 最大值
        test_mod_mul(1664, 2, ref_mod_mul(1664, 2));     // 接近q/2 的测试
        
        // 测试4: 特殊值测试
        $display("\n--- 特殊值测试 ---");
        test_mod_mul(3329, 1, ref_mod_mul(3329 % MODULUS, 1)); // q * 1 = 0
        
        // 手动验证
        $display("\n--- 手动验证关键结果 ---");
        $display("参考计算:");
        $display("3328 * 2 = 6656, 6656 mod 3329 = 3327");
        $display("200 * 200 = 40000, 40000 mod 3329 = 40000 - 12*3329 = 40000 - 39948 = 52");
        $display("1664 * 2 = 3328 (刚好小于q)");
        
        $display("\n========================================");
        $display("模乘法器测试完成");
        $display("关键特性:");
        $display("- 5级深度流水线");
        $display("- Barrett约简算法");
        $display("- DSP48优化");
        $display("- 支持全范围输入 (0 到 q-1)");
        $display("========================================");
        
        #(CLK_PERIOD * 10);
        $finish;
    end
    
    // 波形文件
    initial begin
        $dumpfile("mod_multiplier_pipeline.vcd");
        $dumpvars(0, tb_mod_multiplier_pipeline);
    end

endmodule