module butterfly_unit #(
    parameter DATA_WIDTH = 12,
    parameter MODULUS = 3329
)(
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire valid_in,
    input wire [DATA_WIDTH-1:0] a_in,
    input wire [DATA_WIDTH-1:0] b_in,
    input wire [DATA_WIDTH-1:0] twiddle,
    output reg [DATA_WIDTH-1:0] a_out,
    output reg [DATA_WIDTH-1:0] b_out,
    output reg valid_out
);

    // �ڲ��ź�
    wire [DATA_WIDTH-1:0] mult_result;
    wire mult_valid;
    wire [DATA_WIDTH-1:0] add_result;
    wire add_valid;
    wire [DATA_WIDTH-1:0] sub_result;
    wire sub_valid;
    
    // ��ˮ��ͬ���ź�
    reg [DATA_WIDTH-1:0] a_delay[0:6];  // �ӳ�a��ƥ��˷����ӳ�
    reg valid_delay[0:6];
    
    // ʵ����ģ�˷��������� b * twiddle
    mod_multiplier_pipeline mult_inst (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .valid_in(valid_in),
        .a(b_in),
        .b(twiddle),
        .result(mult_result),
        .valid_out(mult_valid)
    );
    
    // ʵ����ģ�ӷ��������� a + (b * twiddle)
    mod_adder_pipeline add_inst (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .valid_in(mult_valid),
        .a(a_delay[4]),  // �ӳ�ƥ��˷�����5����ˮ��
        .b(mult_result),
        .result(add_result),
        .valid_out(add_valid)
    );
    
    // ʵ����ģ������������ a - (b * twiddle)
    mod_subtractor_pipeline sub_inst (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .valid_in(mult_valid),
        .a(a_delay[4]),  // �ӳ�ƥ��˷�����5����ˮ��
        .b(mult_result),
        .result(sub_result),
        .valid_out(sub_valid)
    );
    
    // �ӳ�������a_in�ӳ���ƥ��˷����ӳ�
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            integer i;
            for (i = 0; i < 7; i = i + 1) begin
                a_delay[i] <= 0;
                valid_delay[i] <= 0;
            end
        end else if (enable) begin
            a_delay[0] <= a_in;
            valid_delay[0] <= valid_in;
            
            integer j;
            for (j = 1; j < 7; j = j + 1) begin
                a_delay[j] <= a_delay[j-1];
                valid_delay[j] <= valid_delay[j-1];
            end
        end
    end
    
    // ����Ĵ�����ͬ��������
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_out <= 0;
            b_out <= 0;
            valid_out <= 0;
        end else if (enable && add_valid && sub_valid) begin
            a_out <= add_result;  // a' = a + b*��
            b_out <= sub_result;  // b' = a - b*��
            valid_out <= 1;
        end else begin
            valid_out <= 0;
        end
    end

endmodule