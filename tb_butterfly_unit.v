`timescale 1ns / 1ps

module tb_butterfly_unit;

    // ����
    parameter DATA_WIDTH = 12;
    parameter MODULUS = 3329;
    parameter CLK_PERIOD = 10;
    
    // �����ź�
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
    
    // ʵ��������ģ��
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
    
    // ʱ������
    always #(CLK_PERIOD/2) clk = ~clk;
    
    // �ο�ģ��
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
    
    // ��������ο�ģ��
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
    
    // ��������
    task test_butterfly;
        input [DATA_WIDTH-1:0] test_a, test_b, test_w;
        reg [DATA_WIDTH-1:0] expected_a, expected_b;
        begin
            // �����������
            ref_butterfly(test_a, test_b, test_w, expected_a, expected_b);
            
            // ��������
            a_in = test_a;
            b_in = test_b;
            twiddle = test_w;
            valid_in = 1;
            @(posedge clk);
            valid_in = 0;
            
            // �ȴ����������������ҪԼ8-10�����ڣ�
            repeat(15) begin
                @(posedge clk);
                if (valid_out) begin
                    if ((a_out == expected_a) && (b_out == expected_b))
                        $display("PASS: (%d,%d)*%d = (%d,%d)", test_a, test_b, test_w, a_out, b_out);
                    else
                        $display("FAIL: (%d,%d)*%d = (%d,%d), ���� (%d,%d)", 
                                test_a, test_b, test_w, a_out, b_out, expected_a, expected_b);
                    return;
                end
            end
            $display("TIMEOUT: û���յ����");
        end
    endtask
    
    // ����������
    initial begin
        // ��ʼ��
        clk = 0;
        rst_n = 0;
        enable = 0;
        valid_in = 0;
        a_in = 0;
        b_in = 0;
        twiddle = 0;
        
        $display("========================================");
        $display("�������㵥Ԫ����");
        $display("��׼NTT��������: (a,b,��) -> (a+b*��, a-b*��)");
        $display("========================================");
        
        // ��λ
        #(CLK_PERIOD * 3);
        rst_n = 1;
        enable = 1;
        #(CLK_PERIOD * 2);
        
        // ����1: ������������
        $display("\n--- ��������������� ---");
        test_butterfly(100, 200, 1);    // twiddle=1�ļ����
        test_butterfly(500, 300, 1);    // ��һ��twiddle=1�����
        test_butterfly(0, 100, 5);      // ����0�����
        
        // ����2: ������ת����
        $display("\n--- ������ת���Ӳ��� ---");
        test_butterfly(1000, 500, 17);   // NTT�г�������ת����
        test_butterfly(200, 300, 49);    // ��һ����ת����
        test_butterfly(1500, 1000, 7);   // �����ӵ����
        
        // ����3: �߽�����
        $display("\n--- �߽��������� ---");
        test_butterfly(3328, 3328, 3328); // ���ֵ����
        test_butterfly(1664, 1664, 2);    // �е�ֵ����
        test_butterfly(1, 3328, 1);       // ��ϲ���
        
        $display("\n========================================");
        $display("�������㵥Ԫ�������");
        $display("�ؼ�����:");
        $display("- ���3��ģ���㵥Ԫ");
        $display("- �Զ�������ˮ���ӳ�ƥ��");
        $display("- ��׼NTT��������");
        $display("- ���ӳ�Լ8-10��ʱ������");
        $display("========================================");
        
        #(CLK_PERIOD * 10);
        $finish;
    end
    
    // �����ļ�
    initial begin
        $dumpfile("butterfly_unit.vcd");
        $dumpvars(0, tb_butterfly_unit);
    end

endmodule