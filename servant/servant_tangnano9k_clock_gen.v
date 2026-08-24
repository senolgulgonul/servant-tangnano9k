`default_nettype none
//
// Clock and reset generation for the Servant SoC on the Sipeed Tang Nano 9K
// (Gowin GW1NR-LV9QN88PC6/I5, GW1N-9C family).
//
// The board has a 27 MHz crystal. Servant's Zephyr UART is bit-banged and is
// calibrated for a 32 MHz core clock at 115200 baud. 32 MHz cannot be reached
// from 27 MHz with a legal phase detector frequency: 32/27 is already in
// lowest terms, so it would require IDIV_SEL=26 giving a 1 MHz PFD, below the
// 3 MHz minimum. The closest legal ratio is 6/5, giving 32.4 MHz.
//
//   PFD  = 27.0 / 5  =  5.4 MHz   (legal range 3 - 400 MHz)
//   VCO  = 32.4 * 32 = 1036.8 MHz (legal range 400 - 1200 MHz)
//   CLK  = 27.0 * 6 / 5 = 32.4 MHz
//
// 32.4 MHz gives an effective baud rate of 116640 instead of 115200, a +1.25%
// error. That is comfortably inside the tolerance of an 8N1 UART frame.
//
module servant_tangnano9k_clock_gen
  (input wire  i_clk,      // 27 MHz board oscillator
   input wire  i_rst_n,    // active low external reset (button S1)
   output wire o_clk,      // 32.4 MHz core clock
   output wire o_rst);     // active high synchronous reset

   wire        pll_clk;
   wire        pll_lock;

   rPLL
     #(.FCLKIN     ("27.0"),
       .IDIV_SEL   (4),      // divide by 5
       .FBDIV_SEL  (5),      // multiply by 6
       .ODIV_SEL   (32),     // VCO = 1036.8 MHz
       .DYN_SDIV_SEL (2),
       .PSDA_SEL   ("0000"),
       .DUTYDA_SEL ("1000"),
       .DYN_DA_EN  ("false"),
       .CLKOUT_FT_DIR (1'b1),
       .CLKOUTP_FT_DIR (1'b1),
       .CLKOUT_DLY_STEP (0),
       .CLKOUTP_DLY_STEP (0),
       .CLKFB_SEL  ("internal"),
       .CLKOUT_BYPASS ("false"),
       .CLKOUTP_BYPASS ("false"),
       .CLKOUTD_BYPASS ("false"),
       .CLKOUTD_SRC ("CLKOUT"),
       .CLKOUTD3_SRC ("CLKOUT"),
       .DEVICE     ("GW1NR-9C"))
   pll
     (.CLKIN    (i_clk),
      .CLKFB    (1'b0),
      .RESET    (1'b0),
      .RESET_P  (1'b0),
      .FBDSEL   (6'b0),
      .IDSEL    (6'b0),
      .ODSEL    (6'b0),
      .PSDA     (4'b0),
      .DUTYDA   (4'b0),
      .FDLY     (4'b0),
      .CLKOUT   (pll_clk),
      .LOCK     (pll_lock),
      .CLKOUTP  (),
      .CLKOUTD  (),
      .CLKOUTD3 ());

   assign o_clk = pll_clk;

   // Hold reset for 32 clocks after the PLL reports lock, and follow the
   // external reset button. Two flops synchronise the button into the PLL
   // clock domain.
   reg [1:0]   rst_n_sync;
   reg [5:0]   rst_cnt;

   always @(posedge pll_clk) begin
      rst_n_sync <= {rst_n_sync[0], i_rst_n};

      if (!rst_n_sync[1] || !pll_lock)
        rst_cnt <= 6'd0;
      else if (!rst_cnt[5])
        rst_cnt <= rst_cnt + 6'd1;
   end

   assign o_rst = !rst_cnt[5];

endmodule
`default_nettype wire
