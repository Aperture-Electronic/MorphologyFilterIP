module erosion
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
	input logic signed [KERNEL_DATA_WIDTH - 1:0]kernel_lut_data,
	output logic [$clog2(KERNEL_WIDTH) - 1:0]kernel_lut_address
);

// AXI stream signal
wire axis_in_data_wen = axis_in_tvalid && axis_in_tready; // When AXI Stream ready & valid, write enable

// Input data pointer
logic [$clog2(KERNEL_WIDTH) - 1:0]input_data_pointer;

// Current data pointer (for calculation)
logic [$clog2(KERNEL_WIDTH) - 1:0]current_data_pointer;

// Kernel moving
logic [$clog2(KERNEL_WIDTH) - 1:0]kernel_pointer;
assign kernel_lut_address = kernel_pointer; // Assign the LUT address to pointer

// Convert kernel pointer
// 0-------in---------M-1
// i: input pointer
// n: calc start pointer
// n -- M-1 length M - i + 1
// 0 -- i	length i + 1
logic [$clog2(KERNEL_WIDTH) - 1:0]calc_pointer;
always_comb begin : convert_kernel_pointer
	if (current_data_pointer + kernel_pointer >= KERNEL_WIDTH - 1) begin
		calc_pointer = kernel_pointer - (KERNEL_WIDTH - current_data_pointer) + 1;
	end
	else begin
		calc_pointer = current_data_pointer + kernel_pointer + 1;
	end
end

// Internal address & data wire
logic signed [DATA_WIDTH - 1:0]calc_data;

