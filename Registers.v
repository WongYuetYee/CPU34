`define READ_VALID 1'b1
`define WRITE_VALID 1'b0

`define ACTIVE 1'b0
`define INACTIVE 1'b1

module Registers(rst,
                 raddr1, raddr2,
                 waddr, wdata,
                 rw,
                 out1, out2);
    input rst;
    input [4:0] raddr1;
    input [4:0] raddr2;
    input [4:0] waddr;
    input [31:0] wdata;
    input rw;
    output[31:0] out1;
    output[31:0] out2;

    reg [31:0] data[31:0];

    reg [31:0] out1;
    reg [31:0] out2;
//----------------------------------------------------------------
    // 0¼Ä´æÆ÷
    always @(negedge rst)
        if (rst == `ACTIVE)
            data[0] <= 32'd0;    

    //write
    always @(*) begin
        if ((rw==`WRITE_VALID) && (waddr!=0))
            data[waddr] <= wdata;
    end
    
    //read
    always @(*)  begin
        if (rw==`READ_VALID)
        begin
            out1 <= data[raddr1];
            out2 <= data[raddr2];
        end
    end
   
endmodule