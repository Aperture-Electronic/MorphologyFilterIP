// System verilog file
// Add with truncate

module add_truncate
#(
	parameter DATA_WIDTH_A = 16,
	parameter DATA_WIDTH_B = 16,
	parameter INTERNAL_WIDTH = 17,
	parameter DATA_WIDTH_Y = 16
)
(
	input logic signed [DATA_WIDTH_A - 1:0]A,
	input logic signed [DATA_WIDTH_B - 1:0]B,
	output logic signed [DATA_WIDTH_Y - 1:0]Y
);

logic signed [INTERNAL_WIDTH - 1:0]internal;
assign internal = A + B;

always_comb begin
	case (internal[INTERNAL_WIDTH - 1:INTERNAL_WIDTH - 2])
		2'b01: Y = {1'b0, {(DATA_WIDTH_Y - 1){1'b1}}}; 
		2'b10: Y = {1'b1, {(DATA_WIDTH_Y - 1){1'b0}}};
		default: Y = internal[DATA_WIDTH_Y - 1:0];
	endcase
end

endmodule
