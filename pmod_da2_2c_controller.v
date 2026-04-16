// =============================================================================
// pmod_da2_dual_controller.v — Dual SPI driver for PMOD DA2
// Supports both Channel A and Channel B outputs simultaneously.
// =============================================================================

module pmod_da2_2c_controller (
    input        CLK,         // System clock input
    input [15:0] data_a,      // 16-bit input word for Channel A (DAC 1)
    input [15:0] data_b,      // 16-bit input word for Channel B (DAC 2)
    output       pmod_cs_n,   // Active-low Chip Select
    output       pmod_mosi1,  // Master-Out-Slave-In data for DAC 1 
    output       pmod_mosi2,  // Master-Out-Slave-In data for DAC 2 
    output       pmod_sclk    // SPI Serial Clock 
);

// Clock divider parameter: SCLK frequency = CLK / (2^(D+1) * 2) = CLK / 32 
localparam D = 3; 

// 8-bit free-running counter to manage the SPI timing frame
reg [7:0] counter = 0;
always @(posedge CLK)
    counter <= counter + 1; 

// CS_N Logic: De-assert (High) for the last 4 cycles of the 256-cycle frame.
// This provides the necessary "quiet time" between SPI transmissions. 
assign pmod_cs_n = (counter >= 8'hFC) ? 1'b1 : 1'b0;

// SCLK Logic: Toggles based on bit D of the counter, but only while CS is active (Low). 
assign pmod_sclk = (~pmod_cs_n) & counter[D]; 

// Dual Shift Registers to hold and serialize the data 
reg [15:0] shreg_a = 16'd0;
reg [15:0] shreg_b = 16'd0;
reg sclk_prev      = 1'b0; // Used for edge detection 
reg cs_prev        = 1'b1; // Used for edge detection 

// Synchronous process to track previous states of SCLK and CS 
always @(posedge CLK) begin
    sclk_prev <= pmod_sclk; 
    cs_prev   <= pmod_cs_n; 
end

// Detect the rising edge of SCLK and the falling edge (start) of the CS frame 
wire sclk_rise   = ~sclk_prev & pmod_sclk; 
wire frame_start = cs_prev & ~pmod_cs_n;

// Shift Register Control Logic
always @(posedge CLK) begin
    if (frame_start) begin
        // At the start of a frame, load the parallel input data into registers 
        shreg_a <= data_a;
        shreg_b <= data_b;
    end else if (sclk_rise) begin
        // On every SPI clock rising edge, shift the bits left by one 
        shreg_a <= {shreg_a[14:0], 1'b0};
        shreg_b <= {shreg_b[14:0], 1'b0};
    end
end

// Output the Most Significant Bit (MSB) of the registers to the MOSI pins 
assign pmod_mosi1 = shreg_a[15]; 
assign pmod_mosi2 = shreg_b[15];

endmodule

// // =============================================================================
// // pmod_da2_dual_controller.v — Dual SPI driver for PMOD DA2
// // Supports both Channel A and Channel B outputs simultaneously.
// // =============================================================================

// module pmod_da2_2c_controller (
//     input        CLK,
//     input [15:0] data_a,    // Input for Channel A
//     input [15:0] data_b,    // Input for Channel B
//     output       pmod_cs_n,
//     output       pmod_mosi1,  // Data out to DAC 1
//     output       pmod_mosi2,  // Data out to DAC 2
//     output       pmod_sclk
// );

// localparam D = 3; // SCLK = CLK/32 

// reg [7:0] counter = 0;
// always @(posedge CLK)
//     counter <= counter + 1; //

// // CS_N high for last 4 cycles of the 256-cycle frame 
// assign pmod_cs_n = (counter >= 8'hFC) ? 1'b1 : 1'b0; //

// // SCLK toggles while CS is active 
// assign pmod_sclk = (~pmod_cs_n) & counter[D]; //

// // Dual Shift Registers
// reg [15:0] shreg_a = 16'd0;
// reg [15:0] shreg_b = 16'd0;
// reg sclk_prev      = 1'b0;
// reg cs_prev        = 1'b1;

// always @(posedge CLK) begin
//     sclk_prev <= pmod_sclk; 
//     cs_prev   <= pmod_cs_n; 
// end

// wire sclk_rise   = ~sclk_prev & pmod_sclk; 
// wire frame_start = cs_prev & ~pmod_cs_n;   

// always @(posedge CLK) begin
//     if (frame_start) begin
//         shreg_a <= data_a; // Load Channel A 
//         shreg_b <= data_b; // Load Channel B
//     end else if (sclk_rise) begin
//         shreg_a <= {shreg_a[14:0], 1'b0}; 
//         shreg_b <= {shreg_b[14:0], 1'b0};
//     end
// end

// // Assign MSB of each shift register to the respective MOSI pins
// assign pmod_mosi1 = shreg_a[15]; 
// assign pmod_mosi2 = shreg_b[15];

// endmodule