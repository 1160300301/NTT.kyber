`timescale 1ns / 1ps

module tb_mod_adder_pipeline;

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
    
    // ���Կ���
    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;
    
    // ����������к������������
    reg [DATA_WIDTH-1:0] test_a_queue [0:9];
    reg [DATA_WIDTH-1:0] test_b_queue [0:9];
    reg [DATA_WIDTH-1:0] expected_queue [0:9];
    integer input_ptr = 0;
    integer output_ptr = 0;
    integer total_tests = 0;
    
    // ʵ��������ģ��
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
    
    // ʱ������
    always #(CLK_PERIOD/2) clk = ~clk;
    
    // �ο�ģ��
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
    
    // ���������������
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
                
                $display("����[%0d]: %d + %d (�������: %d)", 
                         input_ptr, test_a, test_b, expected_queue[input_ptr]);
                
                input_ptr = input_ptr + 1;
                total_tests = total_tests + 1;
            end
        end
    endtask
    
    // ���������
    always @(posedge clk) begin
        if (valid_out && (output_ptr < total_tests)) begin
            test_count = test_count + 1;
            
            if (result == expected_queue[output_ptr]) begin
                pass_count = pass_count + 1;
                $display("���[%0d]: %d + %d = %d ?", 
                         output_ptr, test_a_queue[output_ptr], test_b_queue[output_ptr], result);
            end else begin
                fail_count = fail_count + 1;
                $display("���[%0d]: %d + %d = %d (����: %d) ?", 
                         output_ptr, test_a_queue[output_ptr], test_b_queue[output_ptr], 
                         result, expected_queue[output_ptr]);
            end
            
            output_ptr = output_ptr + 1;
        end
    end
    
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
        $display("����ˮ�߲���");
        $display("========================================");
        
        // ��λ
        #(CLK_PERIOD * 3);
        rst_n = 1;
        enable = 1;
        #(CLK_PERIOD * 2);
        
        // ����1���۲���ˮ���ӳ�
        $display("\n--- ����1: ��ˮ���ӳٹ۲� ---");
        $display("ʱ�� %0t: ���� 100 + 200", $time);
        a = 100; 
        b = 200; 
        valid_in = 1;
        @(posedge clk);
//        valid_in = 0;  // ֻ����һ������
        
        // �۲�5��ʱ������
        repeat(5) begin
            @(posedge clk);
            $display("ʱ�� %0t: valid_out=%d, result=%d %s", 
                     $time, valid_out, result,
                     valid_out ? "(�����Ч!)" : "");
        end
        
        // ����2����������۲�
       $display("\n--- ���������������� ---");
    
        // ����1: 0 + 0
        $display("=== ���� 0 + 0 ===");
        a = 0; b = 0; valid_in = 1; 
        @(posedge clk);
        valid_in = 0;
        
        // �ȴ����������ȫ������
        repeat(6) begin
            @(posedge clk);
            if (valid_out) 
                $display("���1: %d (����: 0)", result);
            else
                $display("�ȴ����1...");
        end
        
        // ����2: 1 + 2  
        $display("=== ���� 1 + 2 ===");
        a = 1; b = 2; valid_in = 1;
        @(posedge clk);
        valid_in = 0;
        
        repeat(6) begin
            @(posedge clk);
            if (valid_out) 
                $display("���2: %d (����: 3)", result);
            else
                $display("�ȴ����2...");
        end
        
        // ����3: 3328 + 1
        $display("=== ���� 3328 + 1 ===");
        a = 3328; b = 1; valid_in = 1;
        @(posedge clk);
        valid_in = 0;
        
        repeat(6) begin
            @(posedge clk);
            if (valid_out) 
                $display("���3: %d (����: 0)", result);
            else
                $display("�ȴ����3...");
        end
        
        // ����3���ֶ���֤�������
        $display("\n--- ����3: �����֤ ---");
        
        // ���Լ򵥼ӷ�
        $display("����: 50 + 75 = ?");
        a = 50; b = 75; valid_in = 1; @(posedge clk);
//        valid_in = 0;
        repeat(4) @(posedge clk);
        if (valid_out) begin
            if (result == 125) 
                $display("PASS: 50 + 75 = %d", result);
            else
                $display("FAIL: 50 + 75 = %d (Ӧ����125)", result);
        end
        
        // ����ģ����
        $display("����: 2000 + 2000 = ? (��Ҫģ����)");
        a = 2000; b = 2000; valid_in = 1; @(posedge clk);
//        valid_in = 0;
        repeat(4) @(posedge clk);
        if (valid_out) begin
            // 2000 + 2000 = 4000, 4000 - 3329 = 671
            if (result == 671)
                $display("PASS: 2000 + 2000 = %d (ģ������ȷ)", result);
            else
                $display("FAIL: 2000 + 2000 = %d (Ӧ����671)", result);
        end
        
        $display("\n========================================");
        $display("�򻯲������");
        $display("�ؼ��۲��:");
        $display("1. �����3��ʱ�����ڲ������");
        $display("2. ��������ʱ�����Ҳ����");
        $display("3. valid_out��ȷָʾ�����Ч��");
        $display("========================================");
        
        #(CLK_PERIOD * 5);
        $finish;
    end
    
    // �����ļ�
    initial begin
        $dumpfile("mod_adder_pipeline.vcd");
        $dumpvars(0, tb_mod_adder_pipeline);
    end
    
    // ��ʱ����
    initial begin
        #(CLK_PERIOD * 500);
        $display("���Գ�ʱ��");
        $finish;
    end

endmodule