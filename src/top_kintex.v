`default_nettype wire

module top_kintex #(
    parameter CLK_FREQ = 210000000,
    parameter INPUT_CLK_FREQ = 50000000,
    parameter BAUD_RATE = 115200,
    parameter CORES = 1,
    parameter UART_DIAGNOSTIC = 0
)(
    input clk,
    input uart_rx_pin,
    output uart_tx_pin,
    output [3:0] led
);
    wire clk_fb_mmcm;
    wire clk_fb_bufg;
    wire clk_mmcm;
    wire mmcm_locked;
    wire clk_mmcm_bufg;

    MMCME2_BASE #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKIN1_PERIOD(1000000000.0 / INPUT_CLK_FREQ),
        .DIVCLK_DIVIDE(1),
        .CLKFBOUT_MULT_F(21.0),
        .CLKOUT0_DIVIDE_F(5.0),
        .CLKOUT0_DUTY_CYCLE(0.5),
        .CLKOUT0_PHASE(0.0),
        .CLKOUT1_DIVIDE(1),
        .CLKOUT2_DIVIDE(1),
        .CLKOUT3_DIVIDE(1),
        .CLKOUT4_DIVIDE(1),
        .CLKOUT5_DIVIDE(1),
        .CLKOUT6_DIVIDE(1),
        .REF_JITTER1(0.010),
        .STARTUP_WAIT("FALSE")
    ) mmcm_i (
        .CLKIN1(clk),
        .CLKFBIN(clk_fb_bufg),
        .RST(1'b0),
        .PWRDWN(1'b0),
        .CLKFBOUT(clk_fb_mmcm),
        .CLKFBOUTB(),
        .CLKOUT0(clk_mmcm),
        .CLKOUT0B(),
        .CLKOUT1(),
        .CLKOUT1B(),
        .CLKOUT2(),
        .CLKOUT2B(),
        .CLKOUT3(),
        .CLKOUT3B(),
        .CLKOUT4(),
        .CLKOUT5(),
        .CLKOUT6(),
        .LOCKED(mmcm_locked)
    );

    BUFG bufg_feedback (
        .I(clk_fb_mmcm),
        .O(clk_fb_bufg)
    );

    BUFGCE bufg_sys_clk (
        .I(clk_mmcm),
        .CE(mmcm_locked),
        .O(clk_mmcm_bufg)
    );

    generate
        if (UART_DIAGNOSTIC != 0) begin : gen_uart_diagnostic
            assign uart_tx_pin = uart_rx_pin;
            assign led = 4'b1111;
        end else begin : gen_miner
            top #(
                .CLK_FREQ(CLK_FREQ),
                .BAUD_RATE(BAUD_RATE),
                .CORES(CORES)
            ) top_i (
                .clk(clk_mmcm_bufg),
                .uart_rx_pin(uart_rx_pin),
                .uart_tx_pin(uart_tx_pin),
                .led(led)
            );
        end
    endgenerate
endmodule
