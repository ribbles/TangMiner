`timescale 1ns/1ps

module tb_uart_top;
    localparam integer CLK_FREQ = 6400000;
    localparam integer BAUD_RATE = 100000;
    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

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
    reg uart_rx_pin = 1'b1;
    wire uart_tx_pin;
    wire [5:0] led;
    wire [7:0] mon_rx_data;
    wire mon_rx_valid;

    top #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE),
        .CORES(1)
    ) dut (
        .clk(clk),
        .uart_rx_pin(uart_rx_pin),
        .uart_tx_pin(uart_tx_pin),
        .led(led)
    );

    uart_rx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) tx_monitor (
        .clk(clk),
        .reset(dut.reset),
        .rx(uart_tx_pin),
        .data(mon_rx_data),
        .valid(mon_rx_valid)
    );

    always #5 clk = ~clk;

    task fail;
        input [8*96-1:0] message;
        begin
            $display("FAIL %0s", message);
            $finish(1);
        end
    endtask

    task wait_clks;
        input integer count;
        integer i;
        begin
            for (i = 0; i < count; i = i + 1) begin
                @(posedge clk);
            end
        end
    endtask

    task uart_send_byte;
        input [7:0] byte_value;
        integer bit_idx;
        begin
            uart_rx_pin = 1'b0;
            wait_clks(CLKS_PER_BIT);

            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                uart_rx_pin = byte_value[bit_idx];
                wait_clks(CLKS_PER_BIT);
            end

            uart_rx_pin = 1'b1;
            wait_clks(CLKS_PER_BIT);
        end
    endtask

    task uart_recv_byte;
        output [7:0] byte_value;
        integer timeout_cycles;
        begin
            byte_value = 8'h00;
            while (mon_rx_valid === 1'b1) begin
                @(posedge clk);
            end

            timeout_cycles = 0;
            while (((mon_rx_valid !== 1'b1) || (^mon_rx_data === 1'bx)) && timeout_cycles < (CLKS_PER_BIT * 6000)) begin
                @(posedge clk);
                timeout_cycles = timeout_cycles + 1;
            end

            if ((mon_rx_valid !== 1'b1) || (^mon_rx_data === 1'bx)) begin
                fail("timed out waiting for uart tx byte");
            end

            byte_value = mon_rx_data;
        end
    endtask

    task send_sync_and_cmd;
        input [7:0] cmd;
        begin
            uart_send_byte("T");
            uart_send_byte("N");
            uart_send_byte(cmd);
        end
    endtask

    function [7:0] job_payload_byte;
        input integer idx;
        integer b;
        begin
            if (idx < 32) begin
                b = idx;
                job_payload_byte = TEST_MIDSTATE[(31 - b) * 8 +: 8];
            end else if (idx < 44) begin
                b = idx - 32;
                job_payload_byte = TEST_TAIL[(11 - b) * 8 +: 8];
            end else begin
                b = idx - 44;
                job_payload_byte = 8'hff;
            end
        end
    endfunction

    task send_job_payload;
        input [255:0] target_value;
        integer idx;
        integer b;
        begin
            for (idx = 0; idx < 76; idx = idx + 1) begin
                if (idx < 44) begin
                    uart_send_byte(job_payload_byte(idx));
                end else begin
                    b = idx - 44;
                    uart_send_byte(target_value[(31 - b) * 8 +: 8]);
                end
            end
        end
    endtask

    task expect_echo_packet;
        input [255:0] target_value;
        reg [7:0] rx_byte;
        integer idx;
        integer b;
        begin
            uart_recv_byte(rx_byte);
            if (rx_byte !== "E") begin
                $display("unexpected echo header byte: %02h", rx_byte);
                fail("bad echo header");
            end

            for (idx = 0; idx < 76; idx = idx + 1) begin
                uart_recv_byte(rx_byte);
                if (idx < 44) begin
                    if (rx_byte !== job_payload_byte(idx)) begin
                        $display("echo mismatch at payload byte %0d expected %02h got %02h",
                                 idx, job_payload_byte(idx), rx_byte);
                        fail("bad echoed payload");
                    end
                end else begin
                    b = idx - 44;
                    if (rx_byte !== target_value[(31 - b) * 8 +: 8]) begin
                        $display("echo mismatch at target byte %0d expected %02h got %02h",
                                 b, target_value[(31 - b) * 8 +: 8], rx_byte);
                        fail("bad echoed target");
                    end
                end
            end
        end
    endtask

    task expect_found_packet_current_impl;
        input [31:0] expected_nonce;
        input [255:0] expected_hash;
        reg [7:0] rx_byte;
        integer idx;
        begin
            uart_recv_byte(rx_byte);
            if (rx_byte !== "F") begin
                $display("unexpected found header byte: %02h", rx_byte);
                fail("bad found header");
            end

            for (idx = 0; idx < 4; idx = idx + 1) begin
                uart_recv_byte(rx_byte);
                if (rx_byte !== expected_nonce[(3 - idx) * 8 +: 8]) begin
                    $display("nonce mismatch at byte %0d expected %02h got %02h",
                             idx, expected_nonce[(3 - idx) * 8 +: 8], rx_byte);
                    fail("bad found nonce bytes");
                end
            end

            for (idx = 0; idx < 32; idx = idx + 1) begin
                uart_recv_byte(rx_byte);
                if (rx_byte !== expected_hash[(31 - idx) * 8 +: 8]) begin
                    $display("hash mismatch at byte %0d expected %02h got %02h",
                             idx, expected_hash[(31 - idx) * 8 +: 8], rx_byte);
                    fail("bad found hash bytes");
                end
            end
        end
    endtask

    task expect_tx_idle;
        input integer cycles;
        integer i;
        begin
            for (i = 0; i < cycles; i = i + 1) begin
                @(posedge clk);
                if (uart_tx_pin != 1'b1) begin
                    fail("unexpected uart tx activity");
                end
            end
        end
    endtask

    initial begin
        force dut.reset_counter = 24'h7ffff0;
        wait_clks(4);
        release dut.reset_counter;
        wait_clks(40);

        send_sync_and_cmd("E");
        send_job_payload(256'hffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        $display("stage: waiting echo");
        expect_echo_packet(256'hffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);

        send_sync_and_cmd("J");
        send_job_payload(256'hffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        $display("stage: waiting found");
        expect_found_packet_current_impl(32'h00000000, HASH0);

        send_sync_and_cmd("J");
        send_job_payload(HASH0_REVERSED);
        $display("stage: waiting found nonce3");
        expect_found_packet_current_impl(32'h00000003, HASH3);

        send_sync_and_cmd("J");
        send_job_payload(256'd0);
        wait_clks(CLKS_PER_BIT * 200);
        send_sync_and_cmd("S");
        $display("stage: checking stop idle");
        expect_tx_idle(CLKS_PER_BIT * 200);

        $display("PASS uart top protocol");
        $finish(0);
    end
endmodule
