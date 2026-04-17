// =============================================================================
// =============================================================================

module top (
    input  wire clk,

    output wire pmod_cs_n, 
    output wire pmod_mosi, // Channel One Data
    output wire pmod_mosi_b, // Channel Two Data
    output wire pmod_sclk,
    output wire pmod_clockout
);
    // ------------------
    // Testing clock divider
    // ------------------
    wire pll_clk;
    wire pll_locked;

SB_PLL40_PAD #(
    .FEEDBACK_PATH("SIMPLE"),
    .DIVR(4'b0000),
    .DIVF(7'b0111111),
    .DIVQ(3'b100),
    .FILTER_RANGE(3'b001)
) u_pll (
    .PACKAGEPIN    (clk),
    .PLLOUTGLOBAL  (pll_clk),
    .PLLOUTCORE    (),          // unused output — leave open
    .LOCK          (pll_locked),
    .RESETB        (1'b1),
    .BYPASS        (1'b0),
    .EXTFEEDBACK   (1'b0),      // unused input — tie low
    .DYNAMICDELAY  (8'b0),      // unused input — tie low
    .LATCHINPUTVALUE(1'b0),     // unused input — tie low
    .SDI           (1'b0),      // SPI config interface — unused
    .SCLK          (1'b0),
    .SDO           ()           // unused output — leave open
);



    // -------------------------------------------------------------------------
    // Address counter — 10-bit, wraps naturally at 1024
    // -------------------------------------------------------------------------
    reg [9:0] addr   = 10'd0;
    reg [9:0] addr_d1 = 10'd0;  // registered copy fed to BRAM

    // -------------------------------------------------------------------------
    // Detect CS rising edge (frame_end) from the DAC controller output
    // -------------------------------------------------------------------------
    reg cs_prev = 1'b1;
    always @(posedge pll_clk)
        cs_prev <= pmod_cs_n;

    wire frame_end = ~cs_prev & pmod_cs_n;  // CS_N 0→1

    // -------------------------------------------------------------------------
    // Step 1: advance address at frame_end
    // Step 2: register address so BRAM sees a fully settled value
    // -------------------------------------------------------------------------
    always @(posedge pll_clk) begin
        if (frame_end)
            addr <= addr + 10'd1;
        addr_d1 <= addr;
    end

    // -------------------------------------------------------------------------
    // Step 3: BRAM read — 1-cycle latency, lut_data valid the cycle after
    // -------------------------------------------------------------------------
    wire [11:0] lut_data;
    wire [11:0] squ_data;
   // mem_controller u_mem (
   //     .clk      (clk),
   //     .addr     (addr_d1),   // use registered address — no same-cycle race
   //     .data_out (lut_data)
   // );

    dual_mem_controller u_dual_mem (
        .clk      (pll_clk),
        .addr     (addr_d1),   // use registered address — no same-cycle
        .data_out_a (lut_data),
        .data_out_b (squ_data)
    );

    

    // -------------------------------------------------------------------------
    // Step 4: two-stage delay on frame_end to align with BRAM output latency
    //         frame_end_d1: addr_d1 has settled
    //         frame_end_d2: lut_data is valid → latch into dac_word_reg
    // -------------------------------------------------------------------------
    reg frame_end_d1 = 1'b0;
    reg frame_end_d2 = 1'b0;
    always @(posedge pll_clk) begin
        frame_end_d1 <= frame_end;
        frame_end_d2 <= frame_end_d1;
    end

    reg [15:0] dac_word_reg = 16'd0;
    reg [15:0] dac_word_square = 16'd0;

    always @(posedge pll_clk)
        if (frame_end_d2) begin
            // dac_word_reg <= {2'b00, lut_data[11:0], 2'b00}; //wrong
            //dac_word_reg <= {lut_data[11:0], 4'b0000};
            dac_word_reg <= {4'b0000, lut_data[11:0]};
            dac_word_square <= {4'b0000, squ_data[11:0]};
        end
            

    pmod_da2_2c_controller u_dual_dac (
        .CLK       (pll_clk),
        .data_a    (dac_word_reg),
        .data_b    (dac_word_square),
        .pmod_cs_n (pmod_cs_n),
        .pmod_mosi1 (pmod_mosi),
        .pmod_mosi2 (pmod_mosi_b),
        .pmod_sclk (pmod_sclk)
    );

endmodule