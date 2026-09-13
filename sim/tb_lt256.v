`timescale 1ns/1ps

module tb_lt256;
    reg [255:0] a;
    reg [255:0] b;
    wire lt;

    lt256 dut (
        .a(a),
        .b(b),
        .lt(lt)
    );

    task check;
        input [255:0] lhs;
        input [255:0] rhs;
        input expected;
        begin
            a = lhs;
            b = rhs;
            #1;
            if (lt !== expected) begin
                $display("FAIL lt256: %h < %h expected %b got %b", lhs, rhs, expected, lt);
                $finish(1);
            end
        end
    endtask

    initial begin
        check(256'd0, 256'd0, 1'b0);
        check(256'd0, 256'd1, 1'b1);
        check(256'd1, 256'd0, 1'b0);
        check(256'h00ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
              256'h0100000000000000000000000000000000000000000000000000000000000000, 1'b1);
        check(256'h0100000000000000000000000000000000000000000000000000000000000000,
              256'h00ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 1'b0);
        check(256'hfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
              256'hffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 1'b1);
        check(256'hffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
              256'hfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe, 1'b0);

        $display("PASS lt256");
        $finish(0);
    end
endmodule
