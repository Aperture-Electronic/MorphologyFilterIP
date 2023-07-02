module morphology_filter
#
(
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
	input logic signed [KERNEL_DATA_WIDTH - 1:0]up_op_ero_kernel_lut_data,
	output logic [$clog2(KERNEL_WIDTH) - 1:0]up_op_ero_kernel_lut_address,
	input logic signed [KERNEL_DATA_WIDTH - 1:0]up_op_dila_kernel_lut_data,
	output logic [$clog2(KERNEL_WIDTH) - 1:0]up_op_dila_kernel_lut_address,

	input logic signed [KERNEL_DATA_WIDTH - 1:0]up_cl_ero_kernel_lut_data,
	output logic [$clog2(KERNEL_WIDTH) - 1:0]up_cl_ero_kernel_lut_address,
	input logic signed [KERNEL_DATA_WIDTH - 1:0]up_cl_dila_kernel_lut_data,
	output logic [$clog2(KERNEL_WIDTH) - 1:0]up_cl_dila_kernel_lut_address,

	input logic signed [KERNEL_DATA_WIDTH - 1:0]lo_op_ero_kernel_lut_data,
	output logic [$clog2(KERNEL_WIDTH) - 1:0]lo_op_ero_kernel_lut_address,
	input logic signed [KERNEL_DATA_WIDTH - 1:0]lo_op_dila_kernel_lut_data,
	output logic [$clog2(KERNEL_WIDTH) - 1:0]lo_op_dila_kernel_lut_address,

	input logic signed [KERNEL_DATA_WIDTH - 1:0]lo_cl_ero_kernel_lut_data,
	output logic [$clog2(KERNEL_WIDTH) - 1:0]lo_cl_ero_kernel_lut_address,
	input logic signed [KERNEL_DATA_WIDTH - 1:0]lo_cl_dila_kernel_lut_data,
	output logic [$clog2(KERNEL_WIDTH) - 1:0]lo_cl_dila_kernel_lut_address
);

// System structure
// Input-----------[z^-N]---------->[-]--> Result
//   |---->[Morphology Baseline]---->|

logic signed [DATA_WIDTH - 1:0]axis_zdelay_tdata;
logic axis_zdelay_tvalid;

// Signal Z-transform delay module
ram_z_transfrom #(
	.DATA_WIDTH(DATA_WIDTH),
	.Z_LENGTH(KERNEL_WIDTH * 2 - 2)
)input_z_delay
(
	.*,
	.axis_in_tready(),

	.axis_out_tdata(axis_zdelay_tdata),
	.axis_out_tvalid(axis_zdelay_tvalid),
	.axis_out_tready(1'b1)
);

logic signed [DATA_WIDTH - 1:0] zdelay_buffer;

always_ff @(posedge clk, negedge areset_n) begin
	if (!areset_n) zdelay_buffer <= 'b0;
	else if (axis_zdelay_tvalid) zdelay_buffer <= axis_zdelay_tdata;
end


// Morphology baseline
logic signed [DATA_WIDTH - 1:0]axis_upper_tdata;
logic axis_upper_tvalid;
logic signed [DATA_WIDTH - 1:0]axis_lower_tdata;
logic axis_lower_tvalid;

//	Upper
upper #(
	.DATA_WIDTH(DATA_WIDTH),
	.KERNEL_WIDTH(KERNEL_WIDTH),
	.KERNEL_DATA_WIDTH(KERNEL_DATA_WIDTH),
	.INTERNAL_WIDTH(INTERNAL_WIDTH)
)baseline_upper
(
	.*,
	.axis_in_tready(),

	.axis_out_tdata(axis_upper_tdata),
	.axis_out_tvalid(axis_upper_tvalid),
	.axis_out_tready(1'b1),

	.cl_dila_kernel_lut_data(up_cl_dila_kernel_lut_data),
	.cl_ero_kernel_lut_data(up_cl_ero_kernel_lut_data),
	.op_dila_kernel_lut_data(up_op_dila_kernel_lut_data),
	.op_ero_kernel_lut_data(up_op_ero_kernel_lut_data),

	.cl_dila_kernel_lut_address(up_cl_dila_kernel_lut_address),
	.cl_ero_kernel_lut_address(up_cl_ero_kernel_lut_address),
	.op_dila_kernel_lut_address(up_op_dila_kernel_lut_address),
	.op_ero_kernel_lut_address(up_op_ero_kernel_lut_address)
);

//	Lower
lower #(
	.DATA_WIDTH(DATA_WIDTH),
	.KERNEL_WIDTH(KERNEL_WIDTH),
	.KERNEL_DATA_WIDTH(KERNEL_DATA_WIDTH),
	.INTERNAL_WIDTH(INTERNAL_WIDTH)
)baseline_lower
(
	.*,
	.axis_in_tready(axis_in_tready),

	.axis_out_tdata(axis_lower_tdata),
	.axis_out_tvalid(axis_lower_tvalid),
	.axis_out_tready(1'b1),

	.cl_dila_kernel_lut_data(lo_cl_dila_kernel_lut_data),
	.cl_ero_kernel_lut_data(lo_cl_ero_kernel_lut_data),
	.op_dila_kernel_lut_data(lo_op_dila_kernel_lut_data),
	.op_ero_kernel_lut_data(lo_op_ero_kernel_lut_data),

	.cl_dila_kernel_lut_address(lo_cl_dila_kernel_lut_address),
	.cl_ero_kernel_lut_address(lo_cl_ero_kernel_lut_address),
	.op_dila_kernel_lut_address(lo_op_dila_kernel_lut_address),
	.op_ero_kernel_lut_address(lo_op_ero_kernel_lut_address)
);

// Average and buffer
logic signed [DATA_WIDTH - 1:0]uplo_average_buffer;

always_ff @(posedge clk, negedge areset_n) begin
	if (!areset_n) uplo_average_buffer <= 'b0;
	else if (axis_upper_tvalid && axis_lower_tvalid) begin
		uplo_average_buffer <= {{{DATA_WIDTH+1}{1'b1}}} & ((axis_upper_tdata + axis_lower_tdata) >> 1); // Avg = (Up + Lo) / 2
	end
end

// Minus
logic signed [DATA_WIDTH - 1:0]minus_buffer;

always_ff @(posedge clk, negedge areset_n) begin
	if (!areset_n) minus_buffer <= 'b0;
	else minus_buffer <= zdelay_buffer - uplo_average_buffer;
end

// Internal buffer valid
logic [2:0]internal_buffer_valid;

always_ff @(posedge clk, negedge areset_n) begin
	if (!areset_n) internal_buffer_valid <= 3'b0;
	else begin
		internal_buffer_valid <= {internal_buffer_valid[1:0], (axis_upper_tvalid && axis_lower_tvalid)};
	end
end

// Output buffer
always_ff @(posedge clk, negedge areset_n) begin
	if (!areset_n) axis_out_tdata <= 'b0;
	else begin
		if (internal_buffer_valid) begin
			axis_out_tdata <= minus_buffer;
		end
	end
end

// Output buffer valid
always_ff @(posedge clk, negedge areset_n) begin
	if (!areset_n) axis_out_tvalid <= 1'b0;
	else begin
		if (internal_buffer_valid[2] && ~axis_out_tvalid) begin
			axis_out_tvalid <= 1'b1;
		end
		else if (axis_out_tready && axis_out_tvalid) begin
			axis_out_tvalid <= 1'b0;
		end
	end
end


endmodule