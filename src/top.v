`default_nettype wire

module top #(
    parameter CLK_FREQ = 27000000,    // 27MHz for Tang Nano, 100MHz or similar for K7
    parameter BAUD_RATE = 115200,
    parameter CORES = 1
)(
    input clk,
    input uart_rx_pin,
    output uart_tx_pin,
    output [5:0] led
);
    // Compute UART Bit Period Tick count
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam JOB_BYTES = 76;
    localparam FOUND_RESP_BYTES = 37;
    localparam ECHO_RESP_BYTES = 77;

    reg [23:0] reset_counter = 24'd0;
    wire reset = !reset_counter[23];

    always @(posedge clk) begin
        if (!reset_counter[23]) begin
            reset_counter <= reset_counter + 24'd1;
        end
    end

    wire [7:0] rx_data;
    wire rx_valid;
    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) rx0 (
        .clk(clk),
        .reset(reset),
        .rx(uart_rx_pin),
        .data(rx_data),
        .valid(rx_valid)
    );

    reg tx_start;
    reg [7:0] tx_data;
    wire tx_busy;
    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) tx0 (
        .clk(clk),
        .reset(reset),
        .start(tx_start),
        .data(tx_data),
        .tx(uart_tx_pin),
        .busy(tx_busy)
    );

    reg core_start;
    reg core_stop;
    reg core_start_pending;
    reg core_start_after_active_load;
    reg core_start_after_active_load_d1;
    reg [255:0] midstate = 256'd0;
    reg [95:0] tail = 96'd0;
    reg [255:0] target = 256'd0;
    reg [255:0] active_midstate = 256'd0;
    reg [95:0] active_tail = 96'd0;
    reg [255:0] active_target = 256'd0;
    
    wire [CORES-1:0] coreX_running;
    wire [CORES-1:0] coreX_found;
    wire [31:0] led_current_nonce;
    wire [CORES*8-1:0] coreX_report_byte;

    // wire found = core0_found || core1_found;
    // wire [31:0] found_nonce = core0_found ? core0_found_nonce : core1_found_nonce;
    // wire [255:0] found_hash = core0_found ? core0_found_hash : core1_found_hash;

    localparam CORE_INDEX_BITS = (CORES <= 1) ? 1 : $clog2(CORES);

    reg found;
    reg [CORE_INDEX_BITS-1:0] found_index;
    integer idx;
    integer report_select_idx;

    // Select the lowest-numbered core reporting a found nonce.
    always @(*) begin
        found = 1'b0;
        found_index = {CORE_INDEX_BITS{1'b0}};
        for (idx = 0; idx < CORES; idx = idx + 1) begin
            if (coreX_found[idx] && !found) begin
                found = 1'b1;
                found_index = idx;
            end
        end
    end

    reg [CORE_INDEX_BITS-1:0] report_found_index;
    wire [CORES-1:0] report_select = {{(CORES-1){1'b0}}, 1'b1} << report_found_index;
    reg [7:0] selected_report_byte;
    reg report_load;
    reg report_shift;

    always @(*) begin
        selected_report_byte = 8'h00;
        for (report_select_idx = 0; report_select_idx < CORES; report_select_idx = report_select_idx + 1) begin
            if (report_found_index == report_select_idx[CORE_INDEX_BITS-1:0]) begin
                selected_report_byte = coreX_report_byte[report_select_idx * 8 +: 8];
            end
        end
    end

    bitcoin_hash_core #(
        .START_NONCE(0),
        .NONCE_STRIDE(CORES)
    ) core0 (
        .clk(clk),
        .start(core_start),
        .stop(core_stop),
        .midstate(active_midstate),
        .tail(active_tail),
        .target(active_target),
        .running(coreX_running[0]),
        .found(coreX_found[0]),
        .found_nonce(),
        .found_hash(),
        .current_nonce(led_current_nonce),
        .report_byte_out(coreX_report_byte[7:0]),
        .report_load(report_load),
        .report_shift(report_shift),
        .report_select(report_select[0]),
        .report_bit_index(9'd0),
        .report_bit_out()
    );

    genvar i;
    generate
    for (i = 1; i < CORES; i = i + 1) begin : gg
        bitcoin_hash_core #(
            .START_NONCE(i),
            .NONCE_STRIDE(CORES)
        ) coreX (
            .clk(clk),
            .start(core_start),
            .stop(core_stop),
            .midstate(active_midstate),
            .tail(active_tail),
            .target(active_target),
            .running(coreX_running[i]),
            .found(coreX_found[i]),
            .found_nonce(),
            .found_hash(),
            .current_nonce(),
            .report_byte_out(coreX_report_byte[i * 8 +: 8]),
            .report_load(report_load),
            .report_shift(report_shift),
            .report_select(report_select[i]),
            .report_bit_index(9'd0),
            .report_bit_out()
        );
    end
    endgenerate

    localparam R_SYNC0 = 3'd0;
    localparam R_SYNC1 = 3'd1;
    localparam R_CMD = 3'd2;
    localparam R_PAYLOAD = 3'd3;

    reg [2:0] rx_state;
    reg [6:0] payload_count;
    reg [7:0] command;

    localparam T_IDLE = 3'd0;
    localparam T_PREP_LOAD = 3'd1;
    localparam T_SHIFT_REPORT = 3'd2;
    localparam T_PREP_SEND = 3'd3;
    localparam T_SEND = 3'd4;
    localparam T_WAIT = 3'd5;

    reg [2:0] tx_state;
    reg [6:0] tx_index;
    reg [7:0] report_sample_byte;
    reg found_seen;
    reg echo_toggle;
    reg echo_seen_toggle;
    reg tx_echo;

    function [7:0] echo_response_byte;
        input [6:0] index;
        begin
            case (index)
                7'd0: echo_response_byte = "E";
                7'd1: echo_response_byte = midstate[255:248];
                7'd2: echo_response_byte = midstate[247:240];
                7'd3: echo_response_byte = midstate[239:232];
                7'd4: echo_response_byte = midstate[231:224];
                7'd5: echo_response_byte = midstate[223:216];
                7'd6: echo_response_byte = midstate[215:208];
                7'd7: echo_response_byte = midstate[207:200];
                7'd8: echo_response_byte = midstate[199:192];
                7'd9: echo_response_byte = midstate[191:184];
                7'd10: echo_response_byte = midstate[183:176];
                7'd11: echo_response_byte = midstate[175:168];
                7'd12: echo_response_byte = midstate[167:160];
                7'd13: echo_response_byte = midstate[159:152];
                7'd14: echo_response_byte = midstate[151:144];
                7'd15: echo_response_byte = midstate[143:136];
                7'd16: echo_response_byte = midstate[135:128];
                7'd17: echo_response_byte = midstate[127:120];
                7'd18: echo_response_byte = midstate[119:112];
                7'd19: echo_response_byte = midstate[111:104];
                7'd20: echo_response_byte = midstate[103:96];
                7'd21: echo_response_byte = midstate[95:88];
                7'd22: echo_response_byte = midstate[87:80];
                7'd23: echo_response_byte = midstate[79:72];
                7'd24: echo_response_byte = midstate[71:64];
                7'd25: echo_response_byte = midstate[63:56];
                7'd26: echo_response_byte = midstate[55:48];
                7'd27: echo_response_byte = midstate[47:40];
                7'd28: echo_response_byte = midstate[39:32];
                7'd29: echo_response_byte = midstate[31:24];
                7'd30: echo_response_byte = midstate[23:16];
                7'd31: echo_response_byte = midstate[15:8];
                7'd32: echo_response_byte = midstate[7:0];
                7'd33: echo_response_byte = tail[95:88];
                7'd34: echo_response_byte = tail[87:80];
                7'd35: echo_response_byte = tail[79:72];
                7'd36: echo_response_byte = tail[71:64];
                7'd37: echo_response_byte = tail[63:56];
                7'd38: echo_response_byte = tail[55:48];
                7'd39: echo_response_byte = tail[47:40];
                7'd40: echo_response_byte = tail[39:32];
                7'd41: echo_response_byte = tail[31:24];
                7'd42: echo_response_byte = tail[23:16];
                7'd43: echo_response_byte = tail[15:8];
                7'd44: echo_response_byte = tail[7:0];
                7'd45: echo_response_byte = target[255:248];
                7'd46: echo_response_byte = target[247:240];
                7'd47: echo_response_byte = target[239:232];
                7'd48: echo_response_byte = target[231:224];
                7'd49: echo_response_byte = target[223:216];
                7'd50: echo_response_byte = target[215:208];
                7'd51: echo_response_byte = target[207:200];
                7'd52: echo_response_byte = target[199:192];
                7'd53: echo_response_byte = target[191:184];
                7'd54: echo_response_byte = target[183:176];
                7'd55: echo_response_byte = target[175:168];
                7'd56: echo_response_byte = target[167:160];
                7'd57: echo_response_byte = target[159:152];
                7'd58: echo_response_byte = target[151:144];
                7'd59: echo_response_byte = target[143:136];
                7'd60: echo_response_byte = target[135:128];
                7'd61: echo_response_byte = target[127:120];
                7'd62: echo_response_byte = target[119:112];
                7'd63: echo_response_byte = target[111:104];
                7'd64: echo_response_byte = target[103:96];
                7'd65: echo_response_byte = target[95:88];
                7'd66: echo_response_byte = target[87:80];
                7'd67: echo_response_byte = target[79:72];
                7'd68: echo_response_byte = target[71:64];
                7'd69: echo_response_byte = target[63:56];
                7'd70: echo_response_byte = target[55:48];
                7'd71: echo_response_byte = target[47:40];
                7'd72: echo_response_byte = target[39:32];
                7'd73: echo_response_byte = target[31:24];
                7'd74: echo_response_byte = target[23:16];
                7'd75: echo_response_byte = target[15:8];
                7'd76: echo_response_byte = target[7:0];
                default: echo_response_byte = 8'h00;
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (reset) begin
            rx_state <= R_SYNC0;
            payload_count <= 7'd0;
            command <= 8'd0;
            core_start <= 1'b0;
            core_stop <= 1'b0;
            core_start_pending <= 1'b0;
            core_start_after_active_load <= 1'b0;
            core_start_after_active_load_d1 <= 1'b0;
            echo_toggle <= 1'b0;
        end else begin
            core_start <= 1'b0;
            core_stop <= 1'b0;

            if (core_start_after_active_load_d1) begin
                core_start <= 1'b1;
                core_start_after_active_load_d1 <= 1'b0;
            end

            if (core_start_after_active_load) begin
                core_start_after_active_load_d1 <= 1'b1;
                core_start_after_active_load <= 1'b0;
            end

            if (core_start_pending) begin
                core_start_after_active_load <= 1'b1;
                core_start_pending <= 1'b0;
            end

            if (rx_valid) begin
                case (rx_state)
                    R_SYNC0: rx_state <= (rx_data == "T") ? R_SYNC1 : R_SYNC0;
                    R_SYNC1: rx_state <= (rx_data == "N") ? R_CMD : R_SYNC0;
                    R_CMD: begin
                        command <= rx_data;
                        payload_count <= 7'd0;
                        if (rx_data == "S") begin
                            core_stop <= 1'b1;
                            rx_state <= R_SYNC0;
                        end else if (rx_data == "H") begin
                            core_start_pending <= 1'b1;
                            rx_state <= R_SYNC0;
                        end else if (rx_data == "J" || rx_data == "E") begin
                            rx_state <= R_PAYLOAD;
                        end else begin
                            rx_state <= R_SYNC0;
                        end
                    end
                    R_PAYLOAD: begin
                        if (payload_count == JOB_BYTES - 1) begin
                            if (command == "J") begin
                                core_start_pending <= 1'b1;
                            end else if (command == "E") begin
                                echo_toggle <= ~echo_toggle;
                            end
                            rx_state <= R_SYNC0;
                        end else begin
                            payload_count <= payload_count + 7'd1;
                        end
                    end
                    default: rx_state <= R_SYNC0;
                endcase
            end
        end
    end

    always @(posedge clk) begin
        if (rx_valid) begin
            case (rx_state)
                R_CMD: begin
                    if (rx_data == "H") begin
                        midstate <= 256'hbc909a336358bff090ccac7d1e59caa8c3c8d8e94f0103c896b187364719f91b;
                        tail <= 96'h4b1e5e4a29ab5f49ffff001d;
                        target <= 256'hffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
                    end
                end

                R_PAYLOAD: begin
                    if (payload_count < 7'd32) begin
                        midstate <= {midstate[247:0], rx_data};
                    end else if (payload_count < 7'd44) begin
                        tail <= {tail[87:0], rx_data};
                    end else if (payload_count < 7'd76) begin
                        target <= {target[247:0], rx_data};
                    end
                end
            endcase
        end
    end

    always @(posedge clk) begin
        if (core_start_pending) begin
            active_midstate <= midstate;
            active_tail <= tail;
            active_target <= target;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            tx_state <= T_IDLE;
            tx_index <= 6'd0;
            tx_start <= 1'b0;
            tx_data <= 8'hff;
            report_found_index <= {CORE_INDEX_BITS{1'b0}};
            report_sample_byte <= 8'h00;
            report_load <= 1'b0;
            report_shift <= 1'b0;
            found_seen <= 1'b0;
            echo_seen_toggle <= 1'b0;
            tx_echo <= 1'b0;
        end else begin
            tx_start <= 1'b0;
            report_load <= 1'b0;
            report_shift <= 1'b0;

            if (!found) begin
                found_seen <= 1'b0;
            end

            case (tx_state)
                T_IDLE: begin
                    if (echo_seen_toggle != echo_toggle) begin
                        tx_index <= 7'd0;
                        tx_echo <= 1'b1;
                        tx_state <= T_SEND;
                        echo_seen_toggle <= echo_toggle;
                    end else if (found && !found_seen) begin
                        tx_index <= 7'd0;
                        tx_echo <= 1'b0;
                        report_found_index <= found_index;
                        tx_state <= T_PREP_LOAD;
                        found_seen <= 1'b1;
                    end
                end

                T_PREP_LOAD: begin
                    report_load <= 1'b1;
                    tx_state <= T_PREP_SEND;
                end

                T_SHIFT_REPORT: begin
                    report_shift <= 1'b1;
                    tx_state <= T_PREP_SEND;
                end

                T_PREP_SEND: begin
                    report_sample_byte <= selected_report_byte;
                    tx_state <= T_SEND;
                end

                T_SEND: begin
                    if (!tx_busy) begin
                        tx_data <= tx_echo ? echo_response_byte(tx_index) : report_sample_byte;
                        tx_start <= 1'b1;
                        tx_state <= T_WAIT;
                    end
                end

                T_WAIT: begin
                    if (tx_busy) begin
                        if ((!tx_echo && tx_index == FOUND_RESP_BYTES - 1) ||
                            (tx_echo && tx_index == ECHO_RESP_BYTES - 1)) begin
                            tx_state <= T_IDLE;
                        end else begin
                            tx_index <= tx_index + 7'd1;
                            tx_state <= tx_echo ? T_SEND : T_SHIFT_REPORT;
                        end
                    end
                end

                default: tx_state <= T_IDLE;
            endcase
        end
    end

    wire led_core_running = |coreX_running;
    // wire [31:0] led_current_nonce = coreX_current_nonce[found_index * 32 +: 32];

    assign led[0] = ~led_core_running;
    assign led[1] = ~found;
    assign led[2] = ~led_current_nonce[20];
    assign led[3] = ~led_current_nonce[21];
    assign led[4] = ~led_current_nonce[22];
    assign led[5] = ~led_current_nonce[23];
endmodule
