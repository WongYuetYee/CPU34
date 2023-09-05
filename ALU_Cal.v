// 0: zero flag             ---HE
// 1: carry flag            ---HE
// 2: Integer overflow flag ---HE
// 3: warning flag          ---HE
// 4: error flag            ---HE
//////////////////////////////////////////////////////////////////////////////////
`define ENABLED 1'b0

`define SIGNEDADD 1'b1
`define UNSIGNEDADD 1'b0

// module Adder32 (en, a, b, inner_ctr, cin, sum, cout, overflow, zero, warn);
//     input en;
//     input [31:0] a, b;
//     input inner_ctr;
//     input cin;

//     output [31:0] sum;
//     output cout;
//     output overflow;
//     output zero;
//     output warn;

//     assign sum = (en == `ENABLED) ? (a+b) : (32'h0zzzz_zzzz);
//     assign cout = (en == `ENABLED) ? cin : (1'bz);
//     assign overflow = (en == `ENABLED) ? ((a[31] == b[31]) && (a[31] != sum[31])) : (1'bz);
//     assign zero = (en == `ENABLED) ? (~(|sum)) : (1'bz); 
//     assign warn = (en == `ENABLED) ? ~(zero==1 || zero==0) : (1'bz); //如果sum含有x/z，则zero不会为1/0，此时发出warn信号
// endmodule
module Adder32 (en, a, b, inner_ctr, cin, sum, cout, overflow, zero, warn);
    input en;
    input [31:0] a, b;
    input [1:0]inner_ctr;
    input cin;

    output [31:0] sum;
    output cout;
    output overflow;
    output zero;
    output warn;

    wire [31:0] s;
    wire c;
    wire [7:0] carry;
    assign carry[0] = (inner_ctr[0] == `ENABLED) ? cin : (1'b0);

    wire [31:0] a_comp, b_comp, s_comp;

    assign a_comp = ((inner_ctr[1]==`SIGNEDADD) && (a[31]==1'b1)) ? {a[31], (~a[30:0]+31'd1)} : a;
    assign b_comp = ((inner_ctr[1]==`SIGNEDADD) && (b[31]==1'b1)) ? {b[31], (~b[30:0]+31'd1)} : b;
    assign s_comp = ((inner_ctr[1]==`SIGNEDADD) && (s[31]==1'b1)) ? {s[31], (~s[30:0]+31'd1)} : s;

    PA4 u0(a_comp[3:0], b_comp[3:0], carry[0], s[3:0], carry[1]);
    PA4 u1(a_comp[7:4], b_comp[7:4], carry[1], s[7:4], carry[2]);
    PA4 u2(a_comp[11:8], b_comp[11:8], carry[2], s[11:8], carry[3]);
    PA4 u3(a_comp[15:12], b_comp[15:12], carry[3], s[15:12], carry[4]);
    PA4 u4(a_comp[19:16], b_comp[19:16], carry[4], s[19:16], carry[5]);
    PA4 u5(a_comp[23:20], b_comp[23:20], carry[5], s[23:20], carry[6]);
    PA4 u6(a_comp[27:24], b_comp[27:24], carry[6], s[27:24], carry[7]);
    PA4 u7(a_comp[31:28], b_comp[31:28], carry[7], s[31:28], c);


    assign sum = (en == `ENABLED) ? s_comp : (32'h0zzzz_zzzz);
    assign cout = (en == `ENABLED) ? c : (1'bz);
    assign overflow = (en == `ENABLED) ? ((a[31] == b[31]) && (a[31] != sum[31])) : (1'bz);
    assign zero = (en == `ENABLED) ? (~(|s)) : (1'bz); 
    assign warn = (en == `ENABLED) ? ~(zero==1 || zero==0) : (1'bz); //如果sum含有x/z，则zero不会为1/0，此时发出warn信号
endmodule

module PA4(a, b, cin, s, cout);
    input [3:0] a;
	input [3:0] b;
	input cin;

	output [3:0] s;
	output cout;

	wire [3:0] p;
	wire [3:0] g;
	wire [3:0] c;

	assign g[0] = a[0] & b[0];
	assign g[1] = a[1] & b[1];
	assign g[2] = a[2] & b[2];
	assign g[3] = a[3] & b[3];
	assign p[0] = a[0] ^ b[0];
	assign p[1] = a[1] ^ b[1];
	assign p[2] = a[2] ^ b[2];
	assign p[3] = a[3] ^ b[3];
	assign s[0] = p[0] ^ cin;
	assign c[0] = g[0] | (p[0] & cin);
	assign s[1] = p[1] ^ c[0];
	assign c[1] = g[1] | (p[1] & g[0]) | (p[1] & p[0] & cin);
	assign s[2] = p[2] ^ c[1];
	assign c[2] = g[2] | (p[2] & g[1]) | (p[2] & p[1] & g[0]) | (p[2] & p[1] & p[0] & cin);
	assign s[3] = p[3] ^ c[2];
	assign c[3] = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1]) | (p[3] & p[2] & p[1] & g[0]) | (p[3] & p[2] & p[1] & p[0] & cin);
	
    assign cout = c[3];
endmodule

module MulSigned(en, a, b, res, zero, carry, overflow, warn);
    input en;
    input signed [31:0] a, b;
    output [31:0] res;
    output zero, carry, overflow, warn;

    wire [31:0] res;
    wire zero;

    wire [31:0] a_comp, b_comp;
    assign a_comp = a[31] ? {a[31], (~a[30:0]+31'd1)} : a;
    assign b_comp = b[31] ? {b[31], (~b[30:0]+31'd1)} : b;

    //运算
    wire [63:0] fullres_comp, fullres;
    assign fullres = (en == `ENABLED) ? (a_comp * b_comp) : (32'h0zzzz_zzzz);
    assign fullres_comp = fullres[63] ? {fullres[63], ~fullres[62:0]+63'd1} : fullres;
    
    //获取乘法结果的低32位
    assign res = (en == `ENABLED) ? (fullres_comp[31:0]) : 32'h0zzzz_zzzz;
    //0?
    assign zero = (en == `ENABLED) ? (~(|res)) : (1'bz);
    //carry
    assign carry = (en == `ENABLED) ? (1'b0) : (1'bz);
    //overflow
    assign overflow = (en == `ENABLED) ? (1'b0) : (1'bz);
    //warn
    assign warn = (en == `ENABLED) ? ~(zero==1 || zero==0) : (1'bz); //如果sum含有x/z，则zero不会为1/0，此时发出warn信号

endmodule

module Shift(en, clk, sbits, din, rl, la, dout, zero, carry, overflow, warn);
    input en;
    input clk;
    input [31:0] sbits;
    input signed [31:0] din;
    //right-left, logic-arithmatic
    input rl, la;
    output [31:0] dout;
    output zero, carry, overflow, warn;

    reg [31:0] dout;
    wire zero;

    // 砍sbits
    // Send Warning 信号
    wire [4:0] sbits_cut;
    assign sbits_cut = sbits[4:0];                   

    parameter ARITH_L = 2'b00;
    parameter ARITH_R = 2'b01;
    parameter LOGIC_L = 2'b10;
    parameter LOGIC_R = 2'b11;

    always @(negedge clk)
    begin
        case({la, rl})
            ARITH_L:
            begin
                dout = (en == `ENABLED) ? ({din <<< sbits_cut}) : (32'h0zzzz_zzzz);
            end            
            ARITH_R:
            begin
                dout = (en == `ENABLED) ? ({din >>> sbits_cut}) : (32'h0zzzz_zzzz);
            end
            LOGIC_L:
            begin
                dout = (en == `ENABLED) ? (din << sbits_cut) : (32'h0zzzz_zzzz);
            end
            LOGIC_R:
            begin
                dout = (en == `ENABLED) ? (din >> sbits_cut) : (32'h0zzzz_zzzz);
            end
            // 未知态，输出高阻态
            default:
            begin
                dout = 32'h0zzzz_zzzz;
            end
        endcase
    end

    assign zero = (en == `ENABLED) ? (~(|dout)) : (1'bz);
    assign carry = (en == `ENABLED) ? (1'b0) : (1'bz);
    assign overflow = (en == `ENABLED) ? (1'b0) : (1'bz);
    assign warn = (en == `ENABLED) ? ((|(sbits[31:5])) || ~(zero==1 || zero==0)) : (1'bz);

endmodule

module CombCal(en, a, b, res, ccctr, zero, carry, overflow, warn);
    input en;
    input [31:0] a, b;
    input [1:0] ccctr;
    output reg [31:0] res;
    output zero, carry, overflow, warn;

    reg warn;

    parameter AND = 2'b00;
    parameter OR  = 2'b01;
    parameter XOR = 2'b10;

    always @(*)
    begin
        case(ccctr)
            AND: begin
                res <= (en == `ENABLED) ? (a & b) : (32'h0zzzz_zzzz);
                warn <= (en == `ENABLED) ? (1'b0) : (1'bz);
            end
            OR: begin
                res <= (en == `ENABLED) ? (a | b) : (32'h0zzzz_zzzz);
                warn <= (en == `ENABLED) ? (1'b0) : (1'bz);
            end
            XOR: begin
                res <= (en == `ENABLED) ? (a ^ b) : (32'h0zzzz_zzzz);
                warn <= (en == `ENABLED) ? (1'b0) : (1'bz);
            end
            // 未知态，输出高阻态
            default: begin
                res <= (32'h0zzzz_zzzz);
                warn <= (1'bz) ;
            end
        endcase
    end

    assign zero = (en == `ENABLED) ? (~(|res)) : (1'bz);
    assign carry = (en == `ENABLED) ? (1'b0) : (1'bz);
    assign overflow = (en == `ENABLED) ? (1'b0) : (1'bz);

endmodule