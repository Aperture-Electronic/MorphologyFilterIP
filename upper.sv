module upper
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
	input logic signed [KERNEL_DATA_WIDTH - 1:0]op_ero_kernel_lut_data,
	output logic [$clog2(KERNEL_WIDTH) - 1:0]op_ero_kernel_lut_address,
	input logic signed [KERNEL_DATA_WIDTH - 1:0]op_dila_kernel_lut_data,
	output logic [$clog2(KERNEL_WIDTH) - 1:0]op_dila_kernel_lut_address,

	input logic signed [KERNEL_DATA_WIDTH - 1:0]cl_ero_kernel_lut_data,
	output logic [$clog2(KERNEL_WIDTH) - 1:0]cl_ero_kernel_lut_address,
	input logic signed [KERNEL_DATA_WIDTH - 1:0]cl_dila_kernel_lut_data,
	output logic [$clog2(KERNEL_WIDTH) - 1:0]cl_dila_kernel_lut_address
);

// Upper(X, K) = Open(Close(X, K), K)
logic signed [DATA_WIDTH - 1:0]axis_cl_out_tdata;
logic axis_cl_out_tvalid;
logic axis_cl_out_tready;

close close
(	
	.*, 
	.axis_out_tdata(axis_cl_out_tdata),
	.axis_out_tvalid(axis_cl_out_tvalid),
	.axis_out_tready(axis_cl_out_tready),

	.ero_kernel_lut_data(cl_ero_kernel_lut_data),
	.ero_kernel_lut_address(cl_ero_kernel_lut_address),
	.dila_kernel_lut_data(cl_dila_kernel_lut_data),
	.dila_kernel_lut_address(cl_dila_kernel_lut_address)
);

open open
(
	.*,
	.axis_in_tdata(axis_cl_out_tdata),
	.axis_in_tvalid(axis_cl_out_tvalid),
	.axis_in_tready(axis_cl_out_tready),

	.ero_kernel_lut_data(op_ero_kernel_lut_data),
	.ero_kernel_lut_address(op_ero_kernel_lut_address),
	.dila_kernel_lut_data(op_dila_kernel_lut_data),
	.dila_kernel_lut_address(op_dila_kernel_lut_address)
);

endmodule
