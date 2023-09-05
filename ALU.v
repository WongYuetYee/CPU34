module ALU(clk, rst, opcode, goahead, alu_cs, rw_reg, raddr1, raddr2,
              waddr, rdata1, rdata2, wdata, flag, rw_flag, new_flag,
              rw_mem, mem_ref, mem_addr, wmem, rmem, alu_rd);
    //===ctrl====
    input clk, rst;
    input [31:0] opcode;
    input goahead;
    output alu_cs;
    output [31:0] alu_rd;
    
    //====memory====
    input mem_ref;
    output [31:0] mem_addr;
    output rw_mem;
    input [7:0] rmem;
    output [7:0] wmem;

    //====registers====
    output rw_reg;
    output [4:0] raddr1, raddr2, waddr;
    input [31:0] rdata1, rdata2;
    output [31:0] wdata;

    //===Flag====
    input [31:0] flag;
    output rw_flag;
    output [31:0] new_flag;

    wire zero, carry, overflow, warn;
    assign zero = flag[0];
    assign carry = flag[1];
    assign overflow = flag[2];
    assign warn = flag[3];

    wire new_zero, new_carry, new_overflow, new_warn;

    //===connection====
    wire [3:0] en;
    wire en_adder, en_mul, en_sft, en_comb;
    assign en_adder = en[0];
    assign en_mul = en[1];
    assign en_sft = en[2];
    assign en_comb = en[3];

    wire [1:0] inner_ctr;
    wire [31:0] res;

    wire [31:0] num1, num2;

//-------------------------------------------------------------

    ALU_Ctr alu_ctr(.clk(clk), .rst(rst), 
                    .opcode(opcode),
                    .goahead(goahead), .alu_cs(alu_cs),
                    .num1(num1), .num2(num2), .en(en), 
                    .inner_ctr(inner_ctr), .res(res), 
                    .rdata1(rdata1), .rdata2(rdata2), 
                    .wdata(wdata), .rw_reg(rw_reg), 
                    .raddr1(raddr1), .raddr2(raddr2), .waddr(waddr),
                    .rw_flag(rw_flag), .new_flag(new_flag),
                    .new_zero(new_zero), .new_carry(new_carry), 
                    .new_overflow(new_overflow), .new_warn(new_warn), 
                    .rw_mem(rw_mem), .mem_ref(mem_ref), .mem_addr(mem_addr),
                    .rmem(rmem), .wmem(wmem), .alu_rd(alu_rd));

    Adder32 adder32(.en(en_adder), .a(num1), .b(num2), 
                    .inner_ctr(inner_ctr), .cin(carry), .sum(res), 
                    .cout(new_carry), .overflow(new_overflow), .zero(new_zero), .warn(new_warn));  
    
    MulSigned mulsigned(.en(en_mul), .a(num1), .b(num2), 
                        .res(res), 
                        .zero(new_zero), .carry(new_carry), .overflow(new_overflow), .warn(new_warn));

    Shift shift(.en(en_sft), .clk(clk), .sbits(num1), 
                .din(num2), .rl(inner_ctr[0]), .la(inner_ctr[1]), 
                .dout(res), 
                .zero(new_zero), .carry(new_carry), .overflow(new_overflow), .warn(new_warn));

    CombCal combcal(.en(en_comb), .a(num1), .b(num2), 
                    .res(res), .ccctr(inner_ctr), 
                    .zero(new_zero), .carry(new_carry), .overflow(new_overflow), .warn(new_warn));

endmodule