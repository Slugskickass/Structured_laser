// =============================================================================
// pmod_da2_dual_controller.v — Dual SPI driver for PMOD DA2
// Supports both Channel A and Channel B outputs simultaneously.
// =============================================================================

module pmod_da2_2c_controller (
    input        CLK,
    input [15:0] data_a,    // Input for Channel A
    input [15:0] data_b,    // Input for Channel B
    output       pmod_cs_n,
    output       pmod_mosi1,  // Data out to DAC 1
    output       pmod_mosi2,  // Data out to DAC 2
    output       pmod_sclk
);

localparam D = 3; // SCLK = CLK/32 [cite: 3]

reg [7:0] counter = 0;
always @(posedge CLK)
    counter <= counter + 1; //[cite: 4]

// CS_N high for last 4 cycles of the 256-cycle frame [cite: 5]
assign pmod_cs_n = (counter >= 8'hFC) ? 1'b1 : 1'b0; //[cite: 5]

// SCLK toggles while CS is active [cite: 6]
assign pmod_sclk = (~pmod_cs_n) & counter[D]; //[cite: 6]

// Dual Shift Registers
reg [15:0] shreg_a = 16'd0;
reg [15:0] shreg_b = 16'd0;
reg sclk_prev      = 1'b0;
reg cs_prev        = 1'b1;

always @(posedge CLK) begin
    sclk_prev <= pmod_sclk; //[cite: 9]
    cs_prev   <= pmod_cs_n; //[cite: 9]
end

wire sclk_rise   = ~sclk_prev & pmod_sclk; //[cite: 10]
wire frame_start = cs_prev & ~pmod_cs_n;   //[cite: 10]

always @(posedge CLK) begin
    if (frame_start) begin
        shreg_a <= data_a; // Load Channel A [cite: 11]
        shreg_b <= data_b; // Load Channel B
    end else if (sclk_rise) begin
        shreg_a <= {shreg_a[14:0], 1'b0}; //[cite: 12]
        shreg_b <= {shreg_b[14:0], 1'b0};
    end
end

// Assign MSB of each shift register to the respective MOSI pins
assign pmod_mosi1 = shreg_a[15]; //[cite: 12]
assign pmod_mosi2 = shreg_b[15];

endmodule