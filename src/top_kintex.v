`default_nettype wire

module top_kintex #(
    parameter CLK_FREQ = 210000000,
    parameter INPUT_CLK_FREQ = 50000000,
    parameter BAUD_RATE = 115200,
    parameter CORES = 1
)(
    input clk,
    input uart_rx_pin,
    output uart_tx_pin,
    output [3:0] led
);
    // Keep the MMCM VCO in a valid Kintex-7 range, then derive the ratios
    // from the requested input and system clock frequencies.
    localparam real MMCM_VCO_FREQ = 1050000000.0;
    wire clk_fb_mmcm;
    wire clk_fb_bufg;
    wire clk_mmcm;
    wire mmcm_locked;
    wire clk_mmcm_bufg;

    MMCME2_BASE #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKIN1_PERIOD(1000000000.0 / INPUT_CLK_FREQ),
        .DIVCLK_DIVIDE(1),
        .CLKFBOUT_MULT_F(MMCM_VCO_FREQ / INPUT_CLK_FREQ),
        .CLKOUT0_DIVIDE_F(MMCM_VCO_FREQ / CLK_FREQ),
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

    BUFG bufg_sys_clk (
        .I(clk_mmcm),
        .O(clk_mmcm_bufg)
    );

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
endmodule
