`timescale 1ns/1ps

module tb_dual_bitcoin_hash_core;
    reg clk = 1'b0;
    reg reset = 1'b1;
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

    bitcoin_hash_core #(
        .START_NONCE(32'd0),
        .NONCE_STRIDE(32'd2)
    ) core0 (
        .clk(clk),
        .reset(reset),
        .start(start),
        .stop(stop),
        .midstate(midstate),
        .tail(tail),
        .target(target),
        .running(core0_running),
        .found(core0_found),
        .found_nonce(core0_found_nonce),
        .found_hash(core0_found_hash),
        .current_nonce(core0_current_nonce)
    );

    bitcoin_hash_core #(
        .START_NONCE(32'd1),
        .NONCE_STRIDE(32'd2)
    ) core1 (
        .clk(clk),
        .reset(reset),
        .start(start),
        .stop(stop),
        .midstate(midstate),
        .tail(tail),
        .target(target),
        .running(core1_running),
        .found(core1_found),
        .found_nonce(core1_found_nonce),
        .found_hash(core1_found_hash),
        .current_nonce(core1_current_nonce)
    );

    always #5 clk = ~clk;

    initial begin
        midstate = 256'hbc909a336358bff090ccac7d1e59caa8c3c8d8e94f0103c896b187364719f91b;
        tail = 96'h4b1e5e4a29ab5f49ffff001d;
        target = 256'hffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

        repeat (4) @(posedge clk);
        reset <= 1'b0;
        @(posedge clk);
        start <= 1'b1;
        @(posedge clk);
        start <= 1'b0;

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

        if (core0_found_hash !== 256'hbf483998a9b44cbf5a113973e34da96b5cf3c7757d75ac3bd7c6b30af5a7c12b) begin
            $display("FAIL core0 hash: %h", core0_found_hash);
            $finish(1);
        end

        if (core1_found_hash === core0_found_hash) begin
            $display("FAIL core1 hash matched core0 hash");
            $finish(1);
        end

        $display("PASS dual bitcoin hash cores");
        $finish(0);
    end
endmodule
