module mod_multiplier_pipeline #(
    parameter DATA_WIDTH = 12,
    parameter MODULUS = 3329
)(
    input clk,
    input rst_n,
    input enable,
    input valid_in,
    input [DATA_WIDTH-1:0] a,
    input [DATA_WIDTH-1:0] b,
    output reg [DATA_WIDTH-1:0] result,
    output reg valid_out
);

    // 真正的Barrett算法参数
    localparam V = 20159;               // v = ((1<<26) + KYBER_Q/2)/KYBER_Q
    
    // Barrett算法5级流水线 - 严格按照算法实现
    reg [23:0] stage1_prod;             // prod = a * b
    reg stage1_valid;
    
    reg [23:0] stage2_prod;             
    reg [37:0] stage2_vt;               // vt = v * prod
    reg stage2_valid;
    
    reg [23:0] stage3_prod;             
    reg [31:0] stage3_t;                // t = (vt + 2^25) >> 26
    reg stage3_valid;
    
    reg [23:0] stage4_prod;             
    reg [31:0] stage4_qt;               // qt = t * MODULUS
    reg stage4_valid;
    
    // Barrett差值计算
    reg signed [31:0] barrett_diff;
    
    // 第一级：计算乘积
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage1_prod <= 0;
            stage1_valid <= 0;
        end else if (enable) begin
            stage1_prod <= valid_in ? (a * b) : 0;
            stage1_valid <= valid_in;
        end else begin
            stage1_valid <= 0;
        end
    end
    
    // 第二级：计算 vt = v * prod
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage2_prod <= 0;
            stage2_vt <= 0;
            stage2_valid <= 0;
        end else if (enable) begin
            stage2_prod <= stage1_prod;
            stage2_vt <= V * stage1_prod;
            stage2_valid <= stage1_valid;
        end else begin
            stage2_valid <= 0;
        end
    end
    
    // 第三级：计算 t = (vt + 2^25) >> 26
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage3_prod <= 0;
            stage3_t <= 0;
            stage3_valid <= 0;
        end else if (enable) begin
            stage3_prod <= stage2_prod;
            stage3_t <= (stage2_vt + (38'd1 << 25)) >> 26;
            stage3_valid <= stage2_valid;
        end else begin
            stage3_valid <= 0;
        end
    end
    
    // 第四级：计算 qt = t * MODULUS
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage4_prod <= 0;
            stage4_qt <= 0;
            stage4_valid <= 0;
        end else if (enable) begin
            stage4_prod <= stage3_prod;
            stage4_qt <= stage3_t * MODULUS;
            stage4_valid <= stage3_valid;
        end else begin
            stage4_valid <= 0;
        end
    end
    
    // 第五级：Barrett核心 - result = prod - qt，然后调整范围
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            valid_out <= 0;
            barrett_diff <= 0;
        end else if (enable && stage4_valid) begin
            // Barrett算法核心：prod - qt
            barrett_diff <= $signed({8'h0, stage4_prod}) - $signed(stage4_qt);
            
            // 范围调整：只用加减法，不用模运算
            if (($signed({8'h0, stage4_prod}) - $signed(stage4_qt)) < 0) begin
                result <= ($signed({8'h0, stage4_prod}) - $signed(stage4_qt)) + MODULUS;
            end else if (($signed({8'h0, stage4_prod}) - $signed(stage4_qt)) >= MODULUS) begin
                result <= ($signed({8'h0, stage4_prod}) - $signed(stage4_qt)) - MODULUS;
            end else begin
                result <= ($signed({8'h0, stage4_prod}) - $signed(stage4_qt));
            end
            
            valid_out <= 1;
        end else begin
            result <= 0;
            valid_out <= 0;
            barrett_diff <= 0;
        end
    end

endmodule
