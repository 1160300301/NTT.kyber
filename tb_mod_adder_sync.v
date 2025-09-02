`timescale 1ns / 1ps

module tb_mod_adder_sync;

    // 测试参数
    parameter DATA_WIDTH = 12;
    parameter MODULUS = 3329;
    parameter CLK_PERIOD = 10;  // 10ns = 100MHz
    
    // 测试信号
    reg clk;
    reg rst_n;
    reg enable;
    reg [DATA_WIDTH-1:0] a;
    reg [DATA_WIDTH-1:0] b;
    wire [DATA_WIDTH-1:0] result;
    wire valid;
    
    // 测试控制
    reg [DATA_WIDTH-1:0] expected;
    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;
    
    // 实例化被测模块
    mod_adder_sync #(
        .DATA_WIDTH(DATA_WIDTH),
        .MODULUS(MODULUS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .a(a),
        .b(b),
        .result(result),
        .valid(valid)
    );
    
    // 时钟生成
    always #(CLK_PERIOD/2) clk = ~clk;
    
    // 参考模型
    function [DATA_WIDTH-1:0] ref_mod_add;
        input [DATA_WIDTH-1:0] x, y;
        reg [DATA_WIDTH:0] temp;
        begin
            temp = x + y;
            ref_mod_add = (temp >= MODULUS) ? temp - MODULUS : temp;
        end
    endfunction
    
    // 同步测试任务
   task test_sync_case;
    input [DATA_WIDTH-1:0] test_a, test_b;
    begin
        // 设置输入
        a = test_a;
        b = test_b;
        expected = ref_mod_add(test_a, test_b);
        enable = 1;
        
        // 等待一个时钟周期 - 输入被采样
        @(posedge clk);
        
        // 再等一个时钟周期 - 结果出来了
        @(posedge clk);  // 添加这一行！
        
        // 现在检查结果
        if (!valid) begin
            $display("ERROR: valid信号未拉高");
            fail_count = fail_count + 1;
        end else begin
            test_count = test_count + 1;
            if (result == expected) begin
                pass_count = pass_count + 1;
                $display("PASS: %d + %d = %d", test_a, test_b, result);
            end else begin
                fail_count = fail_count + 1;
                $display("FAIL: %d + %d = %d (expected %d)", test_a, test_b, result, expected);
            end
        end
        
        enable = 0;
        @(posedge clk);
    end
endtask
    
    // 测试复位功能
    task test_reset;
        begin
            $display("\n--- 复位功能测试 ---");
            
            // 先设置一些值
            a = 100;
            b = 200;
            enable = 1;
            @(posedge clk);
            
            $display("复位前: result=%d, valid=%d", result, valid);
            
            // 执行复位
            rst_n = 0;
            @(posedge clk);
            @(posedge clk);
            
            if (result == 0 && valid == 0) begin
                $display("? 复位功能正常");
            end else begin
                $display("? 复位功能异常: result=%d, valid=%d", result, valid);
                fail_count = fail_count + 1;
            end
            
            // 释放复位
            rst_n = 1;
            @(posedge clk);
        end
    endtask
    
    // 测试使能控制
    task test_enable_control;
        begin
            $display("\n--- 使能控制测试 ---");
            
            a = 50;
            b = 75;
            
            // 测试使能=0的情况
            enable = 0;
            @(posedge clk);
            
            if (valid == 0) begin
                $display("? 使能=0时valid正确为0");
            end else begin
                $display("? 使能=0时valid应该为0");
                fail_count = fail_count + 1;
            end
            
            // 测试使能=1的情况
            enable = 1;
            @(posedge clk);
            
            if (valid == 1) begin
                $display("? 使能=1时valid正确为1");
            end else begin
                $display("? 使能=1时valid应该为1");
                fail_count = fail_count + 1;
            end
        end
    endtask
    
    // 主测试序列
    initial begin
        // 初始化
        clk = 0;
        rst_n = 0;
        enable = 0;
        a = 0;
        b = 0;
        
        $display("========================================");
        $display("同步模加法器测试开始");
        $display("时钟频率: %d MHz", 1000/CLK_PERIOD);
        $display("========================================");
        
        // 等待几个时钟周期后释放复位
        #(CLK_PERIOD * 3);
        rst_n = 1;
        #(CLK_PERIOD * 2);
        
        // 测试复位功能
        test_reset();
        
        // 测试使能控制
        test_enable_control();
        
        // 测试基本功能
        $display("\n--- 同步功能测试 ---");
        test_sync_case(0, 0);
        test_sync_case(0, 1);
        test_sync_case(MODULUS-1, 1);
        test_sync_case(MODULUS/2, MODULUS/2);
        test_sync_case(1000, 2000);
        test_sync_case(2000, 1500);
        
        // 测试连续操作
        $display("\n--- 连续操作测试 ---");
        begin : random_test_block
            reg [DATA_WIDTH-1:0] rand_a, rand_b;  // 在命名块中声明
            integer i;
            for (i = 0; i < 5; i = i + 1) begin
                rand_a = $random % MODULUS;
                rand_b = $random % MODULUS;
                if (rand_a < 0) rand_a = -rand_a;  // 确保为正数
                if (rand_b < 0) rand_b = -rand_b;
                test_sync_case(rand_a, rand_b);
            end
        end
        
        // 测试背靠背操作（每个周期都输入新数据）
        $display("\n--- 背靠背操作测试 ---");
        enable = 1;  // 持续使能
        
        // 输入序列
        a = 100; b = 200; @(posedge clk);
        a = 300; b = 400; @(posedge clk);  
        a = 1500; b = 1600; @(posedge clk);
        a = 3000; b = 300; @(posedge clk);
        
        enable = 0;
        @(posedge clk);
        
        $display(" 背靠背操作测试完成");
        
        // 结果统计
        $display("\n========================================");
        $display("同步测试完成");
        $display("总测试数: %d", test_count);
        $display("通过: %d", pass_count);
        $display("失败: %d", fail_count);
        
        if (fail_count == 0) begin
            $display("? 同步设计测试全部通过！");
            $display("? 下一步：实现流水线版本");
        end else begin
            $display("?  有 %d 个测试失败，需要检查", fail_count);
        end
        $display("========================================");
        
        #(CLK_PERIOD * 5);
        $finish;
    end
    
    // 波形文件
    initial begin
        $dumpfile("mod_adder_sync.vcd");
        $dumpvars(0, tb_mod_adder_sync);
    end
    
    // 超时保护
    initial begin
        #(CLK_PERIOD * 1000);
        $display("测试超时！");
        $finish;
    end

endmodule