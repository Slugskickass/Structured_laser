// =============================================================================
// top.v — streams 1024-entry LUT to PMOD DA2, looping forever.
//
// Pipeline:
//   frame_end (CS rises, cycle 0):  addr increments
//   cycle 1:                        addr_d1 settles (registered, glitch-free)
//   cycle 1 also:                   frame_end_d1 fires
//   cycle 2:                        BRAM outputs lut_data for addr_d1
//                                   dac_word_reg latches lut_data (frame_end_d2)
//   frame_start (CS falls):         DAC shift register loads dac_word_reg
//
// The extra addr_d1 stage ensures the BRAM always sees a fully settled address,
// avoiding the race where addr increments and is read in the same clock edge.
// With a 4-cycle CS-high window (counters 252-255) there is sufficient margin.
// =============================================================================

module top (
    input  wire clk,

    output wire pmod_cs_n,
    output wire pmod_mosi,
    output wire pmod_mosi_b,
    output wire pmod_sclk,
    output wire pmod_clockout
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
    always @(posedge clk)
        cs_prev <= pmod_cs_n;

    wire frame_end = ~cs_prev & pmod_cs_n;  // CS_N 0→1

    // -------------------------------------------------------------------------
    // Step 1: advance address at frame_end
    // Step 2: register address so BRAM sees a fully settled value
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
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
        .clk      (clk),
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
    always @(posedge clk) begin
        frame_end_d1 <= frame_end;
        frame_end_d2 <= frame_end_d1;
    end

    reg [15:0] dac_word_reg = 16'd0;
    reg [15:0] dac_word_square = 16'd0;

    always @(posedge clk)
        if (frame_end_d2) begin
            // dac_word_reg <= {2'b00, lut_data[11:0], 2'b00}; //wrong
            //dac_word_reg <= {lut_data[11:0], 4'b0000};
            dac_word_reg <= {4'b0000, lut_data[11:0]};
            dac_word_square <= {4'b0000, squ_data[11:0]};
        end
            
            //dac_word_square <= {4'b0000, squ_data[11:0]};
            //dac_word_reg <= 16'b0000001111000000;
    // -------------------------------------------------------------------------
    // DAC SPI controller
    // -------------------------------------------------------------------------
    //pmod_da2_controller u_dac (
    //    .CLK       (clk),
    //    .data      (dac_word_reg),
    //    .pmod_cs_n (pmod_cs_n),
    //    .pmod_mosi (pmod_mosi),
    //    .pmod_sclk (pmod_sclk),
    //    .clockout  (pmod_clockout)
    //);
    pmod_da2_2c_controller u_dual_dac (
        .CLK       (clk),
        .data_a    (dac_word_reg),
        .data_b    (dac_word_square),
        .pmod_cs_n (pmod_cs_n),
        .pmod_mosi1 (pmod_mosi),
        .pmod_mosi2 (pmod_mosi_b),
        .pmod_sclk (pmod_sclk)
    );

endmodule