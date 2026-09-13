`timescale 1ns/1ps

module tb_dual_bitcoin_hash_core;
    reg clk = 1'b0;
    reg start = 1'b0;
    reg stop = 1'b0;
    reg [255:0] midstate;
    reg [95:0] tail;
    reg [255:0] target;
    wire core0_running;
    wire core0_found;
    wire [31:0] core0_found_nonce;
    wire [255:0] core0_found_hash;
    wire [31:0] core0_current_nonce;
    wire core1_running;
    wire core1_found;
    wire [31:0] core1_found_nonce;
    wire [255:0] core1_found_hash;
    wire [31:0] core1_current_nonce;
    reg core0_report_select = 1'b0;
    reg core1_report_select = 1'b0;
    reg [8:0] report_bit_index = 9'd0;
    wire core0_report_bit;
    wire core1_report_bit;

    localparam [255:0] CORE0_HASH =
        256'hbf483998a9b44cbf5a113973e34da96b5cf3c7757d75ac3bd7c6b30af5a7c12b;
    localparam [255:0] CORE1_HASH =
        256'h71db64cd9bf90d1a28f0676dd83a7481f3655b85e330a189a0ed433174d13d57;

    bitcoin_hash_core #(
        .START_NONCE(32'd0),
        .NONCE_STRIDE(32'd2)
    ) core0 (
        .clk(clk),
        .start(start),
        .stop(stop),
        .midstate(midstate),
        .tail(tail),
        .target(target),
        .running(core0_running),
        .found(core0_found),
        .found_nonce(core0_found_nonce),
        .found_hash(core0_found_hash),
        .current_nonce(core0_current_nonce),
        .report_select(core0_report_select),
        .report_bit_index(report_bit_index),
        .report_bit_out(core0_report_bit)
    );

    bitcoin_hash_core #(
        .START_NONCE(32'd1),
        .NONCE_STRIDE(32'd2)
    ) core1 (
        .clk(clk),
        .start(start),
        .stop(stop),
        .midstate(midstate),
        .tail(tail),
        .target(target),
        .running(core1_running),
        .found(core1_found),
        .found_nonce(core1_found_nonce),
        .found_hash(core1_found_hash),
        .current_nonce(core1_current_nonce),
        .report_select(core1_report_select),
        .report_bit_index(report_bit_index),
        .report_bit_out(core1_report_bit)
    );

    always #5 clk = ~clk;

    task check_report_bits;
        input select_core1;
        input [31:0] expected_nonce;
        input [255:0] expected_hash;
        reg [287:0] expected_result;
        integer bit_idx;
        begin
            expected_result = {expected_nonce, expected_hash};
            core0_report_select = !select_core1;
            core1_report_select = select_core1;

            for (bit_idx = 0; bit_idx < 288; bit_idx = bit_idx + 1) begin
                report_bit_index = bit_idx[8:0];
                #1;
                if ((select_core1 ? core1_report_bit : core0_report_bit) !== expected_result[287 - bit_idx]) begin
                    $display("FAIL report bit core%0d bit %0d expected %b got %b",
                             select_core1, bit_idx, expected_result[287 - bit_idx],
                             (select_core1 ? core1_report_bit : core0_report_bit));
                    $finish(1);
                end
            end

            core0_report_select = 1'b0;
            core1_report_select = 1'b0;
            report_bit_index = 9'd0;
        end
    endtask

    initial begin
        midstate = 256'hbc909a336358bff090ccac7d1e59caa8c3c8d8e94f0103c896b187364719f91b;
        tail = 96'h4b1e5e4a29ab5f49ffff001d;
        target = 256'hffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

        repeat (4) @(posedge clk);
        @(negedge clk);
        start = 1'b1;
        @(posedge clk);
        @(negedge clk);
        start = 1'b0;

        wait(core0_found && core1_found);
        @(posedge clk);

        if (core0_found_nonce !== 32'h00000000) begin
            $display("FAIL core0 nonce: %h", core0_found_nonce);
            $finish(1);
        end

        if (core1_found_nonce !== 32'h00000001) begin
            $display("FAIL core1 nonce: %h", core1_found_nonce);
            $finish(1);
        end

        if (core0_found_hash !== CORE0_HASH) begin
            $display("FAIL core0 hash: %h", core0_found_hash);
            $finish(1);
        end

        if (core1_found_hash !== CORE1_HASH) begin
            $display("FAIL core1 hash: %h", core1_found_hash);
            $finish(1);
        end

        check_report_bits(1'b0, 32'h00000000, CORE0_HASH);
        check_report_bits(1'b1, 32'h00000001, CORE1_HASH);

        $display("PASS dual bitcoin hash cores");
        $finish(0);
    end
endmodule
