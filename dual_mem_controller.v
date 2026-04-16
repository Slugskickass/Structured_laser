// =============================================================================
// dual_mem_controller.v — Dual-channel Waveform Look-Up Table (LUT)
// Loads two independent 1024-entry waveform tables and outputs samples in parallel.
// =============================================================================

module dual_mem_controller (
    input  wire        clk,
    input  wire [9:0]  addr,        // 10-bit address allows indexing 1024 samples (2^10)
    output reg  [11:0] data_out_a,  // 12-bit sample output for Channel A (Triangle)
    output reg  [11:0] data_out_b   // 12-bit sample output for Channel B (Square)
);

    // Memory arrays: 1024 rows deep, 16 bits wide [cite: 96]
    // Note: Though the output is 12-bit, the memory is defined as 16-bit to match .hex files if needed.
    reg [15:0] mem_a [0:1023]; 
    reg [15:0] mem_b [0:1023];

    // Initialize memory during FPGA configuration [cite: 96]
    initial begin
        // Loads hexadecimal values from external files into the memory arrays
        $readmemh("triangle.hex", mem_a); // Populates Channel A LUT [cite: 96]
        $readmemh("square.hex",  mem_b);  // Populates Channel B LUT [cite: 97]
    end

    // Synchronous Read: BRAM output is updated on every rising clock edge 
    always @(posedge clk) begin
        // Slice the 16-bit memory word to return only the lower 12 bits to the DAC 
        data_out_a <= mem_a[addr][11:0];
        data_out_b <= mem_b[addr][11:0];
    end

endmodule


// module dual_mem_controller (
//     input  wire        clk,
//     input  wire [9:0]  addr,
//     output reg  [11:0] data_out_a,
//     output reg  [11:0] data_out_b
// );
//     reg [15:0] mem_a [0:1023];
//     reg [15:0] mem_b [0:1023];

//     initial begin
//         $readmemh("triangle.hex", mem_a);
//         $readmemh("square.hex",  mem_b); //Square wave for channel B
//     end

//     always @(posedge clk) begin
//         data_out_a <= mem_a[addr][11:0];
//         data_out_b <= mem_b[addr][11:0];
//     end

// endmodule