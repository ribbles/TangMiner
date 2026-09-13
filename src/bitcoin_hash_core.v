`default_nettype wire

module bitcoin_hash_core #(
    parameter [31:0] START_NONCE = 32'd0,
    parameter [31:0] NONCE_STRIDE = 32'd1
) (
    input clk,
    input start,
    input stop,
    input [255:0] midstate,
    input [95:0] tail,
    input [255:0] target,
    output reg running = 1'b0,
    output reg found = 1'b0,
    output reg [31:0] found_nonce = 32'd0,
    output reg [255:0] found_hash = 256'd0,
    output reg [31:0] current_nonce = 32'd0,
    output [7:0] report_byte_out,
    input report_load,
    input report_shift,
    input report_select,
    input [8:0] report_bit_index,
    output report_bit_out
);
    localparam [255:0] SHA256_IV = {
        32'h6a09e667, 32'hbb67ae85, 32'h3c6ef372, 32'ha54ff53a,
        32'h510e527f, 32'h9b05688c, 32'h1f83d9ab, 32'h5be0cd19
    };

    localparam S_IDLE = 3'd0;          // Wait for start.
    localparam S_FIRST_START = 3'd1;   // Assert the first compression start pulse.
    localparam S_FIRST_WAIT = 3'd2;    // Wait for the first compression result.
    localparam S_SECOND_START = 3'd3;  // Assert the second compression start pulse.
    localparam S_SECOND_WAIT = 3'd4;   // Wait for the final hash and check it against target.
    localparam S_REPORT = 3'd5;        // Hold the winning nonce/hash stable for reporting.

    reg [2:0] core_state = S_IDLE;
    reg compress_start = 1'b0;
    reg [255:0] compress_state_in;
    reg [511:0] compress_block;
    wire compress_busy;
    wire compress_done;
    wire [255:0] compress_state_out;

    reg [255:0] first_digest;
    reg [255:0] job_midstate;
    reg [95:0] job_tail;
    reg [255:0] job_target;
    reg [287:0] report_shift_reg;
    wire [255:0] final_hash_be = reverse_bytes_256(compress_state_out);

    sha256_compress sha (
        .clk(clk),
        .start(compress_start),
        .state_in(compress_state_in),
        .block(compress_block),
        .busy(compress_busy),
        .done(compress_done),
        .state_out(compress_state_out)
    );

    // First compression consumes tail || nonce as the last 16-word block of the Bitcoin header.
    wire [511:0] first_block = {
        job_tail[95:64], job_tail[63:32], job_tail[31:0], current_nonce,
        32'h80000000, 32'h00000000, 32'h00000000, 32'h00000000,
        32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000,
        32'h00000000, 32'h00000000, 32'h00000000, 32'h00000280
    };

    // Second compression hashes the first digest with standard SHA-256 padding for a 32-byte input.
    wire [511:0] second_block = {
        first_digest,
        32'h80000000, 32'h00000000, 32'h00000000, 32'h00000000,
        32'h00000000, 32'h00000000, 32'h00000000, 32'h00000100
    };

    function [255:0] reverse_bytes_256;
        input [255:0] value;
        integer i;
        begin
            for (i = 0; i < 32; i = i + 1) begin
                reverse_bytes_256[(31 - i) * 8 +: 8] = value[i * 8 +: 8];
            end
        end
    endfunction

    wire final_hash_meets_target;

    lt256 target_compare (
        .a(final_hash_be),
        .b(job_target),
        .lt(final_hash_meets_target)
    );

    wire [287:0] report_payload = {found_nonce, found_hash};

    assign report_byte_out = report_shift_reg[287:280];
    assign report_bit_out = report_select ? report_payload[9'd287 - report_bit_index] : 1'b0;

    always @(posedge clk) begin
        compress_start <= 1'b0;

        if (report_select && report_load) begin
            report_shift_reg <= report_payload;
        end else if (report_select && report_shift) begin
            report_shift_reg <= {report_shift_reg[279:0], 8'h00};
        end

        if (stop) begin
            core_state <= S_IDLE;
            running <= 1'b0;
        end else begin
            case (core_state)
                S_IDLE: begin
                    found <= 1'b0;
                    running <= 1'b0;
                    if (start) begin
                        job_midstate <= midstate;
                        job_tail <= tail;
                        job_target <= target;
                        current_nonce <= START_NONCE;
                        running <= 1'b1;
                        core_state <= S_FIRST_START;
                    end
                end

                S_FIRST_START: begin
                    if (!compress_busy) begin
                        compress_state_in <= job_midstate;
                        compress_block <= first_block;
                        compress_start <= 1'b1;
                        core_state <= S_FIRST_WAIT;
                    end
                end

                S_FIRST_WAIT: begin
                    if (compress_done) begin
                        first_digest <= compress_state_out;
                        core_state <= S_SECOND_START;
                    end
                end

                S_SECOND_START: begin
                    if (!compress_busy) begin
                        compress_state_in <= SHA256_IV;
                        compress_block <= second_block;
                        compress_start <= 1'b1;
                        core_state <= S_SECOND_WAIT;
                    end
                end

                S_SECOND_WAIT: begin
                    if (compress_done) begin
                        found_nonce <= current_nonce;
                        found_hash <= compress_state_out;
                        if (final_hash_meets_target) begin
                            found <= 1'b1;
                            core_state <= S_REPORT;
                        end else begin
                            current_nonce <= current_nonce + NONCE_STRIDE;
                            core_state <= S_FIRST_START;
                        end
                    end
                end

                S_REPORT: begin
                    running <= 1'b0;
                    if (start) begin
                        found <= 1'b0;
                        job_midstate <= midstate;
                        job_tail <= tail;
                        job_target <= target;
                        current_nonce <= START_NONCE;
                        running <= 1'b1;
                        core_state <= S_FIRST_START;
                    end
                end

                default: begin
                    core_state <= S_IDLE;
                    running <= 1'b0;
                end
            endcase
        end
    end
endmodule
