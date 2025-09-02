module mod_subtractor_pipeline #(
    parameter DATA_WIDTH = 12,
    parameter MODULUS = 3329
)(
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire valid_in,
    input wire [DATA_WIDTH-1:0] a,
    input wire [DATA_WIDTH-1:0] b,
    output reg [DATA_WIDTH-1:0] result,
    output reg valid_out
);

    // ��ˮ�߼Ĵ��� - Stage 1
    reg signed [DATA_WIDTH:0] diff_s1;          // 13λ�з��ţ��洢a-b
    reg [DATA_WIDTH:0] pre_add_s1;              // 13λ���洢a-b+q
    reg valid_s1;
    
    // ��ˮ�߼Ĵ��� - Stage 2  
    reg negative_s2;                            // �ж��Ƿ�Ϊ����
    reg signed [DATA_WIDTH:0] diff_s2;          // ����diff
    reg [DATA_WIDTH:0] pre_add_s2;              // ����pre_add
    reg valid_s2;
    
    // Stage 1: ���м���׶�
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            diff_s1 <= 0;
            pre_add_s1 <= 0;
            valid_s1 <= 0;
        end else begin
            // ���м����������ܵĽ��
            diff_s1 <= $signed({1'b0, a}) - $signed({1'b0, b});     // ��ͨ����
            pre_add_s1 <= $signed({1'b0, a}) - $signed({1'b0, b}) + MODULUS;  // Ԥ��ģ��
            valid_s1 <= enable & valid_in;
        end
    end
    
    // Stage 2: �����жϽ׶�
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            negative_s2 <= 0;
            diff_s2 <= 0;
            pre_add_s2 <= 0;
            valid_s2 <= 0;
        end else begin
            // �жϲ�ֵ�Ƿ�Ϊ��
            negative_s2 <= (diff_s1 < 0);
            // ���ݼ���������һ��
            diff_s2 <= diff_s1;
            pre_add_s2 <= pre_add_s1;
            valid_s2 <= valid_s1;
        end
    end
    
    // Stage 3: ����ѡ��׶�
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            valid_out <= 0;
        end else begin
            // ���ݷ���ѡ���������
            if (negative_s2)
                result <= pre_add_s2[DATA_WIDTH-1:0];  // ����ʱʹ��a-b+q
            else
                result <= diff_s2[DATA_WIDTH-1:0];     // �Ǹ�ʱʹ��a-b
            valid_out <= valid_s2;
        end
    end

endmodule