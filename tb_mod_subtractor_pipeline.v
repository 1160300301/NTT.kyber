`timescale 1ns / 1ps

module tb_mod_subtractor_pipeline;

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
    
    // ʱ������
    always #(CLK_PERIOD/2) clk = ~clk;
    
    // �ο�ģ��
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
    
    // ��������
    task test_mod_sub;
        input [DATA_WIDTH-1:0] test_a, test_b;
        input [DATA_WIDTH-1:0] expected;
        begin
            a = test_a;
            b = test_b;
            valid_in = 1;
            @(posedge clk);
            valid_in = 0;
            
            // �ȴ����
            repeat(6) begin
                @(posedge clk);
                if (valid_out) begin
                    if (result == expected)
                        $display("PASS: %d - %d = %d", test_a, test_b, result);
                    else
                        $display("FAIL: %d - %d = %d (����: %d)", test_a, test_b, result, expected);
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
        $display("3����ˮ��ģ����������");
        $display("========================================");
        
        // ��λ
        #(CLK_PERIOD * 3);
        rst_n = 1;
        enable = 1;
        #(CLK_PERIOD * 2);
        
        // ����1: ������������
        $display("\n--- ������������ ---");
        
        // ��������������ģ���㣩
        test_mod_sub(200, 100, ref_mod_sub(200, 100));   // 200 - 100 = 100
        test_mod_sub(1000, 500, ref_mod_sub(1000, 500)); // 1000 - 500 = 500
        test_mod_sub(100, 100, ref_mod_sub(100, 100));   // 100 - 100 = 0
        
        // ��Ҫģ����ļ��������Ϊ����
        $display("\n--- ����������ԣ���Ҫģ���㣩 ---");
        test_mod_sub(100, 200, ref_mod_sub(100, 200));   // 100 - 200 = -100 -> 3229
        test_mod_sub(0, 1, ref_mod_sub(0, 1));           // 0 - 1 = -1 -> 3328
        test_mod_sub(500, 1000, ref_mod_sub(500, 1000)); // 500 - 1000 = -500 -> 2829
        
        // �߽���������
        $display("\n--- �߽��������� ---");
        test_mod_sub(3328, 0, ref_mod_sub(3328, 0));     // ���ֵ - 0
        test_mod_sub(0, 3328, ref_mod_sub(0, 3328));     // 0 - ���ֵ
        test_mod_sub(3328, 3328, ref_mod_sub(3328, 3328)); // ���ֵ - ���ֵ = 0
        
        // �ֶ���֤�����ؼ����
        $display("\n--- �ֶ���֤ ---");
        $display("�ο�����:");
        $display("100 - 200 = -100, -100 + 3329 = 3229");
        $display("0 - 1 = -1, -1 + 3329 = 3328"); 
        $display("0 - 3328 = -3328, -3328 + 3329 = 1");
        
        $display("\n========================================");
        $display("ģ�������������");
        $display("�ؼ�����:");
        $display("- 3����ˮ���ӳ�");
        $display("- �Զ����������");
        $display("- ��ģ�ӷ������ݵĽӿ�");
        $display("========================================");
        
        #(CLK_PERIOD * 5);
        $finish;
    end
    
    // �����ļ�
    initial begin
        $dumpfile("mod_subtractor_pipeline.vcd");
        $dumpvars(0, tb_mod_subtractor_pipeline);
    end

endmodule