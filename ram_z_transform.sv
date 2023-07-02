module ram_z_transfrom
#(
	parameter DATA_WIDTH = 16,
	parameter Z_LENGTH = 70
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
	input logic axis_out_tready
);
	

// Data pointer
logic [$clog2(Z_LENGTH) - 1:0]input_data_pointer;
logic [$clog2(Z_LENGTH) - 1:0]output_data_pointer;

// AXI stream signal
wire axis_in_data_wen = axis_in_tvalid && axis_in_tready; // When AXI Stream ready & valid, write enable
	
// Shift-RAM
xpm_memory_sdpram 
#(
	.ADDR_WIDTH_A($clog2(Z_LENGTH)),
	.ADDR_WIDTH_B($clog2(Z_LENGTH)),
	.MEMORY_INIT_FILE("none"),
	.MEMORY_PRIMITIVE("auto"),
	.READ_DATA_WIDTH_B(DATA_WIDTH),
	.READ_LATENCY_B(1),
	.WRITE_DATA_WIDTH_A(DATA_WIDTH),
	.WRITE_MODE_B("no_change"),
	.MEMORY_SIZE(Z_LENGTH * DATA_WIDTH)
)shift_ram
(
	.addra(input_data_pointer), // Pointer for write
	.addrb(output_data_pointer),
	.clka(clk),
	.clkb(clk),
	.dina(axis_in_tdata), // Input data directly to RAM
	.doutb(axis_out_tdata),
	.ena(axis_in_data_wen),
	.enb(1'b1),
	.regceb(1'b1),
	.rstb(~areset_n),
	.wea({$clog2(Z_LENGTH){1'b1}}),

	// Unused pins
	.dbiterrb(),
	.sbiterrb(),
	.injectdbiterra(),
	.injectsbiterra(),
	.sleep()
);

// AXI stream ready
always_ff @(posedge clk, negedge areset_n) begin : axis_in_ready
	if (!areset_n) axis_in_tready <= 1'b0;	
	else begin
		if (axis_in_tvalid) begin
			axis_in_tready <= 1'b1;
		end
	end
end

// Input pointer
always_ff @(posedge clk, negedge areset_n) begin : input_pointer
	if (!areset_n) begin
		input_data_pointer <= 'b0;
	end	
	else begin
		if (axis_in_data_wen) begin
			if (input_data_pointer == Z_LENGTH - 1) begin
				input_data_pointer <= 'b0;
			end
			else begin
				input_data_pointer <= input_data_pointer + 1'b1;
			end
		end
	end
end

// Output pointer
always_ff @(posedge clk, negedge areset_n) begin : output_pointer
	if (!areset_n) begin
		output_data_pointer <= 'b1;
	end	
	else begin
		if (axis_in_data_wen) begin
			if (output_data_pointer == Z_LENGTH - 1) begin
				output_data_pointer <= 'b0;
			end
			else begin
				output_data_pointer <= output_data_pointer + 1'b1;
			end
		end
	end
end

// Output control
always_ff @(posedge clk, negedge areset_n) begin : output_ctrl
	if (!areset_n) begin
		axis_out_tvalid <= 1'b0;
	end	
	else begin
		if (axis_in_data_wen) begin // Output a data when new data stream into the shift RAM
			axis_out_tvalid <= 1'b1;
		end

		if (axis_out_tvalid && axis_out_tready) begin // When slave accept, end the transmission
			axis_out_tvalid <= 1'b0;
		end
	end
end

endmodule