// Input data RAM
xpm_memory_sdpram 
#(
	.ADDR_WIDTH_A($clog2(KERNEL_WIDTH)),
	.ADDR_WIDTH_B($clog2(KERNEL_WIDTH)),
	.MEMORY_INIT_FILE("none"),
	.MEMORY_PRIMITIVE("auto"),
	.READ_DATA_WIDTH_B(DATA_WIDTH),
	.READ_LATENCY_B(1),
	.WRITE_DATA_WIDTH_A(DATA_WIDTH),
	.WRITE_MODE_B("no_change"),
	.MEMORY_SIZE(KERNEL_WIDTH * DATA_WIDTH)
)input_ram
(
	.addra(input_data_pointer), // Pointer for write
	.addrb(calc_pointer),
	.clka(clk),
	.clkb(clk),
	.dina(axis_in_tdata), // Input data directly to RAM
	.doutb(calc_data),
	.ena(axis_in_data_wen),
	.enb(1'b1),
	.regceb(1'b1),
	.rstb(~areset_n),
	.wea({$clog2(KERNEL_WIDTH){1'b1}}),

	// Unused pins
	.dbiterrb(),
	.sbiterrb(),
	.injectdbiterra(),
	.injectsbiterra(),
	.sleep()
);

// Input pointer control
always_ff @(posedge clk or negedge areset_n) begin : input_pointer_ctrl
	if (!areset_n) input_data_pointer <= 'b0;
	else if (axis_in_data_wen) begin
		if (input_data_pointer < KERNEL_WIDTH - 1) begin
			input_data_pointer <= input_data_pointer + 1'b1;
		end
		else begin
			input_data_pointer <= 'b0;
		end
	end
end

// State machine
typedef enum reg[3:0]
{
	MST_IDLE,
	MST_PREPARE,
	MST_CALC,
	MST_FINAL
}STATE;

STATE mst_state; // Master state machine
logic calc_done; // Calculate done

// The input AXI stream bus is only ready when system in idle status
assign axis_in_tready = mst_state == MST_IDLE;

// Current pointer control
always_ff @(posedge clk or negedge areset_n) begin : curr_pointer_ctrl
	if (!areset_n) current_data_pointer <= 'b0;
	else begin
		if ((mst_state == MST_IDLE) && (axis_in_tvalid)) begin
			current_data_pointer <= input_data_pointer;
		end
	end
end

// Master state machine control
always_ff @(posedge clk or negedge areset_n) begin : master_state_machine
	if (!areset_n) begin
		mst_state <= MST_IDLE; // Return to default state
	end
	else begin
		case (mst_state)
			MST_IDLE: begin
				if (axis_in_tvalid) begin // When new data coming
					mst_state <= MST_PREPARE; // Go to next state
				end
			end // MST_IDLE
			MST_PREPARE: begin
				mst_state <= MST_CALC;
			end // MST_PREPARE
			MST_CALC: begin
				if (calc_done) begin
					mst_state <= MST_FINAL; // Calculation done, entering final state
				end
			end // MST_CALC
			MST_FINAL: begin
				if (axis_out_tready && axis_out_tvalid) begin
					mst_state <= MST_IDLE; // Return to idle state
				end
			end // MST_FINAL
		endcase
	end
end

// Calculate done
always_ff @(posedge clk, negedge areset_n) begin : calc_done_ctrl
	if (!areset_n) begin
		calc_done <= 1'b0;
	end
	else begin
		case (mst_state)
			MST_IDLE, MST_PREPARE, MST_FINAL: calc_done <= 1'b0;
			MST_CALC: begin
				if (kernel_pointer == KERNEL_WIDTH - 1) begin
					calc_done <= 1'b1;
				end
			end
		endcase
	end
end

// Kernel pointer
always_ff @(posedge clk or negedge areset_n) begin : kernel_pointer_ctrl
	if (!areset_n) begin
		// Reset pointers
		kernel_pointer <= 'b0;
	end
	else begin
		case (mst_state)
			MST_IDLE: begin
				if (axis_in_tvalid) begin
					kernel_pointer <= 'b0;
				end
			end
			MST_PREPARE,
			MST_CALC: begin
				if (kernel_pointer < KERNEL_WIDTH - 1) begin
					kernel_pointer <= kernel_pointer + 1'b1;
				end
			end
			MST_FINAL: begin end // Nothing to do
		endcase
	end
end

// Calculation
logic signed [DATA_WIDTH - 1:0]compare_reg;
wire signed [DATA_WIDTH - 1:0]calc_result;

add_truncate #
(
	.DATA_WIDTH_A(DATA_WIDTH),
	.DATA_WIDTH_B(KERNEL_DATA_WIDTH),
	.INTERNAL_WIDTH(INTERNAL_WIDTH),
	.DATA_WIDTH_Y(DATA_WIDTH)
)calc_add
(
	.A(calc_data),
	.B(kernel_lut_data),
	.Y(calc_result)
);

always_ff @(posedge clk or negedge areset_n) begin : calculation
	if (!areset_n) begin
		compare_reg <= {1'b0, {(DATA_WIDTH - 1){1'b1}}}; // Give the maximun
	end
	else begin
		case (mst_state)
			MST_IDLE,
			MST_PREPARE: compare_reg <= {1'b0, {(DATA_WIDTH - 1){1'b1}}}; // Give the maximum
			MST_CALC, MST_FINAL: compare_reg <= (calc_result < compare_reg) ? calc_result : compare_reg; // Get the minimum
		endcase
	end
end

// Result output
always_ff @(posedge clk or negedge areset_n) begin : result_out
	if (!areset_n) begin
		axis_out_tdata <= 'b0;
	end
	else begin
		if (mst_state == MST_FINAL) begin
			axis_out_tdata <= compare_reg;
		end
	end
end

// Result valid
always_ff @(posedge clk or negedge areset_n) begin : result_valid
	if (!areset_n) begin
		axis_out_tvalid <= 'b0;	
	end
	else begin
		if (mst_state == MST_FINAL) begin
			if (axis_out_tready && axis_out_tvalid) begin
				axis_out_tvalid <= 'b0;
			end
			else begin
				axis_out_tvalid <= 'b1;
			end
		end
		else axis_out_tvalid <= 'b0;
	end
end

endmodule