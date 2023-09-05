`define READ_VALID 1'b1
`define WRITE_VALID 1'b0

`define ACTIVE 1'b0
`define INACTIVE 1'b1

`define FULL 1'b1
`define EMPTY 1'b0

`define CARRY_ENABLED  1'b0
`define CARRY_DISABLED 1'b1

`define SIGNEDADD 1'b1
`define UNSIGNEDADD 1'b0

`define AND 2'b00
`define OR  2'b01
`define XOR 2'b10
`define ARITH_L 2'b00
`define ARITH_R 2'b01
`define LOGIC_L 2'b10
`define LOGIC_R 2'b11

`define ALL_DISABLED    5'b1111
`define ADDER_ENABLED   5'b1110
`define MUL_ENABLED     5'b1101
`define SFT_ENABLED     5'b1011
`define COMB_ENABLED    5'b0111

module ALU_Ctr(clk, rst, goahead, alu_cs, opcode,
               num1, num2, en, inner_ctr, res,
               rdata1, rdata2, wdata, rw_reg, 
               raddr1, raddr2, waddr, 
               rw_flag, new_flag,
               new_zero, new_carry, new_overflow, new_warn,
               rw_mem, mem_ref, mem_addr, rmem, wmem,
               alu_rd);

    input clk, rst;
    output reg [31:0] alu_rd;
    //===mem
    output reg rw_mem;
    input mem_ref;
    output reg [31:0] mem_addr;    
    input [7:0] rmem;
    output reg [7:0] wmem;
    reg [1:0] mem_count;
    //===flag
    input new_zero, new_carry, new_overflow, new_warn;
    output reg [31:0] new_flag;
    //===to instruction control unit
    input goahead;
    output reg alu_cs;
    //===to opcode
    input [31:0] opcode;
        //------Opcode Head 6bits...Tail 6bits
    wire [11:0] aluctr; 
    assign aluctr = {opcode[31:26], opcode[5:0]};
        //------rs/rt/rd address
    wire [4:0] rs_addr, rt_addr, rd_addr;
    assign rs_addr = opcode[25:21];
    assign rt_addr = opcode[20:16];
    assign rd_addr = opcode[15:11];
        //------imm extension
    wire [15:0] imm;
    wire [31:0] imm_zero = {16'd0, imm};
    wire [31:0] imm_signed = {imm[15], 16'd0, imm[14:0]};
    assign imm = opcode[15:0];
        //------sa extension
    wire [4:0] sa;
    wire [31:0] sa_zero = {27'd0, sa};
    assign sa = opcode[10:6];
    //===to alu
    output reg [31:0] num1, num2;
    output reg [4:0] en;
    output reg [1:0] inner_ctr;
    input [31:0] res;
        //------en
    wire en_add, en_mul, en_sft, en_comb;
    assign en_add = en[3];
    assign en_mul = en[2];
    assign en_sft = en[1];
    assign en_comb = en[0];
    //===to reg
    input [31:0] rdata1, rdata2;
    output reg [31:0] wdata;
    output reg rw_reg;
    output reg [4:0] raddr1, raddr2, waddr;

    parameter INIT = 3'b000; //0
    parameter RD   = 3'b001; //1
    parameter CAL  = 3'b011; //3
    parameter WRI  = 3'b010; //2
    parameter FIN  = 3'b100; //4
    parameter ERR  = 3'b111; //7
    parameter MEM  = 3'b101; //5
    //===to flag
    output reg rw_flag;

//----------------------------------------------------------------
    reg [11:0] ctrl;
    reg [2:0] state_cur;
    reg [2:0] state_next;

    //状态转移
    always @(negedge clk or negedge rst)
    begin
        if (rst==`ACTIVE) begin
            state_cur <= RD;
            ctrl <= aluctr;
            mem_count <= 2'b00;
            rw_reg <= 1'bz;
        end
        else
            state_cur <= state_next;
    end

    //状态转移条件 + 输出
    always @(*)
    begin
        case(state_cur)
            INIT:begin
                alu_cs = `INACTIVE;
                casex (aluctr)
                    //BEQ
                    //rs==rt then offset
                    12'b000100_xxxxxx:
                        state_next = RD;
                    //BNE
                    //rs!=rt then offset
                    12'b000101_xxxxxx:
                        state_next = RD;
                    //BGEZ
                    //rs>=0 -> offset
                    12'b000001_xxxxxx: 
                        state_next = RD;
                    //BGTZ
                    //rs>0 -> offset
                    12'b000111_xxxxxx: 
                        state_next = RD;
                    //BLEZ
                    //rs<=0 -> offset
                    12'b000110_xxxxxx:
                        state_next = RD;
                    //BLTZ
                    //rs<0 -> offset
                    12'b000001_xxxxxx:
                        state_next = RD;
                    //J
                    //->instr_index
                    12'b000010_xxxxxx:
                        state_next = FIN;
                    //JAL
                    //->instr_index, PC_origin+4 -> REG$31
                    12'b000011_xxxxxx:
                        state_next = FIN;
                    //JR
                    //->rs
                    12'b000000_001000:
                        state_next = RD;
                    //JALR
                    //->rs, pc+4 -> rd
                    12'b000000_001001: 
                        state_next = RD;
                    default:
                        state_next = RD;
                endcase
            end

            RD:begin
                rw_reg = `READ_VALID;
                casex (ctrl)                        
                    //ADD
                    12'b000000_100000: begin
                        raddr1 = rs_addr;
                        raddr2 = rt_addr;
                        state_next = CAL;
                    end
                    //ADDI
                    12'b001000_xxxxxx: begin
                        raddr1 = rs_addr;
                        raddr2 = 5'b0zzzzz;
                        state_next = CAL;
                    end
                    //ADDU
                    12'b000000_100001: begin
                        raddr1 = rs_addr;
                        raddr2 = rt_addr;
                        state_next = CAL;
                    end
                    //ADDIU
                    12'b001001_xxxxxx: begin
                        raddr1 = rs_addr;
                        state_next = CAL;
                    end
                    //SUB
                    12'b000000_100010: begin
                        raddr1 = rs_addr;
                        raddr2 = rt_addr;
                        state_next = CAL;
                    end
                    //SLT
                    12'b000000_101010: begin
                        raddr1 = rs_addr;
                        raddr2 = rt_addr;
                        state_next = CAL;
                    end
                    //MUL
                    12'b011100_000010: begin
                        raddr1 = rs_addr;
                        raddr2 = rt_addr;
                        state_next = CAL;
                    end
                    //AND
                    12'b000000_100100: begin
                        raddr1 = rs_addr;
                        raddr2 = rt_addr;
                        state_next = CAL;
                    end
                    //ANDI
                    12'b001100_xxxxxx: begin
                        raddr1 = rs_addr;
                        raddr2 = 5'b0zzzzz;
                        state_next = CAL;
                    end
                    //OR
                    12'b000000_100101: begin
                        raddr1 = rs_addr;
                        raddr2 = rt_addr;
                        state_next = CAL;
                    end
                    //ORI
                    12'b001101_xxxxxx: begin
                        raddr1 = rs_addr;
                        raddr2 = 5'b0zzzzz;
                        state_next = CAL;
                    end
                    //XOR
                    12'b000000_100110: begin
                        raddr1 = rs_addr;
                        raddr2 = rt_addr;
                        state_next = CAL;
                    end
                    //XORI
                    12'b001110_xxxxxx: begin
                        raddr1 = rs_addr;
                        raddr2 = 5'b0zzzzz;
                        state_next = CAL;
                    end
                    //SLLV
                    12'b000000_000100: begin
                        raddr1 = rs_addr;
                        raddr2 = rt_addr;
                        state_next = CAL;
                    end
                    //SLL
                    12'b000000_000000: begin
                        raddr1 = 5'b0zzzzz;
                        raddr2 = rt_addr;
                        state_next = CAL;
                    end
                    //SRAV
                    12'b000000_000111: begin
                        raddr1 = rs_addr;
                        raddr2 = rt_addr;
                        state_next = CAL;
                    end
                    //SRA
                    12'b000000_000011: begin
                        raddr1 = 5'b0zzzzz;
                        raddr2 = rt_addr;
                        state_next = CAL;
                    end
                    //SRLV
                    12'b000000_000110: begin
                        raddr1 = rs_addr;
                        raddr2 = rt_addr;
                        state_next = CAL;
                    end
                    //SRL
                    12'b000000_000010: begin
                        raddr1 = 5'b0zzzzz;
                        raddr2 = rt_addr;
                        state_next = CAL;
                    end
                    //LUI
                    12'b001111_xxxxxx: begin
                        state_next = WRI;
                    end
                    //BEQ
                    12'b000100_xxxxxx: begin
                        raddr1 = rs_addr;
                        raddr2 = rt_addr;
                        state_next = CAL;
                    end
                    //BNE
                    12'b000101_xxxxxx: begin
                        raddr1 = rs_addr;
                        raddr2 = rt_addr;
                        state_next = CAL;
                    end
                    //BGEZ
                    12'b000001_xxxxxx: begin
                        raddr1 = rs_addr;
                        raddr2 = 5'd0;
                        state_next = CAL;
                    end
                    //BGTZ
                    //rs>0 -> offset
                    12'b000111_xxxxxx: begin
                        raddr1 = rs_addr;
                        raddr2 = 5'd0;
                        state_next = CAL;
                    end                
                    //BLEZ
                    //rs<=0 -> offset
                    12'b000110_xxxxxx:begin
                        raddr1 = rs_addr;
                        raddr2 = 5'd0;
                        state_next = CAL;
                    end
                    //BLTZ
                    //rs<0 -> offset
                    12'b000001_xxxxxx: begin
                        raddr1 = rs_addr;
                        raddr2 = 5'd0;
                        state_next = CAL;
                    end
                    //JR
                    //->rs
                    12'b000000_001000: begin
                        raddr1 = rs_addr;
                        raddr2 = 5'd0;
                        state_next = CAL;
                    end
                    //JALR
                    //->rs, pc+4 -> rd
                    12'b000000_001001: begin
                        raddr1 = rs_addr;
                        raddr2 = 5'd0;
                        state_next = CAL;
                    end
                    //LB
                    12'b100000_xxxxxx: begin
                        raddr1 = rs_addr;
                        raddr2 = 5'b0zzzzz;
                        state_next = MEM;
                    end
                    //LW
                    12'b100011_xxxxxx: begin
                        raddr1 = rs_addr;
                        raddr2 = 5'b0zzzzz;
                        state_next = MEM;
                    end
                    //SB
                    12'b101000_xxxxxx: begin
                        raddr1 = rs_addr;
                        raddr2 = rt_addr;
                        state_next = MEM;
                    end
                    //SW
                    12'b101011_xxxxxx: begin
                        raddr1 = rs_addr;
                        raddr2 = rt_addr;
                        state_next = MEM;
                    end
                    default:
                        state_next = ERR;
                endcase
            end

            CAL:begin
                casex (ctrl)                    
                    //ADD
                    12'b000000_100000: begin
                        en = `ADDER_ENABLED;
                        num1 = rdata1;
                        num2 = rdata2;
                        inner_ctr = {`SIGNEDADD, `CARRY_DISABLED};
                        new_flag = {28'd0, new_warn, new_overflow, new_carry, new_zero};
                        state_next = WRI;
                    end
                    //ADDI
                    12'b001000_xxxxxx: begin
                        en = `ADDER_ENABLED;
                        inner_ctr = {`SIGNEDADD, `CARRY_DISABLED};
                        num1 = rdata1;
                        num2 = imm_signed;
                        new_flag = {28'd0, new_warn, new_overflow, new_carry, new_zero};
                        state_next = WRI;
                    end
                    //ADDU
                    12'b000000_100001: begin
                        en = `ADDER_ENABLED;
                        inner_ctr = {`UNSIGNEDADD, `CARRY_DISABLED};
                        num1 = rdata1;
                        num2 = rdata2;
                        new_flag = {28'd0, new_warn, 1'b0, new_carry, new_zero};
                        state_next = WRI;
                    end
                    //ADDIU
                    12'b001001_xxxxxx: begin
                        en = `ADDER_ENABLED;
                        inner_ctr = {`SIGNEDADD, `CARRY_DISABLED};
                        num1 = rdata1;
                        num2 = imm_signed;
                        new_flag = {28'd0, new_warn, 1'b0, new_carry, new_zero};
                        state_next = WRI;
                    end
                    //SUB
                    12'b000000_100010: begin
                        en = `ADDER_ENABLED;
                        inner_ctr = {`SIGNEDADD, `CARRY_DISABLED};
                        num1 = rdata1;
                        num2 = {~rdata2[31], rdata2[30:0]};
                        new_flag = {28'd0, new_warn, new_overflow, new_carry, new_zero};
                        state_next = WRI;
                    end
                    //SLT
                    12'b000000_101010: begin
                        en = `ADDER_ENABLED;
                        inner_ctr = {`SIGNEDADD, `CARRY_DISABLED};
                        num1 = rdata1;
                        num2 = {~rdata2[31], rdata2[30:0]};
                        new_flag = {28'd0, new_warn, new_overflow, new_carry, new_zero};
                        state_next = WRI;
                    end
                    //MUL
                    12'b011100_000010: begin
                        en = `MUL_ENABLED;
                        inner_ctr = 2'bzz;
                        num1 = rdata1;
                        num2 = rdata2;
                        new_flag = {28'd0, new_warn, new_overflow, new_carry, new_zero};
                        state_next = WRI;
                    end
                    //AND
                    12'b000000_100100: begin
                        en = `COMB_ENABLED;
                        inner_ctr = `AND;
                        num1 = rdata1;
                        num2 = rdata2;
                        new_flag = {28'd0, new_warn, new_overflow, new_carry, new_zero};
                        state_next = WRI;
                    end
                    //ANDI
                    12'b001100_xxxxxx: begin
                        en = `COMB_ENABLED;
                        inner_ctr = `AND;
                        num1 = rdata1;
                        num2 = imm_zero;
                        new_flag = {28'd0, new_warn, new_overflow, new_carry, new_zero};
                        state_next = WRI;                        
                    end
                    //OR
                    12'b000000_100101: begin
                        en = `COMB_ENABLED;
                        inner_ctr = `OR;
                        num1 = rdata1;
                        num2 = rdata2;
                        new_flag = {28'd0, new_warn, new_overflow, new_carry, new_zero};
                        state_next = WRI;
                    end
                    //ORI
                    12'b001101_xxxxxx: begin
                        en = `COMB_ENABLED;
                        inner_ctr = `OR;
                        num1 = rdata1;
                        num2 = imm_zero;
                        new_flag = {28'd0, new_warn, new_overflow, new_carry, new_zero};
                        state_next = WRI;   
                    end
                    //XOR
                    12'b000000_100110: begin
                        en = `COMB_ENABLED;
                        inner_ctr = `XOR;
                        num1 = rdata1;
                        num2 = rdata2;
                        new_flag = {28'd0, new_warn, new_overflow, new_carry, new_zero};
                        state_next = WRI;
                    end
                    //XORI
                    12'b001110_xxxxxx: begin
                        en = `COMB_ENABLED;
                        inner_ctr = `XOR;
                        num1 = rdata1;
                        num2 = imm_zero;
                        new_flag = {28'd0, new_warn, new_overflow, new_carry, new_zero};
                        state_next = WRI;    
                    end
                    //SLLV
                    12'b000000_000100: begin
                        en = `SFT_ENABLED;
                        inner_ctr = `LOGIC_L;
                        num1 = rdata1;
                        num2 = rdata2;
                        new_flag = {28'd0, new_warn, new_overflow, new_carry, new_zero};
                        state_next = WRI; 
                    end
                    //SLL
                    12'b000000_000000: begin
                        en = `SFT_ENABLED;
                        inner_ctr = `LOGIC_L;
                        num1 = sa_zero;
                        num2 = rdata2;
                        new_flag = {28'd0, new_warn, new_overflow, new_carry, new_zero};
                        state_next = WRI; 
                    end
                    //SRAV
                    12'b000000_000111: begin
                        en = `SFT_ENABLED;
                        inner_ctr = `ARITH_R;
                        num1 = rdata1;
                        num2 = rdata2;
                        new_flag = {28'd0, new_warn, new_overflow, new_carry, new_zero};
                        state_next = WRI; 
                    end
                    //SRA
                    12'b000000_000011: begin
                        en = `SFT_ENABLED;
                        inner_ctr = `ARITH_R;
                        num1 = sa_zero;
                        num2 = rdata2;
                        new_flag = {28'd0, new_warn, new_overflow, new_carry, new_zero};
                        state_next = WRI; 
                    end
                    //SRLV
                    12'b000000_000110: begin
                        en = `SFT_ENABLED;
                        inner_ctr = `LOGIC_R;
                        num1 = rdata1;
                        num2 = rdata2;
                        new_flag = {28'd0, new_warn, new_overflow, new_carry, new_zero};
                        state_next = WRI; 
                    end
                    //SRL
                    12'b000000_000010: begin
                        en = `SFT_ENABLED;
                        inner_ctr = `LOGIC_R;
                        num1 = sa_zero;
                        num2 = rdata2;
                        new_flag = {28'd0, new_warn, new_overflow, new_carry, new_zero};
                        state_next = WRI; 
                    end
                    //BEQ
                    12'b000100_xxxxxx: begin
                        en = `ADDER_ENABLED;
                        inner_ctr = {`SIGNEDADD, `CARRY_DISABLED};
                        num1 = rdata1;
                        num2 = {~rdata2[31], rdata2[30:0]};
                        new_flag = {28'd0, new_warn, new_overflow, new_carry, new_zero};
                        state_next = FIN;
                    end
                    //BNE
                    12'b000101_xxxxxx: begin
                        en = `ADDER_ENABLED;
                        inner_ctr = {`SIGNEDADD, `CARRY_DISABLED};
                        num1 = rdata1;
                        num2 = {~rdata2[31], rdata2[30:0]};
                        new_flag = {28'd0, new_warn, new_overflow, new_carry, new_zero};
                        state_next = FIN;
                    end
                    //BGEZ
                    //rs>=0 -> offset
                    12'b000001_xxxxxx: begin
                        en = `ALL_DISABLED;
                        inner_ctr = 2'b0zz;
                        num1 = rdata1;
                        new_flag = {27'd0, num1[31], new_warn, new_overflow, new_carry, new_zero};
                        state_next = FIN;
                    end
                    //BGTZ
                    //rs>0 -> offset
                    12'b000111_xxxxxx: begin
                        en = `ALL_DISABLED;
                        inner_ctr = 2'b0zz;
                        num1 = rdata1;
                        new_flag = {27'd0, num1[31], new_warn, new_overflow, new_carry, new_zero};
                        state_next = FIN;
                    end
                    //BLEZ
                    //rs<=0 -> offset
                    12'b000110_xxxxxx: begin
                        en = `ALL_DISABLED;
                        inner_ctr = 2'b0zz;
                        num1 = rdata1;
                        new_flag = {27'd0, num1[31], new_warn, new_overflow, new_carry, new_zero};
                        state_next = FIN;
                    end
                    //BLTZ
                    //rs<0 -> offset
                    12'b000001_xxxxxx: begin
                        en = `ALL_DISABLED;
                        inner_ctr = 2'b0zz;
                        num1 = rdata1;
                        new_flag = {27'd0, num1[31], new_warn, new_overflow, new_carry, new_zero};
                        state_next = FIN;
                    end
                    //JR
                    //->rs
                    12'b000000_001000: begin
                        en = `ALL_DISABLED;
                        inner_ctr = 2'b0zz;
                        alu_rd = rdata1;
                        state_next = FIN;
                    end
                    //JALR
                    //->rs, pc+4 -> rd
                    12'b000000_001001: begin
                        en = `ALL_DISABLED;
                        inner_ctr = 2'b0zz;
                        alu_rd = rdata1;
                        state_next = FIN;
                    end
                    default: begin
                        num1 = 32'h0zzzz_zzzz;
                        num2 = 32'h0zzzz_zzzz;
                        state_next = ERR;
                    end
                endcase
                rw_flag = `WRITE_VALID;
            end

            WRI:begin
                casex (ctrl)
                    //ADD
                    12'b000000_100000: begin
                        rw_reg = `WRITE_VALID;
                        wdata = res;
                        waddr = rd_addr;
                        state_next = FIN;
                    end
                    //ADDI
                    12'b001000_xxxxxx: begin
                        rw_reg = `WRITE_VALID;
                        wdata = res;
                        waddr = rt_addr;
                        state_next = FIN;
                    end
                    //ADDU
                    12'b000000_100001: begin
                        rw_reg = `WRITE_VALID;
                        wdata = res;
                        waddr = rd_addr;
                        state_next = FIN;
                    end
                    //ADDIU
                    12'b001001_xxxxxx: begin
                        rw_reg = `WRITE_VALID;
                        wdata = res;
                        waddr = rt_addr;
                        state_next = FIN;
                    end
                    //SUB
                    12'b000000_100010: begin
                        rw_reg = `WRITE_VALID;
                        wdata = res;
                        waddr = rd_addr;
                        state_next = FIN;
                    end
                    //SLT
                    12'b000000_101010: begin
                        rw_reg = `WRITE_VALID;
                        if (new_overflow) begin
                            //若溢出，即ab异号，则可根据被减数符号确认比较结果
                            //正(0)则大(0)， 负(1)则小(1)
                            wdata = {31'd0, num1[31]};
                        end
                        else if (!new_overflow) begin
                            //若未溢出，则ab同号，可根据结果符号确认比较结果
                            wdata = {31'd0, res[31]};
                        end
                        waddr = rd_addr;
                        state_next = FIN;
                    end
                    //MUL
                    12'b011100_000010: begin
                        rw_reg = `WRITE_VALID;
                        wdata = res;
                        waddr = rd_addr;
                        state_next = FIN;
                    end
                    //AND
                    12'b000000_100100: begin
                        rw_reg = `WRITE_VALID;
                        wdata = res;
                        waddr = rd_addr;
                        state_next = FIN;
                    end
                    //ANDI
                    12'b001100_xxxxxx: begin
                        rw_reg = `WRITE_VALID;
                        wdata = res;
                        waddr = rt_addr;
                        state_next = FIN;
                    end
                    //OR
                    12'b000000_100101: begin
                        rw_reg = `WRITE_VALID;
                        wdata = res;
                        waddr = rd_addr;
                        state_next = FIN;
                    end
                    //ORI
                    12'b001101_xxxxxx: begin
                        rw_reg = `WRITE_VALID;
                        wdata = res;
                        waddr = rt_addr;
                        state_next = FIN;
                    end
                    //XOR
                    12'b000000_100110: begin
                        rw_reg = `WRITE_VALID;
                        wdata = res;
                        waddr = rd_addr;
                        state_next = FIN;
                    end
                    //XORI
                    12'b001110_xxxxxx: begin
                        rw_reg = `WRITE_VALID;
                        wdata = res;
                        waddr = rt_addr;
                        state_next = FIN;
                    end
                    //SLLV
                    12'b000000_000100: begin
                        rw_reg = `WRITE_VALID;
                        wdata = res;
                        waddr = rd_addr;
                        state_next = FIN;
                    end
                    //SLL
                    12'b000000_000000: begin
                        rw_reg = `WRITE_VALID;
                        wdata = res;
                        waddr = rd_addr;
                        state_next = FIN;
                    end
                    //SRAV
                    12'b000000_000111: begin
                        rw_reg = `WRITE_VALID;
                        wdata = res;
                        waddr = rd_addr;
                        state_next = FIN;
                    end
                    //SRA
                    12'b000000_000011: begin
                        rw_reg = `WRITE_VALID;
                        wdata = res;
                        waddr = rd_addr;
                        state_next = FIN;
                    end
                    //SRLV
                    12'b000000_000110: begin
                        rw_reg = `WRITE_VALID;
                        wdata = res;
                        waddr = rd_addr;
                        state_next = FIN;
                    end
                    //SRL
                    12'b000000_000010: begin
                        rw_reg = `WRITE_VALID;
                        wdata = res;
                        waddr = rd_addr;
                        state_next = FIN;
                    end
                    //LUI
                    12'b001111_xxxxxx: begin
                        rw_reg = `WRITE_VALID;
                        wdata = {imm, 16'b0};
                        waddr = rt_addr;
                        state_next = FIN;
                    end
                    //LB
                    12'b100000_xxxxxx: begin
                        if (mem_ref == `FULL) begin
                            wdata = {{24{rmem[7]}}, rmem}; 
                            waddr = rt_addr;
                            state_next = FIN;
                        end
                        else begin
                            state_next = WRI;
                        end
                    end
                    //LW
                    12'b100011_xxxxxx: begin
                        rw_reg = `WRITE_VALID;
                        waddr = rt_addr;
                        state_next = FIN;
                    end
                    default:
                        state_next = ERR;
                endcase
            end

            MEM:begin
                casex (aluctr)
                //LB
                12'b100000_xxxxxx: begin
                    mem_addr = rdata1 + imm_signed;
                    case (mem_addr[31:28])
                        4'h0b: mem_addr[31:28] = 4'b0001;
                        4'h0a: mem_addr[31:28] = 4'b0000;
                        4'h09: mem_addr[31:28] = 4'b0001;
                        4'h08: mem_addr[31:28] = 4'b0000;
                        4'h07: mem_addr[31:28] = 4'h8;
                        4'h06: mem_addr[31:28] = 4'h7;
                        4'h05: mem_addr[31:28] = 4'h6;
                        4'h04: mem_addr[31:28] = 4'h5;
                        4'h03: mem_addr[31:28] = 4'h4;
                        4'h02: mem_addr[31:28] = 4'h3;
                        4'h01: mem_addr[31:28] = 4'h2;
                        4'h00: mem_addr[31:28] = 4'h1;
                        default: mem_addr[31:28] = mem_addr[31:28];
                    endcase
                    rw_mem = `READ_VALID;
                    state_next = WRI;
                end
                //LW
                12'b100011_xxxxxx: begin
                    if (mem_count==0) begin
                        rw_mem = `READ_VALID;
                        mem_addr = rdata1 + imm_signed;
                        case (mem_addr[31:28])
                            4'h0b: mem_addr[31:28] = 4'b0001;
                            4'h0a: mem_addr[31:28] = 4'b0000;
                            4'h09: mem_addr[31:28] = 4'b0001;
                            4'h08: mem_addr[31:28] = 4'b0000;
                            4'h07: mem_addr[31:28] = 4'h8;
                            4'h06: mem_addr[31:28] = 4'h7;
                            4'h05: mem_addr[31:28] = 4'h6;
                            4'h04: mem_addr[31:28] = 4'h5;
                            4'h03: mem_addr[31:28] = 4'h4;
                            4'h02: mem_addr[31:28] = 4'h3;
                            4'h01: mem_addr[31:28] = 4'h2;
                            4'h00: mem_addr[31:28] = 4'h1;
                            default: mem_addr[31:28] = mem_addr[31:28];
                        endcase
                        //若非4倍，触发ERR
                        if (mem_addr[1:0]!=2'b00)
                            state_next = ERR;
                        if (mem_ref==`EMPTY)
                            state_next = MEM;
                        else if (mem_ref == `FULL)
                        begin
                            wdata[7:0] = rmem;
                            mem_count = mem_count + 1;
                            state_next = MEM;
                        end
                    end
                    else if (mem_count == 1) begin
                        mem_addr = mem_addr + 1;
                        if (mem_ref==`EMPTY)
                            state_next = MEM;
                        else if (mem_ref == `FULL)
                        begin
                            wdata[15:8] = rmem;
                            mem_count = mem_count + 1;
                            state_next = MEM;
                        end
                    end
                    else if (mem_count == 2) begin
                        mem_addr = mem_addr + 2;
                        if (mem_ref==`EMPTY)
                            state_next = MEM;
                        else if (mem_ref == `FULL)
                        begin
                            wdata[23:16] = rmem;
                            mem_count = mem_count + 1;
                            state_next = MEM;
                        end
                    end
                    else if (mem_count == 3) begin
                        mem_addr = mem_addr + 3;
                        if (mem_ref==`EMPTY)
                            state_next = MEM;
                        else if (mem_ref == `FULL)
                        begin
                            wdata[31:24] = rmem;
                            mem_count = mem_count + 1;
                            state_next = WRI;
                        end
                    end
                end
                //SB
                12'b101000_xxxxxx: begin
                    rw_mem = `WRITE_VALID;
                    mem_addr = rdata1 + imm_signed;
                    case (mem_addr[31:28])
                        4'h0b: mem_addr[31:28] = 4'b0001;
                        4'h0a: mem_addr[31:28] = 4'b0000;
                        4'h09: mem_addr[31:28] = 4'b0001;
                        4'h08: mem_addr[31:28] = 4'b0000;
                        4'h07: mem_addr[31:28] = 4'h8;
                        4'h06: mem_addr[31:28] = 4'h7;
                        4'h05: mem_addr[31:28] = 4'h6;
                        4'h04: mem_addr[31:28] = 4'h5;
                        4'h03: mem_addr[31:28] = 4'h4;
                        4'h02: mem_addr[31:28] = 4'h3;
                        4'h01: mem_addr[31:28] = 4'h2;
                        4'h00: mem_addr[31:28] = 4'h1;
                        default: mem_addr[31:28] = mem_addr[31:28];
                    endcase
                    wmem = rdata2[7:0];
                    state_next = FIN;
                end
                //SW
                12'b101011_xxxxxx: begin
                    if (mem_count==0) begin
                        rw_mem = `WRITE_VALID;
                        mem_addr = rdata1 + imm_signed;
                        case (mem_addr[31:28])
                            4'h0b: mem_addr[31:28] = 4'b0001;
                            4'h0a: mem_addr[31:28] = 4'b0000;
                            4'h09: mem_addr[31:28] = 4'b0001;
                            4'h08: mem_addr[31:28] = 4'b0000;
                            4'h07: mem_addr[31:28] = 4'h8;
                            4'h06: mem_addr[31:28] = 4'h7;
                            4'h05: mem_addr[31:28] = 4'h6;
                            4'h04: mem_addr[31:28] = 4'h5;
                            4'h03: mem_addr[31:28] = 4'h4;
                            4'h02: mem_addr[31:28] = 4'h3;
                            4'h01: mem_addr[31:28] = 4'h2;
                            4'h00: mem_addr[31:28] = 4'h1;
                            default: mem_addr[31:28] = mem_addr[31:28];
                        endcase
                        //若非4倍，触发ERR
                        if (mem_addr[1:0]!=2'b00)
                            state_next = ERR;
                        if (mem_ref==`EMPTY)
                            state_next = MEM;
                        else if (mem_ref == `FULL)
                        begin
                            wmem = rdata2[7:0];
                            mem_count = mem_count + 1;
                            state_next = MEM;
                        end
                    end
                    else if (mem_count == 1) begin
                        mem_addr = mem_addr + 1;
                        if (mem_ref==`EMPTY)
                            state_next = MEM;
                        else if (mem_ref == `FULL)
                        begin
                            wmem = rdata2[15:8];
                            mem_count = mem_count + 1;
                            state_next = MEM;
                        end
                    end
                    else if (mem_count == 2) begin
                        mem_addr = mem_addr + 2;
                        if (mem_ref==`EMPTY)
                            state_next = MEM;
                        else if (mem_ref == `FULL)
                        begin
                            wmem = rdata2[23:16];
                            mem_count = mem_count + 1;
                            state_next = MEM;
                        end
                    end
                    else if (mem_count == 3) begin
                        mem_addr = mem_addr + 3;
                        if (mem_ref==`EMPTY)
                            state_next = MEM;
                        else if (mem_ref == `FULL)
                        begin
                            wmem = rdata2[31:24];
                            mem_count = mem_count + 1;
                            state_next = FIN;
                        end
                    end
                    state_next = FIN;
                end
                default:
                    state_next = INIT;
                endcase
            end

            FIN:begin
                alu_cs = `ACTIVE;
                rw_flag = `READ_VALID;
                ctrl = aluctr;
                // shutdown alu<->reg to enable pcu<->reg
                rw_reg = 1'bz;
                raddr1 = 5'b0zzzzz;
                raddr2 = 5'b0zzzzz;
                waddr = 5'b0zzzzz;
                wdata = 32'b0zzzzzzzz_zzzzzzzz_zzzzzzzz_zzzzzzzz;
                if (goahead==`FULL) begin
                    en = `ALL_DISABLED;
                    state_next = INIT;
                end
                else if (goahead==`EMPTY) begin
                    en = `ALL_DISABLED;
                    state_next = FIN;
                end
                else
                    state_next = ERR;
            end

            ERR:begin
                state_next = ERR;
            end

            default:begin
                state_next = INIT;
            end
        endcase
    end
endmodule