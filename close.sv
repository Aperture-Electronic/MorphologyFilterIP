module close
#(
	parameter DATA_WIDTH = 16,
	parameter KERNEL_WIDTH = 71,
	parameter KERNEL_DATA_WIDTH = 8,
	parameter INTERNAL_WIDTH = 17
) 
(
	// Clock and reset
	input logic clk,
	input logic areset_n,
	
	// Data input
	input logic signed [DATA_WIDTH - 1:0]axis_in_tdata,
	input logic axis_in_tvalid,
	output logic axis_in_tready,
	
	// Data output
	output logic signed [DATA_WIDTH - 1:0]axis_out_tdata,
	output logic axis_out_tvalid,
	input logic axis_out_tready,
	
	// Kernel setting
	input logic signed [KERNEL_DATA_WIDTH - 1:0]ero_kernel_lut_data,
	output logic [$clog2(KERNEL_WIDTH) - 1:0]ero_kernel_lut_address,
	input logic signed [KERNEL_DATA_WIDTH - 1:0]dila_kernel_lut_data,
	output logic [$clog2(KERNEL_WIDTH) - 1:0]dila_kernel_lut_address
);
	
// Close(X, K) = Erosion(Dilation(X, K), K)
logic signed [DATA_WIDTH - 1:0]axis_dial_out_tdata;
logic axis_dial_out_tvalid;
logic axis_dial_out_tready;

dilation dialtion
(	
	.*, 
	.axis_out_tdata(axis_dial_out_tdata),
	.axis_out_tvalid(axis_dial_out_tvalid),
	.axis_out_tready(axis_dial_out_tready),

	.kernel_lut_data(ero_kernel_lut_data),
	.kernel_lut_address(ero_kernel_lut_address)
);

erosion erosion
(
	.*,
	.axis_in_tdata(axis_dial_out_tdata),
	.axis_in_tvalid(axis_dial_out_tvalid),
	.axis_in_tready(axis_dial_out_tready),

	.kernel_lut_data(dila_kernel_lut_data),
	.kernel_lut_address(dila_kernel_lut_address)
);

endmodule