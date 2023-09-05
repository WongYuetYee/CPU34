`define ACTIVE 1'b0
`define INACTIVE 1'b1

module cpu34(clk, rst, nothing);
    //===clk / rst
    input clk, rst;
    // wire clk_div2;
    // CLOCK clock(clk, rst, clk_div2);
    output [31:0] nothing; // for imple & sim

    //===ctrl====
    wire goahead;
    wire finish;
    wire [31:0] opcode;
    wire [31:0] program_count;

    //===Flag====
    wire rw_flag;
    wire [31:0] new_flag;

    wire [31:0] flag;
    wire zero, carry, overflow, warn;
    assign zero = flag[0];
    assign carry = flag[1];
    assign overflow = flag[2];
    assign warn = flag[3];

    //===connection====
    //------alu
    wire [3:0] en;
    wire en_adder, en_mul, en_sft, en_comb;
    assign en_adder = en[0];
    assign en_mul = en[1];
    assign en_sft = en[2];
    assign en_comb = en[3];

    wire [1:0] inner_ctr;
    wire [31:0] res;

    wire [31:0] num1, num2;
    //------registers
    wire rw_reg;
    wire [4:0] raddr1, raddr2, waddr;
    wire [31:0] rdata1, rdata2, wdata;
    assign nothing = wdata;
    //------mem
    wire rw_mem;
    wire mem_ref;
    wire [31:0] mem_addr;

    //------pcir -- alu
    wire [31:0] alu_rd;
//----------------------------------------------------------------

    //Instantiation    
    ALU alu(.clk(clk), .rst(rst), 
            .opcode(opcode), .goahead(goahead), .alu_cs(alu_cs), 
            .rw_reg(rw_reg), .raddr1(raddr1), .raddr2(raddr2), 
            .waddr(waddr), .rdata1(rdata1), .rdata2(rdata2), .wdata(wdata), 
            .flag(flag), .rw_flag(rw_flag), .new_flag(new_flag), 
            .rw_mem(rw_mem), .mem_ref(mem_ref), .mem_addr(mem_addr), 
            .wmem(mem_in), .rmem(mem_out), .alu_rd(alu_rd));

    Registers registers(.rst(rst),
                        .raddr1(raddr1), .raddr2(raddr2), 
                        .waddr(waddr), .wdata(wdata), 
                        .rw(rw_reg), .out1(rdata1), .out2(rdata2));

    Flag flag_instance(.rst(rst), .rw(rw_flag), 
                       .new_flag(new_flag), .flag(flag));
    
    Memory memory(.clk(clk), .rw_mem(rw_mem), .mem_ref(mem_ref), 
                  .mem_addr(mem_addr), .din(mem_in), .dout(mem_out));

    ProgramCache programcache(.clk(clk), .addr(program_count[9:0]), .data_out(opcode));

    PCU pcu(.clk(clk), .rst(rst),
            .alu_cs(alu_cs), .pcir_cs(pcir_cs), 
            .finish(finish), .goahead(goahead));

    PCIR pcir(.clk(clk), .rst(rst), .flag(flag), 
              .finish(finish), .pcir_cs(pcir_cs), 
              .program_count(program_count), .opcode(opcode), 
              .rw_reg(rw_reg), .alu_rd(alu_rd), 
              .waddr(waddr), .wdata(wdata));
endmodule

// module CLOCK (clk, rst, clk_div2);
//     input clk, rst;
//     output clk_div2;

//     reg clk_div2_r;
//     always @(posedge clk or negedge rst) begin
//         if (rst == `ACTIVE)
//             clk_div2_r <= 1'b0;
//         else
//             clk_div2_r <= ~clk_div2_r;
//     end
//    assign clk_div2 = clk_div2_r;
// endmodule