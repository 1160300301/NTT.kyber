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
    // 声明循环变量在模块级别
    integer i, j;
    
    // 内部信号
    wire [DATA_WIDTH-1:0] mult_result;
    wire mult_valid;
    wire [DATA_WIDTH-1:0] add_result;
    wire add_valid;
    wire [DATA_WIDTH-1:0] sub_result;
    wire sub_valid;
    
    // 流水线同步信号
    reg [DATA_WIDTH-1:0] a_delay[0:6];  // 延迟a以匹配乘法器延迟
    reg valid_delay[0:6];
    
    // 实例化模乘法器：计算 b * twiddle
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
    
    // 实例化模加法器：计算 a + (b * twiddle)
    mod_adder_pipeline add_inst (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .valid_in(mult_valid),
        .a(a_delay[4]),  // 延迟匹配乘法器的5级流水线
        .b(mult_result),
        .result(add_result),
        .valid_out(add_valid)
    );
    
    // 实例化模减法器：计算 a - (b * twiddle)
    mod_subtractor_pipeline sub_inst (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .valid_in(mult_valid),
        .a(a_delay[4]),  // 延迟匹配乘法器的5级流水线
        .b(mult_result),
        .result(sub_result),
        .valid_out(sub_valid)
    );
    
    // 延迟链：将a_in延迟以匹配乘法器延迟
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 7; i = i + 1) begin
                a_delay[i] <= 0;
                valid_delay[i] <= 0;
            end
        end else if (enable) begin
            a_delay[0] <= a_in;
            valid_delay[0] <= valid_in;
            
            for (j = 1; j < 7; j = j + 1) begin
                a_delay[j] <= a_delay[j-1];
                valid_delay[j] <= valid_delay[j-1];
            end
        end
    end
    
    // 输出寄存器：同步输出结果
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_out <= 0;
            b_out <= 0;
            valid_out <= 0;
        end else if (enable && add_valid && sub_valid) begin
            a_out <= add_result;  // a' = a + b*ω
            b_out <= sub_result;  // b' = a - b*ω
            valid_out <= 1;
        end else begin
            valid_out <= 0;
        end
    end
endmodule
