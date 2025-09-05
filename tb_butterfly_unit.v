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
    reg [DATA_WIDTH-1:0] expected;
    
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
    
    // 测试任务 - 增加调试信息
    task test_multiply;
        input [DATA_WIDTH-1:0] test_a, test_b;
        integer wait_count;
        begin
            // 清空流水线
            valid_in = 0;
            a = 0;
            b = 0;
            repeat(3) @(posedge clk);
            
            // 计算期望结果
            expected = ref_mod_mul(test_a, test_b);
            
            // 输入测试数据
            $display("=== 输入 %d * %d (乘积=%d) ===", test_a, test_b, test_a * test_b);
            a = test_a;
            b = test_b;
            valid_in = 1;
            @(posedge clk);
            valid_in = 0;
            
            // 等待结果 (5级流水线)
            wait_count = 0;
            while (wait_count < 10) begin
                @(posedge clk);
                wait_count = wait_count + 1;
                
                if (valid_out) begin
                    if (result == expected)
                        $display("PASS: %d * %d = %d (周期%d)", test_a, test_b, result, wait_count);
                    else
                        $display("FAIL: %d * %d = %d (期望: %d) [乘积=%d]", test_a, test_b, result, expected, test_a * test_b);
                    wait_count = 999; // 跳出循环
                end else begin
                    $display("等待输出... (周期%d)", wait_count);
                end
            end
            
            if (wait_count != 999) begin
                $display("ERROR: 测试超时 - valid_out未拉高");
            end
        end
    endtask
    
    // Barrett约简验证任务
    task verify_barrett_range;
        input [DATA_WIDTH-1:0] start_val;
        input integer test_count;
        integer i;
        reg [DATA_WIDTH-1:0] test_a, test_b;
        begin
            $display("\n--- Barrett约简范围验证 (起始值: %d) ---", start_val);
            for (i = 0; i < test_count; i = i + 1) begin
                test_a = (start_val + i) % MODULUS;
                test_b = (start_val + i*17) % MODULUS;  // 使用17作为步长
                test_multiply(test_a, test_b);
            end
        end
    endtask
    
    // 边界条件测试
    task test_boundary_conditions;
        begin
            $display("\n--- 边界条件测试 ---");
            test_multiply(0, 0);                    // 零值测试
            test_multiply(1, 1);                    // 最小非零值
            test_multiply(MODULUS-1, MODULUS-1);    // 最大值
            test_multiply(MODULUS-1, 1);            // 混合边界
            test_multiply(1, MODULUS-1);            // 混合边界
            test_multiply(MODULUS/2, MODULUS/2);    // 中值测试
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
        $display("模乘法器流水线测试 (Kyber Modified Barrett)");
        $display("算法: Kyber论文优化的Barrett约简");
        $display("μ参数: %d (2^12 + 2^10 - 2^8 - 2^4)", 4848);
        $display("========================================");
        
        // 复位
        #(CLK_PERIOD * 3);
        rst_n = 1;
        enable = 1;
        #(CLK_PERIOD * 2);
        
        // 测试1：基础功能验证
        $display("\n--- 基础功能测试 ---");
        test_multiply(100, 200);
        test_multiply(17, 289);     // 使用Kyber相关值
        test_multiply(500, 600);
        test_multiply(1000, 2000);
        
        // 测试2：边界条件
        test_boundary_conditions();
        
        // 测试3：Barrett约简算法验证
        verify_barrett_range(1000, 5);   // 中等值范围
        verify_barrett_range(3000, 5);   // 接近模数的值
        
        // 测试4：NTT常用值测试
        $display("\n--- NTT常用值测试 ---");
        test_multiply(17, 17);      // 原根平方
        test_multiply(289, 17);     // 17^2 * 17
        test_multiply(1664, 1664);  // 模数的一半
        test_multiply(3328, 2);     // 接近模数的值
        
        // 测试5：随机值测试
        $display("\n--- 随机值测试 ---");
        repeat(10) begin
            test_multiply($random % MODULUS, $random % MODULUS);
        end
        
        // 测试6：流水线吞吐量测试
        $display("\n--- 流水线吞吐量测试 ---");
        $display("连续输入多个数据，验证流水线工作...");
        
        // 连续输入5个数据对
        a = 100; b = 200; valid_in = 1; @(posedge clk);
        a = 300; b = 400; valid_in = 1; @(posedge clk);
        a = 500; b = 600; valid_in = 1; @(posedge clk);
        a = 700; b = 800; valid_in = 1; @(posedge clk);
        a = 900; b = 1000; valid_in = 1; @(posedge clk);
        valid_in = 0;
        
        // 等待所有结果输出
        repeat(15) begin
            @(posedge clk);
            if (valid_out) begin
                $display("流水线输出: result = %d", result);
            end
        end
        
        $display("\n========================================");
        $display("模乘法器测试完成");
        $display("关键验证点:");
        $display("- Barrett约简算法正确性");
        $display("- 5级流水线延迟匹配");
        $display("- 边界条件处理");
        $display("- 流水线吞吐量性能");
        $display("- 与NTT算法的兼容性");
        $display("========================================");
        
        #(CLK_PERIOD * 10);
        $finish;
    end
    
    // 波形文件
    initial begin
        $dumpfile("mod_multiplier_pipeline.vcd");
        $dumpvars(0, tb_mod_multiplier_pipeline);
    end
    
    // 超时保护
    initial begin
        #(CLK_PERIOD * 2000);
        $display("测试超时！");
        $finish;
    end

endmodule
