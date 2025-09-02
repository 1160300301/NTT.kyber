// ========================================================================
// ������DSP48�Ż���5����ˮ��ģ�˷���
// ʹ��������BarrettԼ���㷨
// �ļ�: mod_multiplier_pipeline.v
// ========================================================================

module mod_multiplier_pipeline #(
    parameter DATA_WIDTH = 12,
    parameter MODULUS = 3329,
    // ������BarrettԼ��Ԥ���㳣��
    parameter BARRETT_MU = 5040,        // floor(2^24/3329) = 5040
    parameter BARRETT_K = 12
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

    // ��ʱ�������
    reg [31:0] temp_result;

    // ��ˮ�߼Ĵ��� - Stage 1-2: DSP48�˷�
    reg [23:0] product_s1;
    reg valid_s1;
    
    reg [23:0] product_s2;
    reg valid_s2;
    
    // ��ˮ�߼Ĵ��� - Stage 3: BarrettԤԼ��
    reg [23:0] product_s3;
    reg [23:0] barrett_est_s3;
    reg valid_s3;
    
    // ��ˮ�߼Ĵ��� - Stage 4: Լ�����
    reg [31:0] reduction_s4;            // ����λ��������
    reg [23:0] product_s4;
    reg valid_s4;
    
    // Stage 1: �˷����㣨DSP48��һ����
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product_s1 <= 0;
            valid_s1 <= 0;
        end else begin
            product_s1 <= a * b;
            valid_s1 <= enable & valid_in;
        end
    end
    
    // Stage 2: �˷���ˮ�ߣ�DSP48�ڶ�����
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product_s2 <= 0;
            valid_s2 <= 0;
        end else begin
            product_s2 <= product_s1;
            valid_s2 <= valid_s1;
        end
    end
    
    // Stage 3: ������BarrettԤԼ��
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product_s3 <= 0;
            barrett_est_s3 <= 0;
            valid_s3 <= 0;
        end else begin
            product_s3 <= product_s2;
            // ������Barrett���㣬�������
            barrett_est_s3 <= ((product_s2 >> (BARRETT_K - 2)) * BARRETT_MU) >> (BARRETT_K + 2);
            valid_s3 <= valid_s2;
        end
    end
    
    // Stage 4: Լ�����
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reduction_s4 <= 0;
            product_s4 <= 0;
            valid_s4 <= 0;
        end else begin
            reduction_s4 <= barrett_est_s3 * MODULUS;
            product_s4 <= product_s3;
            valid_s4 <= valid_s3;
        end
    end
    
    // Stage 5: ����Լ���˫����������
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            valid_out <= 0;
        end else begin
            // BarrettԼ��
            temp_result = product_s4 - reduction_s4;
            
            // ˫������������BarrettԼ�������Ҫ2������
            if (temp_result >= (2 * MODULUS))
                result <= temp_result - (2 * MODULUS);
            else if (temp_result >= MODULUS)
                result <= temp_result - MODULUS;
            else
                result <= temp_result[DATA_WIDTH-1:0];
                
            valid_out <= valid_s4;
        end
    end

endmodule