`timescale 1ns / 1ps

module tb_mod_adder_pipeline;

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
    
    // 测试控制
    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;
    
    // 测试输入队列和期望结果队列
    reg [DATA_WIDTH-1:0] test_a_queue [0:9];
    reg [DATA_WIDTH-1:0] test_b_queue [0:9];
    reg [DATA_WIDTH-1:0] expected_queue [0:9];
    integer input_ptr = 0;
    integer output_ptr = 0;
    integer total_tests = 0;
    
    // 实例化被测模块
    mod_adder_pipeline #(
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
    function [DATA_WIDTH-1:0] ref_mod_add;
        input [DATA_WIDTH-1:0] x, y;
        reg [DATA_WIDTH:0] temp;
        begin
            temp = x + y;
            if (temp >= MODULUS)
                ref_mod_add = temp - MODULUS;
            else
                ref_mod_add = temp;
        end
    endfunction
    
    // 输入测试数据任务
    task send_test_data;
        input [DATA_WIDTH-1:0] test_a, test_b;
        begin
            if (input_ptr < 10) begin
                test_a_queue[input_ptr] = test_a;
                test_b_queue[input_ptr] = test_b;
                expected_queue[input_ptr] = ref_mod_add(test_a, test_b);
                
                a = test_a;
                b = test_b;
                valid_in = 1;
                
                $display("输入[%0d]: %d + %d (期望结果: %d)", 
                         input_ptr, test_a, test_b, expected_queue[input_ptr]);
                
                input_ptr = input_ptr + 1;
                total_tests = total_tests + 1;
            end
        end
    endtask
    
    // 检查输出结果
    always @(posedge clk) begin
        if (valid_out && (output_ptr < total_tests)) begin
            test_count = test_count + 1;
            
            if (result == expected_queue[output_ptr]) begin
                pass_count = pass_count + 1;
                $display("输出[%0d]: %d + %d = %d ?", 
                         output_ptr, test_a_queue[output_ptr], test_b_queue[output_ptr], result);
            end else begin
                fail_count = fail_count + 1;
                $display("输出[%0d]: %d + %d = %d (期望: %d) ?", 
                         output_ptr, test_a_queue[output_ptr], test_b_queue[output_ptr], 
                         result, expected_queue[output_ptr]);
            end
            
            output_ptr = output_ptr + 1;
        end
    end
    
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
        $display("简化流水线测试");
        $display("========================================");
        
        // 复位
        #(CLK_PERIOD * 3);
        rst_n = 1;
        enable = 1;
        #(CLK_PERIOD * 2);
        
        // 测试1：观察流水线延迟
        $display("\n--- 测试1: 流水线延迟观察 ---");
        $display("时间 %0t: 输入 100 + 200", $time);
        a = 100; 
        b = 200; 
        valid_in = 1;
        @(posedge clk);
//        valid_in = 0;  // 只输入一个数据
        
        // 观察5个时钟周期
        repeat(5) begin
            @(posedge clk);
            $display("时间 %0t: valid_out=%d, result=%d %s", 
                     $time, valid_out, result,
                     valid_out ? "(输出有效!)" : "");
        end
        
        // 测试2：连续输入观察
       $display("\n--- 修正版独立输入测试 ---");
    
        // 输入1: 0 + 0
        $display("=== 输入 0 + 0 ===");
        a = 0; b = 0; valid_in = 1; 
        @(posedge clk);
        valid_in = 0;
        
        // 等待这个输入完全处理完
        repeat(6) begin
            @(posedge clk);
            if (valid_out) 
                $display("输出1: %d (期望: 0)", result);
            else
                $display("等待输出1...");
        end
        
        // 输入2: 1 + 2  
        $display("=== 输入 1 + 2 ===");
        a = 1; b = 2; valid_in = 1;
        @(posedge clk);
        valid_in = 0;
        
        repeat(6) begin
            @(posedge clk);
            if (valid_out) 
                $display("输出2: %d (期望: 3)", result);
            else
                $display("等待输出2...");
        end
        
        // 输入3: 3328 + 1
        $display("=== 输入 3328 + 1 ===");
        a = 3328; b = 1; valid_in = 1;
        @(posedge clk);
        valid_in = 0;
        
        repeat(6) begin
            @(posedge clk);
            if (valid_out) 
                $display("输出3: %d (期望: 0)", result);
            else
                $display("等待输出3...");
        end
        
        // 测试3：手动验证几个结果
        $display("\n--- 测试3: 结果验证 ---");
        
        // 测试简单加法
        $display("测试: 50 + 75 = ?");
        a = 50; b = 75; valid_in = 1; @(posedge clk);
//        valid_in = 0;
        repeat(4) @(posedge clk);
        if (valid_out) begin
            if (result == 125) 
                $display("PASS: 50 + 75 = %d", result);
            else
                $display("FAIL: 50 + 75 = %d (应该是125)", result);
        end
        
        // 测试模运算
        $display("测试: 2000 + 2000 = ? (需要模运算)");
        a = 2000; b = 2000; valid_in = 1; @(posedge clk);
//        valid_in = 0;
        repeat(4) @(posedge clk);
        if (valid_out) begin
            // 2000 + 2000 = 4000, 4000 - 3329 = 671
            if (result == 671)
                $display("PASS: 2000 + 2000 = %d (模运算正确)", result);
            else
                $display("FAIL: 2000 + 2000 = %d (应该是671)", result);
        end
        
        $display("\n========================================");
        $display("简化测试完成");
        $display("关键观察点:");
        $display("1. 输入后3个时钟周期才有输出");
        $display("2. 连续输入时，输出也连续");
        $display("3. valid_out正确指示输出有效性");
        $display("========================================");
        
        #(CLK_PERIOD * 5);
        $finish;
    end
    
    // 波形文件
    initial begin
        $dumpfile("mod_adder_pipeline.vcd");
        $dumpvars(0, tb_mod_adder_pipeline);
    end
    
    // 超时保护
    initial begin
        #(CLK_PERIOD * 500);
        $display("测试超时！");
        $finish;
    end

endmodule