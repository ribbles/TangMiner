`timescale 1ns/1ps

module tb_bitcoin_hash_core;
    localparam [255:0] TEST_MIDSTATE =
        256'hbc909a336358bff090ccac7d1e59caa8c3c8d8e94f0103c896b187364719f91b;
    localparam [95:0] TEST_TAIL = 96'h4b1e5e4a29ab5f49ffff001d;

    localparam [255:0] HASH0 =
        256'hbf483998a9b44cbf5a113973e34da96b5cf3c7757d75ac3bd7c6b30af5a7c12b;
    localparam [255:0] HASH3 =
        256'h1498a37b8059cca064bcc16d7a727156907beb5d9bd4641b003b09d911b00f1c;
    localparam [255:0] HASH0_REVERSED =
        256'h2bc1a7f50ab3c6d73bac757d75c7f35c6ba94de37339115abf4cb4a9983948bf;

    reg clk = 1'b0;
    reg start = 1'b0;
    reg stop = 1'b0;
    reg [255:0] midstate;
    reg [95:0] tail;
    reg [255:0] target;
    reg report_select = 1'b0;
    reg [8:0] report_bit_index = 9'd0;

    wire running;
    wire found;
    wire [31:0] found_nonce;
    wire [255:0] found_hash;
    wire [31:0] current_nonce;
    wire report_bit_out;

    bitcoin_hash_core dut (
        .clk(clk),
        .start(start),
        .stop(stop),
        .midstate(midstate),
        .tail(tail),
        .target(target),
        .running(running),
        .found(found),
        .found_nonce(found_nonce),
        .found_hash(found_hash),
        .current_nonce(current_nonce),
        .report_select(report_select),
        .report_bit_index(report_bit_index),
        .report_bit_out(report_bit_out)
    );

    always #5 clk = ~clk;

    task fail;
        input [8*80-1:0] message;
        begin
            $display("FAIL %0s", message);
            $finish(1);
        end
    endtask

    task init_inputs;
        begin
            @(negedge clk);
            start = 1'b0;
            stop = 1'b0;
            report_select = 1'b0;
            report_bit_index = 9'd0;
            midstate = TEST_MIDSTATE;
            tail = TEST_TAIL;
            repeat (4) @(posedge clk);
            @(posedge clk);
        end
    endtask

    task pulse_start;
        begin
            @(negedge clk);
            start = 1'b1;
            @(posedge clk);
            @(negedge clk);
            start = 1'b0;
        end
    endtask

    task pulse_stop;
        begin
            @(negedge clk);
            stop = 1'b1;
            @(posedge clk);
            @(negedge clk);
            stop = 1'b0;
        end
    endtask

    task wait_for_found;
        integer cycles;
        begin
            cycles = 0;
            while (!found && cycles < 2000) begin
                @(posedge clk);
                cycles = cycles + 1;
            end

            if (!found) begin
                fail("timed out waiting for found");
            end
        end
    endtask

    task expect_found_result;
        input [31:0] expected_nonce;
        input [255:0] expected_hash;
        begin
            if (!found) begin
                fail("found is not asserted");
            end

            if (found_nonce !== expected_nonce) begin
                $display("expected nonce %h, got %h", expected_nonce, found_nonce);
                fail("bad found nonce");
            end

            if (found_hash !== expected_hash) begin
                $display("expected hash %h", expected_hash);
                $display("got      hash %h", found_hash);
                fail("bad found hash");
            end
        end
    endtask

    task check_report_bits;
        input [31:0] expected_nonce;
        input [255:0] expected_hash;
        reg [287:0] expected_result;
        integer bit_idx;
        begin
            expected_result = {expected_nonce, expected_hash};
            report_select = 1'b1;
            for (bit_idx = 0; bit_idx < 288; bit_idx = bit_idx + 1) begin
                report_bit_index = bit_idx[8:0];
                #1;
                if (report_bit_out !== expected_result[287 - bit_idx]) begin
                    $display("report bit %0d expected %b got %b",
                             bit_idx, expected_result[287 - bit_idx], report_bit_out);
                    fail("bad report bit");
                end
            end

            report_select = 1'b0;
            report_bit_index = 9'd0;
            #1;
            if (report_bit_out !== 1'b0) begin
                fail("report bit should be zero when not selected");
            end
        end
    endtask

    initial begin
        target = 256'd0;

        init_inputs();

        target = 256'hffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
        pulse_start();
        @(posedge clk);
        if (!running) begin
            fail("core did not enter running state after start");
        end
        wait_for_found();
        expect_found_result(32'h00000000, HASH0);
        check_report_bits(32'h00000000, HASH0);

        init_inputs();

        target = HASH0_REVERSED;
        pulse_start();
        wait_for_found();
        expect_found_result(32'h00000003, HASH3);

        init_inputs();

        target = 256'd0;
        pulse_start();
        repeat (30) @(posedge clk);
        if (!running) begin
            fail("core stopped before stop request");
        end
        if (found) begin
            fail("zero target should not find quickly");
        end
        pulse_stop();
        @(posedge clk);
        if (running) begin
            fail("core did not stop");
        end
        if (found) begin
            fail("core asserted found after stop");
        end

        target = 256'hffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
        pulse_start();
        wait_for_found();
        expect_found_result(32'h00000000, HASH0);

        $display("PASS bitcoin hash core");
        $finish(0);
    end
endmodule
