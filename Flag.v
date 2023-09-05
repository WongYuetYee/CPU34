//////////////////////////////////////////////////////////////////////////////////
// high effective
// 0: zero flag             ---HE
// 1: carry flag            ---HE
// 2: Integer overflow flag ---HE
// 3: warning flag          ---HE
// 4: sign flag             ---HE
//////////////////////////////////////////////////////////////////////////////////

module Flag(rst, rw, new_flag, flag);
// TODO: remove Latch
    input rst, rw;
    input [31:0] new_flag;
    output [31:0] flag;

    reg [31:0] flag_temp;
//----------------------------------------------------------------

    always @(*)
    begin
        if (!rst)
            flag_temp = 32'h0;
        else if (!rw)
            // // overflow neglected sometimes
            // if (new_flag[2] == 1'bz)
            //     new_flag[2] = flag_temp[2];
            flag_temp = new_flag;
        else
            flag_temp = flag_temp;
    end

    assign flag = flag_temp;

endmodule