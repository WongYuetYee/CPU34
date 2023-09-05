import random

def write_instr(res, ctr):
    bits = 32
    output_file = "instr.txt"
    # with open(output_file, "a+") as f2:
    with open(output_file, "w") as f2:
        for x in res:
            f2.write(getcomm(ctr, x) + '\n')
            if (ctr in ['ADD', 'ADDU', 'SUB', 'MUL', 'AND', 'OR', 'XOR', 'SLT']):
                write_reg = getinstr_imm2reg(x[2], 1)
                f2.write(write_reg[0] + write_reg[1])
                write_reg = getinstr_imm2reg(x[3], 2)
                f2.write(write_reg[0] + write_reg[1])
                f2.write( ctr + ' r1 r2 r31\n')
            elif (ctr in ['SLLV', 'SRAV', 'SRLV']):
                write_reg = getinstr_imm2reg(x[2], 1)
                f2.write(write_reg[0] + write_reg[1])
                write_reg = getinstr_imm2reg(x[3], 2)
                f2.write(write_reg[0] + write_reg[1])
                f2.write( ctr + ' r1 r2 r31\n')
            elif (ctr in ['ADDI', 'ADDIU', 'ANDI', 'XORI']):
                write_reg = getinstr_imm2reg(x[2], 1)
                f2.write(write_reg[0] + write_reg[1])
                f2.write( ctr + ' r1 r31 m' + str(int(x[3], 16)) + '\n')
            elif (ctr in ['SLL', 'SRA', 'SRL']):
                write_reg = getinstr_imm2reg(x[2], 1)
                f2.write(write_reg[0] + write_reg[1])
                f2.write( ctr + ' r0 r1 r31 m' + str(int(x[3], 16)) + '\n')
            else:
                print('wrong ctr ' + ctr)
                
def num_gen(n, ctr):
    unsbits = 2 ** 32 - 1
    sigbits = 2 ** 31 - 1
    immbits = 2 ** 15 - 1
    unsimmbits = 2 ** 16 - 1
    sabits = 2 ** 5 - 1
    res = []
    match ctr:
        case 'ADDIU' | 'ADDI': 
            for i in range(n):
                num1 = random.randint(-sigbits, sigbits)
                num2 = random.randint(-immbits, immbits)
                res.append([num1, num2, dec2hex(num1, 32), dec2hex(num2, 16)])
        case 'ANDI' | 'XORI':
            for i in range(n):
                num1 = random.randint(0, unsbits)
                num2 = random.randint(0, unsimmbits)
                res.append([num1, num2, dec2hex(num1, 32), dec2hex(num2, 16)])
        case 'ADDU':
            for i in range(n):
                num1 = random.randint(0, unsbits)
                num2 = random.randint(0, unsbits)
                res.append([num1, num2, dec2hex(num1, 32), dec2hex(num2, 32)])
        case 'SLL' | 'SRA' | 'SRL':
            for i in range(n):
                num1 = random.randint(0, unsbits)
                num2 = random.randint(0, sabits)
                res.append([num1, num2, dec2hex(num1, 32), dec2hex(num2, 5)])
        case 'SLLV' | 'SRAV' | 'SRLV' | 'AND' | 'OR' | 'XOR':
            for i in range(n):
                num1 = random.randint(0, unsbits)
                num2 = random.randint(0, unsbits)
                res.append([num1, num2, dec2hex(num1, 32), dec2hex(num2, 32)])
        case 'ADD' | 'SUB' | 'MUL' | 'SLT':
            for i in range(n):
                num1 = random.randint(-sigbits, sigbits)
                num2 = random.randint(-sigbits, sigbits)
                res.append([num1, num2, dec2hex(num1, 32), dec2hex(num2, 32)])
        case _:
            print('wrong ctr ' + ctr)
    return res
    
