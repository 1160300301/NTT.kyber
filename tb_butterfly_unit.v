`timescale 1ns / 1ps

module tb_butterfly_unit;

    // 参数
    parameter DATA_WIDTH = 12;
    parameter MODULUS = 3329;
    parameter CLK_PERIOD = 10;
    
    // 测试信号
    reg clk;
    reg rst_n;
    reg enable;
    reg valid_in;
    reg [DATA_WIDTH-1:0] a_in;
    reg [DATA_WIDTH-1:0] b_in;
    reg [DATA_WIDTH-1:0] twiddle;
    wire [DATA_WIDTH-1:0] a_out;
    wire [DATA_WIDTH-1:0] b_out;
    wire valid_out;
    
    // 实例化被测模块
    butterfly_unit #(
        .DATA_WIDTH(DATA_WIDTH),
        .MODULUS(MODULUS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .valid_in(valid_in),
        .a_in(a_in),
        .b_in(b_in),
        .twiddle(twiddle),
        .a_out(a_out),
        .b_out(b_out),
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
            if (temp >= MODULUS) ref_mod_add = temp - MODULUS;
            else ref_mod_add = temp;
        end
    endfunction
    
    function [DATA_WIDTH-1:0] ref_mod_sub;
        input [DATA_WIDTH-1:0] x, y;
        reg signed [DATA_WIDTH:0] temp;
        begin
            temp = $signed({1'b0, x}) - $signed({1'b0, y});
            if (temp < 0) ref_mod_sub = temp + MODULUS;
            else ref_mod_sub = temp;
        end
    endfunction
    
    function [DATA_WIDTH-1:0] ref_mod_mul;
        input [DATA_WIDTH-1:0] x, y;
        reg [23:0] temp;
        begin
            temp = x * y;
            ref_mod_mul = temp % MODULUS;
        end
    endfunction
    
    // 蝶形运算参考模型
    task ref_butterfly;
        input [DATA_WIDTH-1:0] a, b, w;
        output [DATA_WIDTH-1:0] a_ref, b_ref;
        reg [DATA_WIDTH-1:0] bw;
        begin
            bw = ref_mod_mul(b, w);
            a_ref = ref_mod_add(a, bw);
            b_ref = ref_mod_sub(a, bw);
        end
    endtask
    
    // 测试任务
    task test_butterfly;
        input [DATA_WIDTH-1:0] test_a, test_b, test_w;
        reg [DATA_WIDTH-1:0] expected_a, expected_b;
        integer wait_cycles;
        begin
            // 计算期望结果
            ref_butterfly(test_a, test_b, test_w, expected_a, expected_b);
            
            // 设置输入
            a_in = test_a;
            b_in = test_b;
            twiddle = test_w;
            valid_in = 1;
            @(posedge clk);
            valid_in = 0;
            
            // 等待结果（蝶形运算需要约8-10个周期）
            wait_cycles = 0;
            while (wait_cycles < 15) begin
                @(posedge clk);
                wait_cycles = wait_cycles + 1;
                if (valid_out) begin
                    if ((a_out == expected_a) && (b_out == expected_b))
                        $display("PASS: (%d,%d)*%d = (%d,%d)", test_a, test_b, test_w, a_out, b_out);
                    else
                        $display("FAIL: (%d,%d)*%d = (%d,%d), 期望 (%d,%d)", 
                                test_a, test_b, test_w, a_out, b_out, expected_a, expected_b);
                    wait_cycles = 99; // 跳出循环
                end
            end
            
            if (wait_cycles != 99) begin
                $display("TIMEOUT: 没有收到输出");
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
        a_in = 0;
        b_in = 0;
        twiddle = 0;
        
        $display("========================================");
        $display("蝶形运算单元测试");
        $display("标准NTT蝶形运算: (a,b,ω) -> (a+b*ω, a-b*ω)");
        $display("========================================");
        
        // 复位
        #(CLK_PERIOD * 3);
        rst_n = 1;
        enable = 1;
        #(CLK_PERIOD * 2);
        
        // 测试1: 基础蝶形运算
        $display("\n--- 基础蝶形运算测试 ---");
        test_butterfly(100, 200, 1);    // twiddle=1的简单情况
        test_butterfly(500, 300, 1);    // 另一个twiddle=1的情况
        test_butterfly(0, 100, 5);      // 包含0的情况
        
        // 测试2: 复杂旋转因子
        $display("\n--- 复杂旋转因子测试 ---");
        test_butterfly(1000, 500, 17);   // NTT中常见的旋转因子
        test_butterfly(200, 300, 49);    // 另一个旋转因子
        test_butterfly(1500, 1000, 7);   // 更复杂的情况
        
        // 测试3: 边界条件
        $display("\n--- 边界条件测试 ---");
        test_butterfly(3328, 3328, 3328); // 最大值测试
        test_butterfly(1664, 1664, 2);    // 中等值测试
        test_butterfly(1, 3328, 1);       // 混合测试
        
        $display("\n========================================");
        $display("蝶形运算单元测试完成");
        $display("关键特性:");
        $display("- 组合3个模运算单元");
        $display("- 自动处理流水线延迟匹配");
        $display("- 标准NTT蝶形运算");
        $display("- 总延迟约8-10个时钟周期");
        $display("========================================");
        
        #(CLK_PERIOD * 10);
        $finish;
    end
    
    // 波形文件
    initial begin
        $dumpfile("butterfly_unit.vcd");
        $dumpvars(0, tb_butterfly_unit);
    end

endmodule
