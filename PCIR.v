`define READ_VALID 1'b1
`define WRITE_VALID 1'b0

`define ACTIVE 1'b0
`define INACTIVE 1'b1

`define FULL 1'b1
`define EMPTY 1'b0

module PCIR(clk, rst, flag, finish, pcir_cs, program_count, opcode,
            rw_reg, alu_rd, waddr, wdata);
    input clk;
    input rst;
    input finish;
    input [31:0] flag;
    input [31:0] opcode;

    output reg pcir_cs;
    output reg [31:0] program_count;

    //===to reg
    input [31:0] alu_rd;
    output reg rw_reg;
    output reg [4:0]  waddr;
    output reg [31:0] wdata;

    //===to opcode
    wire [11:0] pcu_ctr;
    assign pcu_ctr = {opcode[31:26], opcode[5:0]};
    //---rs
    wire [4:0] rs_addr, rd_addr;
    assign rs_addr = opcode[25:21];
    assign rd_addr = opcode[15:11];
    //---offset
    wire [15:0] offset;
    assign offset = opcode[15:0];
    wire [31:0] offset_zero;
    assign offset_zero = {offset[15], 16'd0, offset[14:0]};
    //---instr_index
    wire [25:0] instr_index;
    assign instr_index = opcode[25:0];

    //===to flag
    wire zero;
    assign zero = flag[0];
    wire sign_flag;
    assign sign_flag = flag[4];

    //
    reg count;

    //pc
    always @(negedge clk) begin
        if (rst == `ACTIVE) begin
            pcir_cs = `INACTIVE;
            program_count = 0;
            count = 0;
            rw_reg = `READ_VALID;
            waddr = 5'b0zzzzz;
            wdata = 32'b0zzzzzzzz_zzzzzzzz_zzzzzzzz_zzzzzzzz;
        end
        else if (finish == `FULL) begin
            pcir_cs = `ACTIVE;
            casex (pcu_ctr)
                //BEQ
                //rs==rt then offset
                12'b000100_xxxxxx: begin
                    if (count==`FULL) begin
                        if (zero == `FULL) begin
                            program_count = program_count + {{16{offset[15]}},(offset<<2)};
                        end
                        else if (zero == `EMPTY) begin
                            program_count = program_count + 4;
                        end
                    end
                    else if (count==`EMPTY) begin
                        program_count = program_count;
                    end
                    count = ~count;
                end
                //BNE
                //rs!=rt then offset
                12'b000101_xxxxxx: begin
                    if (count==`FULL) begin
                        if (zero == `EMPTY) begin
                            program_count = program_count + (offset[15] ? -(offset_zero<<2):(offset_zero<<2));
                        end
                        else begin
                            program_count = program_count + 4;
                        end
                    end
                    else if (count==`EMPTY) begin
                        program_count = program_count;
                    end
                    count = ~count;
                end
                //BGEZ
                //rs>=0 -> offset
                12'b000001_xxxxxx: begin
                    if (count==`FULL) begin
                        if (sign_flag == `EMPTY) begin
                            program_count = program_count + (offset[15] ? -(offset_zero<<2):(offset_zero<<2));
                        end
                        else if (sign_flag == `FULL)begin
                            program_count = program_count + 4;
                        end
                    end
                    else if (count==`EMPTY) begin
                        program_count = program_count;
                    end
                    count = ~count;
                end
                //BGTZ
                //rs>0 -> offset
                12'b000111_xxxxxx: begin
                    if (count==`FULL) begin
                        if ((sign_flag == `EMPTY) && (zero != `FULL)) begin
                            program_count = program_count + (offset[15] ? -(offset_zero<<2):(offset_zero<<2));
                        end
                        else begin
                            program_count = program_count + 4;
                        end
                    end
                    else if (count==`EMPTY) begin
                        program_count = program_count;
                    end
                    count = ~count;
                end
                //BLEZ
                //rs<=0 -> offset
                12'b000110_xxxxxx: begin
                    if (count==`FULL) begin
                        if ((sign_flag == `FULL) || (zero == `FULL)) begin
                            program_count = program_count + (offset[15] ? -(offset_zero<<2):(offset_zero<<2));
                        end
                        else begin
                            program_count = program_count + 4;
                        end
                    end
                    else if (count==`EMPTY) begin
                        program_count = program_count;
                    end
                    count = ~count;
                end
                //BLTZ
                //rs<0 -> offset
                12'b000001_xxxxxx: begin
                    if (count==`FULL) begin
                        if (sign_flag == `FULL) begin
                            program_count = program_count + (offset[15] ? -(offset_zero<<2):(offset_zero<<2));
                        end
                        else begin
                            program_count = program_count + 4;
                        end
                    end
                    else if (count==`EMPTY) begin
                        program_count = program_count;
                    end
                    count = ~count;
                end
                //J
                //->instr_index
                12'b000010_xxxxxx: begin
                    program_count = {program_count[31:28], {(instr_index<<2)}};
                end
                //JAL
                //->instr_index, PC_origin+4 -> REG$31
                12'b000011_xxxxxx: begin
                    if (count==`FULL) begin
                        rw_reg = `READ_VALID;
                        program_count = {program_count[31:28], {(instr_index<<2)}};
                    end
                    else if (count==`EMPTY) begin
                        rw_reg = `WRITE_VALID;
                        waddr = 5'd31;
                        wdata = program_count + 4;
                        program_count = program_count;
                    end
                    count = ~count;
                end
                //JR
                //->rs
                12'b000000_001000: begin
                    if (count==`FULL) begin
                        program_count = alu_rd;
                    end
                    else if (count==`EMPTY) begin
                        program_count = program_count;
                    end
                    count = ~count;
                end
                //JALR
                //->rs, pc+4 -> rd
                12'b000000_001001: begin
                    if (count==`FULL) begin
                        rw_reg <= `READ_VALID;
                        program_count = alu_rd;
                    end
                    else if (count==`EMPTY) begin
                        rw_reg <= `WRITE_VALID;
                        waddr <= rd_addr;
                        wdata <= program_count +4;
                        program_count = program_count;
                    end
                    count = ~count;
                end
            default: begin
                rw_reg = 1'bz;
                waddr = 5'b0zzzzz;
                wdata = 32'b0zzzzzzzz_zzzzzzzz_zzzzzzzz_zzzzzzzz;
                program_count = program_count + 4;
            end
            endcase
        end
        else begin
            rw_reg = 1'bz;
            waddr = 5'b0zzzzz;
            wdata = 32'b0zzzzzzzz_zzzzzzzz_zzzzzzzz_zzzzzzzz;
            pcir_cs = `INACTIVE;
            program_count = program_count;
            count = count;
        end
    end

endmodule