module mod_adder_sync #(
    parameter DATA_WIDTH = 12,
    parameter MODULUS = 3329
)(
    input wire clk,                        // ʱ���ź�
    input wire rst_n,                      // ��λ�źţ�����Ч��
    input wire enable,                     // ʹ���ź�
    input wire [DATA_WIDTH-1:0] a,
    input wire [DATA_WIDTH-1:0] b,
    output reg [DATA_WIDTH-1:0] result,
    output reg valid                       // �����Ч�ź�
);

    // �ڲ��ź�
    wire [DATA_WIDTH:0] sum;
    reg [DATA_WIDTH-1:0] temp_result;
    
    // ����߼�������ģ�ӷ�
    assign sum = a + b;
    
    always @(*) begin
        if (sum >= MODULUS)
            temp_result = sum - MODULUS;
        else
            temp_result = sum[DATA_WIDTH-1:0];
    end
    
    // ʱ���߼�����ʱ�ӱ��ظ������
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // �첽��λ
            result <= 0;
            valid <= 0;
        end else if (enable) begin
            // ʱ����������ʹ��ʱ���½��
            result <= temp_result;
            valid <= 1;
        end else begin
            valid <= 0;  // ��ʹ��ʱ���valid�ź�
        end
    end

endmodule