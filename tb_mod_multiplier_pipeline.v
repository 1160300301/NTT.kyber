`timescale 1ns / 1ps

module tb_mod_multiplier_pipeline;

    // ����
    parameter DATA_WIDTH = 12;
    parameter MODULUS = 3329;
    parameter CLK_PERIOD = 10;
    
    // �����ź�
    reg clk;
    reg rst_n;
    reg enable;
    reg valid_in;
    reg [DATA_WIDTH-1:0] a;
    reg [DATA_WIDTH-1:0] b;
    wire [DATA_WIDTH-1:0] result;
    wire valid_out;
    
    // ʵ��������ģ��
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
    
    // ʱ������
    always #(CLK_PERIOD/2) clk = ~clk;
    
    // �ο�ģ��
    function [DATA_WIDTH-1:0] ref_mod_mul;
        input [DATA_WIDTH-1:0] x, y;
        reg [23:0] temp;
        begin
            temp = x * y;
            ref_mod_mul = temp % MODULUS;
        end
    endfunction
    
    // ��������
    task test_mod_mul;
        input [DATA_WIDTH-1:0] test_a, test_b;
        input [DATA_WIDTH-1:0] expected;
        begin
            a = test_a;
            b = test_b;
            valid_in = 1;
            @(posedge clk);
            valid_in = 0;
            
            // �ȴ�5����ˮ�߽��
            repeat(8) begin
                @(posedge clk);
                if (valid_out) begin
                    if (result == expected)
                        $display("PASS: %d * %d = %d", test_a, test_b, result);
                    else
                        $display("FAIL: %d * %d = %d (����: %d)", test_a, test_b, result, expected);
                end
            end
        end
    endtask
    
    // ����������
    initial begin
        // ��ʼ��
        clk = 0;
        rst_n = 0;
        enable = 0;
        valid_in = 0;
        a = 0;
        b = 0;
        
        $display("========================================");
        $display("DSP48�Ż�ģ�˷�������");
        $display("BarrettԼ���㷨 (q=%d)", MODULUS);
        $display("========================================");
        
        // ��λ
        #(CLK_PERIOD * 3);
        rst_n = 1;
        enable = 1;
        #(CLK_PERIOD * 2);
        
        // ����1: �����˷�����
        $display("\n--- �����˷����� ---");
        test_mod_mul(0, 100, ref_mod_mul(0, 100));       // 0 * 100 = 0
        test_mod_mul(1, 200, ref_mod_mul(1, 200));       // 1 * 200 = 200
        test_mod_mul(10, 20, ref_mod_mul(10, 20));       // 10 * 20 = 200
        test_mod_mul(100, 30, ref_mod_mul(100, 30));     // 100 * 30 = 3000
        
        // ����2: ��Ҫģ����ĳ˷�
        $display("\n--- �����˷����ԣ���Ҫģ���㣩 ---");
        test_mod_mul(100, 100, ref_mod_mul(100, 100));   // 10000
        test_mod_mul(200, 200, ref_mod_mul(200, 200));   // 40000 mod 3329
        test_mod_mul(1000, 5, ref_mod_mul(1000, 5));     // 5000 mod 3329
        test_mod_mul(3328, 2, ref_mod_mul(3328, 2));     // 6656 mod 3329 = 6656-3329 = 3327
        
        // ����3: �߽�����
        $display("\n--- �߽��������� ---");
        test_mod_mul(3328, 1, ref_mod_mul(3328, 1));     // ���ֵ * 1
        test_mod_mul(3328, 3328, ref_mod_mul(3328, 3328)); // ���ֵ * ���ֵ
        test_mod_mul(1664, 2, ref_mod_mul(1664, 2));     // �ӽ�q/2 �Ĳ���
        
        // ����4: ����ֵ����
        $display("\n--- ����ֵ���� ---");
        test_mod_mul(3329, 1, ref_mod_mul(3329 % MODULUS, 1)); // q * 1 = 0
        
        // �ֶ���֤
        $display("\n--- �ֶ���֤�ؼ���� ---");
        $display("�ο�����:");
        $display("3328 * 2 = 6656, 6656 mod 3329 = 3327");
        $display("200 * 200 = 40000, 40000 mod 3329 = 40000 - 12*3329 = 40000 - 39948 = 52");
        $display("1664 * 2 = 3328 (�պ�С��q)");
        
        $display("\n========================================");
        $display("ģ�˷����������");
        $display("�ؼ�����:");
        $display("- 5�������ˮ��");
        $display("- BarrettԼ���㷨");
        $display("- DSP48�Ż�");
        $display("- ֧��ȫ��Χ���� (0 �� q-1)");
        $display("========================================");
        
        #(CLK_PERIOD * 10);
        $finish;
    end
    
    // �����ļ�
    initial begin
        $dumpfile("mod_multiplier_pipeline.vcd");
        $dumpvars(0, tb_mod_multiplier_pipeline);
    end

endmodule