`define ACTIVE 1'b0
`define INACTIVE 1'b1

`define READ_VALID 1'b1
`define WRITE_VALID 1'b0

`define FULL 1'b1
`define EMPTY 1'b0

module PCU(clk, rst, alu_cs, pcir_cs, finish, goahead);
    input clk, rst;

    input alu_cs, pcir_cs;

    output reg finish;
    output reg goahead;

    always @(negedge rst or negedge alu_cs or negedge pcir_cs) begin
        if (rst == `ACTIVE) begin
            finish = `EMPTY;
        end
        else begin
            if (alu_cs == `ACTIVE)
                finish = `FULL;

            if (pcir_cs == `ACTIVE)
                finish = `EMPTY;
        end
    end

    always @(negedge rst or posedge alu_cs or posedge pcir_cs) begin
        if (rst == `ACTIVE) begin
            goahead = `FULL;
        end
        else begin
            if (alu_cs == `INACTIVE)
                goahead = `EMPTY;

            if (pcir_cs == `INACTIVE)
                goahead = `FULL;
        end
    end

endmodule