def getcomm(ctr, x):
    a = x[0]
    b = x[1]
    ahex = x[2]
    bhex = x[3]
    if (ctr in ['ADD', 'ADDI', 'ADDU', 'ADDIU']):
        res = a + b
    elif (ctr == 'SUB'):
        res = a - b
    elif (ctr == 'MUL'):
        res = a * b
        reshex = bin(abs(res))[2:]
        if (res<0):
            reshex = ''.join(['1' if (reshex=='0') else '0' for reshex in reshex])[-32:]
        else:
            reshex = reshex[-32:]
        reshex = hex(int(reshex, 2))

    # logic left
    elif ((ctr == 'SLLV')):
        b = b & 0xffffffff
        a_cut = a & 0b11111
        res = (b << a_cut) & 0xffffffff
    elif ((ctr == 'SLL')):
        a = a & 0xffffffff
        b_cut = b & 0b11111
        res = (a << b_cut) & 0xffffffff
    # arithmatic right
    elif ((ctr == 'SRAV') ):
        b = b & 0xffffffff
        a_cut = a & 0b11111
        res = b >> a_cut
        b_sign = (b >> 31) & 1
        if b_sign:
            res |= (0xffffffff << (32 - a_cut))
    elif ((ctr == 'SRA')):
        a = a & 0xffffffff
        b_cut = b & 0b11111
        res = a >> b_cut
        a_sign = (a >> 31) & 1
        if a_sign:
            res |= (0xffffffff << (32 - b_cut))
    # logic right
    elif (ctr =='SRLV'):
        b = b & 0xffffffff
        a_cut = a & 0b11111
        res = (b >> a_cut) & 0xffffffff
    elif (ctr == 'SRL'):
        a = a & 0xffffffff
        b_cut = b & 0b11111
        res = (a >> b_cut) & 0xffffffff 
    elif (ctr in ['AND', 'ANDI']):
        res = a & b
    elif (ctr in ['OR', 'ORI']):
        res = a | b
    elif (ctr in ['XOR', 'XORI']):
        res = a ^ b
    elif (ctr == 'SLT'):
        res = ((a-b)<0)

    if ((res > 0xffffffff) & (ctr != 'MUL')):
        reshex = hex(res)[:-8] + '_' + hex(res)[-8:]
    elif ((ctr in ['ADD', 'SUB', 'ADDI', 'ADDIU']) & (abs(res) > 0x7fffffff)):
        if (ctr == 'ADDIU'):
            reshex = 'hidden overflow'
        else:
            reshex = 'overflow'
    elif (ctr == 'MUL'):
        reshex = reshex[-8:].replace('x', '0')
    else:
        reshex = dec2hex(res, 32)

    comm = "\t\t// " + str(a) + ' ' + ctr + ' ' + str(b) + ' = ' + str(res) + '\n'
    comm = comm + "\t\t//H " + ahex + ' ' + ctr + ' ' + bhex + ' = ' + reshex
    # if (ctr == 'ADDIU'):
    #     comm = "\t\t//H " + ahex + ' ' + ctr + ' sign_ext(' + bhex + ')->'
    #     if (int(bhex[4], 16)>7):
    #         bhex = 'ffff'+bhex[4:]
    #     comm = comm + bhex
    return comm

def getinstr_imm2reg(imm, reg):
    if ((reg<0) | (reg>31) | (len(imm)!=8)):
        print('imm2reg WRONG.')
    reg = str(reg)
    lui = ( 'LUI r0 r' + reg + ' m' + str(int(imm[:4], 16))+'\n')
    ori = ( 'ORI r' + reg +' r' + reg + ' m' + str(int(imm[4:], 16))+'\n')
    return [lui, ori]

def dec2hex(dec, bits):
    #cope with negative
    sign = 0 if (dec>=0) else 1
    dec = abs(dec)
    #base10->base2
    dec = bin(dec)[2:]
    bin_ori = str(sign) + (bits-len(dec)-1)*'0' + dec
    return "{:08x}".format(int(bin_ori, 2))


# ctr_dic = ['ADD', 'ADDI', 'ADDU', 'ADDIU',
#            'SUB', 'SLT', 'MUL', 'AND',
#            'ANDI', 'OR',
#            'XOR', 'XORI', 'SLLV', 'SLL',
#            'SRAV', 'SRA', 'SRLV', 'SRL']
# for ctr in ctr_dic:
#     write_instr(num_gen(1, ctr), ctr)

ctr = 'SRLV'
write_instr(num_gen(5, ctr), ctr)
