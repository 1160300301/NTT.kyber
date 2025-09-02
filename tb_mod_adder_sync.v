`timescale 1ns / 1ps

module tb_mod_adder_sync;

    // ���Բ���
    parameter DATA_WIDTH = 12;
    parameter MODULUS = 3329;
    parameter CLK_PERIOD = 10;  // 10ns = 100MHz
    
    // �����ź�
    reg clk;
    reg rst_n;
    reg enable;
    reg [DATA_WIDTH-1:0] a;
    reg [DATA_WIDTH-1:0] b;
    wire [DATA_WIDTH-1:0] result;
    wire valid;
    
    // ���Կ���
    reg [DATA_WIDTH-1:0] expected;
    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;
    
    // ʵ��������ģ��
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
    
    // ʱ������
    always #(CLK_PERIOD/2) clk = ~clk;
    
    // �ο�ģ��
    function [DATA_WIDTH-1:0] ref_mod_add;
        input [DATA_WIDTH-1:0] x, y;
        reg [DATA_WIDTH:0] temp;
        begin
            temp = x + y;
            ref_mod_add = (temp >= MODULUS) ? temp - MODULUS : temp;
        end
    endfunction
    
    // ͬ����������
   task test_sync_case;
    input [DATA_WIDTH-1:0] test_a, test_b;
    begin
        // ��������
        a = test_a;
        b = test_b;
        expected = ref_mod_add(test_a, test_b);
        enable = 1;
        
        // �ȴ�һ��ʱ������ - ���뱻����
        @(posedge clk);
        
        // �ٵ�һ��ʱ������ - ���������
        @(posedge clk);  // �����һ�У�
        
        // ���ڼ����
        if (!valid) begin
            $display("ERROR: valid�ź�δ����");
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
    
    // ���Ը�λ����
    task test_reset;
        begin
            $display("\n--- ��λ���ܲ��� ---");
            
            // ������һЩֵ
            a = 100;
            b = 200;
            enable = 1;
            @(posedge clk);
            
            $display("��λǰ: result=%d, valid=%d", result, valid);
            
            // ִ�и�λ
            rst_n = 0;
            @(posedge clk);
            @(posedge clk);
            
            if (result == 0 && valid == 0) begin
                $display("? ��λ��������");
            end else begin
                $display("? ��λ�����쳣: result=%d, valid=%d", result, valid);
                fail_count = fail_count + 1;
            end
            
            // �ͷŸ�λ
            rst_n = 1;
            @(posedge clk);
        end
    endtask
    
    // ����ʹ�ܿ���
    task test_enable_control;
        begin
            $display("\n--- ʹ�ܿ��Ʋ��� ---");
            
            a = 50;
            b = 75;
            
            // ����ʹ��=0�����
            enable = 0;
            @(posedge clk);
            
            if (valid == 0) begin
                $display("? ʹ��=0ʱvalid��ȷΪ0");
            end else begin
                $display("? ʹ��=0ʱvalidӦ��Ϊ0");
                fail_count = fail_count + 1;
            end
            
            // ����ʹ��=1�����
            enable = 1;
            @(posedge clk);
            
            if (valid == 1) begin
                $display("? ʹ��=1ʱvalid��ȷΪ1");
            end else begin
                $display("? ʹ��=1ʱvalidӦ��Ϊ1");
                fail_count = fail_count + 1;
            end
        end
    endtask
    
    // ����������
    initial begin
        // ��ʼ��
        clk = 0;
        rst_n = 0;
        enable = 0;
        a = 0;
        b = 0;
        
        $display("========================================");
        $display("ͬ��ģ�ӷ������Կ�ʼ");
        $display("ʱ��Ƶ��: %d MHz", 1000/CLK_PERIOD);
        $display("========================================");
        
        // �ȴ�����ʱ�����ں��ͷŸ�λ
        #(CLK_PERIOD * 3);
        rst_n = 1;
        #(CLK_PERIOD * 2);
        
        // ���Ը�λ����
        test_reset();
        
        // ����ʹ�ܿ���
        test_enable_control();
        
        // ���Ի�������
        $display("\n--- ͬ�����ܲ��� ---");
        test_sync_case(0, 0);
        test_sync_case(0, 1);
        test_sync_case(MODULUS-1, 1);
        test_sync_case(MODULUS/2, MODULUS/2);
        test_sync_case(1000, 2000);
        test_sync_case(2000, 1500);
        
        // ������������
        $display("\n--- ������������ ---");
        begin : random_test_block
            reg [DATA_WIDTH-1:0] rand_a, rand_b;  // ��������������
            integer i;
            for (i = 0; i < 5; i = i + 1) begin
                rand_a = $random % MODULUS;
                rand_b = $random % MODULUS;
                if (rand_a < 0) rand_a = -rand_a;  // ȷ��Ϊ����
                if (rand_b < 0) rand_b = -rand_b;
                test_sync_case(rand_a, rand_b);
            end
        end
        
        // ���Ա�����������ÿ�����ڶ����������ݣ�
        $display("\n--- �������������� ---");
        enable = 1;  // ����ʹ��
        
        // ��������
        a = 100; b = 200; @(posedge clk);
        a = 300; b = 400; @(posedge clk);  
        a = 1500; b = 1600; @(posedge clk);
        a = 3000; b = 300; @(posedge clk);
        
        enable = 0;
        @(posedge clk);
        
        $display(" �����������������");
        
        // ���ͳ��
        $display("\n========================================");
        $display("ͬ���������");
        $display("�ܲ�����: %d", test_count);
        $display("ͨ��: %d", pass_count);
        $display("ʧ��: %d", fail_count);
        
        if (fail_count == 0) begin
            $display("? ͬ����Ʋ���ȫ��ͨ����");
            $display("? ��һ����ʵ����ˮ�߰汾");
        end else begin
            $display("?  �� %d ������ʧ�ܣ���Ҫ���", fail_count);
        end
        $display("========================================");
        
        #(CLK_PERIOD * 5);
        $finish;
    end
    
    // �����ļ�
    initial begin
        $dumpfile("mod_adder_sync.vcd");
        $dumpvars(0, tb_mod_adder_sync);
    end
    
    // ��ʱ����
    initial begin
        #(CLK_PERIOD * 1000);
        $display("���Գ�ʱ��");
        $finish;
    end

endmodule