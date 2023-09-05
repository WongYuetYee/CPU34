def str2instr(instr):
    op_dict = {"ADD" : ["000000", "100000"],
               "ADDI" : ["001000", ""],
               "ADDU" : ["000000", "100001"],
               "ADDIU" : ["001001", ""],
               "SUB" : ["000000", "100010"],
               "SLT" : ["000000", "101010"],
               "MUL" : ["011100", "000010"],
               "AND" : ["000000", "100100"],
               "ANDI" : ["001100", ""],
               "LUI" : ["001111", ""],
               "OR" : ["000000", "100101"],
               "ORI" : ["001101", ""],
               "XOR" : ["000000", "100110"],
               "XORI" : ["001110", ""],
               "SLLV" : ["000000", "000100"],
               "SLL" : ["000000", "000000"],
               "SRAV" : ["000000", "000111"],
               "SRA" : ["000000", "000011"],
               "SRLV" : ["000000", "000110"],
               "SRL" : ["000000", "000010"],
               "BEQ" : ["000100", ""],
                "BNE" : ["000101",""],
                "BGEZ" : ["000001",""],
                "BGTZ" : ["000111",""],
                "BLEZ" : ["000110",""],
                "BLTZ" : ["000001",""],
                "J" : ["000010",""],
                "JAL" : ["000011",""],
                "JR" : ["000000", "001000"],
                "JALR" : ["000000", "001001"],
                "LB" : ["100000",""],
                "LW" : ["100011",""],
                "SB" : ["101000",""],
                "SW" : ["101011",""]}
    
    reg_dict = {"$0" : "00000",
                "$1" : "00001",
                "$2" : "00010",
                "$3" : "00011",
                "$4" : "00100",
                "$5" : "00101",
                "$6" : "00110",
                "$7" : "00111",
                "$8" : "01000",
                "$9" : "01001",
                "$10" : "01010",
                "$11" : "01011",
                "$12" : "01100",
                "$13" : "01101",
                "$14" : "01110",
                "$15" : "01111",
                "$16" : "10000",
                "$17" : "10001",
                "$18" : "10010",
                "$19" : "10011",
                "$20" : "10100",
                "$21" : "10101",
                "$22" : "10110",
                "$23" : "10111",
                "$24" : "11000",
                "$25" : "11001",
                "$26" : "11010",
                "$27" : "11011",
                "$28" : "11100",
                "$29" : "11101",
                "$30" : "11110",
                "$31" : "11111"}
    
    instr = instr.split(' ')
    opcode = ["", "", "", "", "", ""]
    
    # OP: opcode[0]
    opcode[0] = op_dict[instr[0]][0]
    
    if (len(instr) == 4):
        #registers
        for x_ind, x in enumerate(instr):
            if (x[0] == '$'):
                opcode[x_ind] = reg_dict[x]
                
        match instr[0]:
            case 'ADD'|'ADDU'|'SUB'|'SLT'|'MUL'|'AND'|'OR'|'XOR'|'SLLV'|'SRAV'|'SRLV'|'JALR':
                opcode[4] = "00000"
                opcode[5] = op_dict[instr[0]][1]
            case _:
                #imm
                if (instr[3][0] == '#'):
                    imm = dec2bin(instr[3][1:], 16)
                    opcode[3] = imm[0:5]
                    opcode[4] = imm[5:10]
                    opcode[5] = imm[10:16]
    elif (len(instr) == 5):
        #registers
        for x_ind, x in enumerate(instr):
            if (x[0] == '$'):
                opcode[x_ind] = reg_dict[x]
        #sa
        if (instr[4][0] == '#'):
            opcode[4] = dec2bin(instr[4][1:], 5)
            opcode[5] = op_dict[instr[0]][1]
        else:
            # if error
            print(instr)

    elif (len(instr) == 2):
        match instr[0]:
            case 'J'|'JAL':
                ind = dec2bin((instr[1][1:]), 26)
                opcode[1] = ind[0:5]
                opcode[2] = ind[5:10]
                opcode[3] = ind[10:15]
                opcode[4] = ind[15:20]
                opcode[5] = ind[20:]
            case 'JR':
                # registers
                for x_ind, x in enumerate(instr):
                    if (x[0] == '$'):
                        opcode[x_ind] = reg_dict[x]
                opcode[2] = '00000'
                opcode[3] = '00000'
                opcode[4] = '00000'
                opcode[5] = op_dict[instr[0]][1]
            case _:
                print(instr)
    return ''.join(opcode)

def dec2bin(dec, bits):
    #cope with negative
    if (dec[0]=='-'):
        sign = '1'
        dec = dec[1:]
    else:
        sign = '0'
    #str->int
    dec = int(dec, 10)
    #base10->base2
    dec = bin(dec)[2:]
    if (sign == '1'):
        res = sign + (bits-len(dec)-1)*'0' + dec
    else:
        res = (bits-len(dec))*'0' + dec
    return res

file_name = "instr.txt"
output_file = "code.txt"
with open(file_name, "r") as f1:
    lines = f1.readlines()
with open(output_file, "w") as f2:
    count = 0
    for line in lines:
        if (line[0] == '\t'):
            f2.write(line)
        else:
            line = line.rstrip("\n").replace('r', '$').replace('m', '#')
            code = str2instr(line)
            instr = "\t\tdata[{}] = 8'b{};\n".format(count*4, code[0:8])
            instr = instr + "\t\tdata[{}] = 8'b{};\n".format(count*4+1, code[8:16])
            instr = instr + "\t\tdata[{}] = 8'b{};\n".format(count*4+2, code[16:24])
            instr = instr + "\t\tdata[{}] = 8'b{};\n".format(count*4+3, code[24:32])
            count = count + 1
            f2.write(instr)
f1.close()
f2.close()
