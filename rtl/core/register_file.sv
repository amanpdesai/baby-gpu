module register_file #(
    parameter int ADDR_W = 32,
    parameter int DATA_W = 32,
    parameter int COORD_W = 16,
    parameter int FB_WIDTH_DEFAULT = 160,
    parameter int FB_HEIGHT_DEFAULT = 120
) (
    input logic clk,
    input logic reset,

    input logic write_valid,
    input logic [ADDR_W-1:0] write_addr,
    input logic [DATA_W-1:0] write_data,

    input logic read_valid,
    input logic [ADDR_W-1:0] read_addr,
    output logic [DATA_W-1:0] read_data,

    input logic status_busy,
    input logic [7:0] status_errors,

    output logic core_enable,
    output logic soft_reset_pulse,
    output logic clear_errors_pulse,
    output logic test_pattern_enable,
    output logic [ADDR_W-1:0] fb_base,
    output logic [COORD_W-1:0] fb_width,
    output logic [COORD_W-1:0] fb_height,
    output logic [1:0] fb_format
);
  localparam logic [ADDR_W-1:0] ADDR_GPU_ID = 32'h0000_0000;
  localparam logic [ADDR_W-1:0] ADDR_GPU_VERSION = 32'h0000_0004;
  localparam logic [ADDR_W-1:0] ADDR_STATUS = 32'h0000_0008;
  localparam logic [ADDR_W-1:0] ADDR_CONTROL = 32'h0000_000C;
  localparam logic [ADDR_W-1:0] ADDR_FB_BASE = 32'h0000_0010;
  localparam logic [ADDR_W-1:0] ADDR_FB_WIDTH = 32'h0000_0014;
  localparam logic [ADDR_W-1:0] ADDR_FB_HEIGHT = 32'h0000_0018;
  localparam logic [ADDR_W-1:0] ADDR_FB_FORMAT = 32'h0000_001C;
  localparam logic [ADDR_W-1:0] ADDR_INTERRUPT_STATUS = 32'h0000_0024;
  localparam logic [ADDR_W-1:0] ADDR_INTERRUPT_ENABLE = 32'h0000_0028;
  localparam logic [ADDR_W-1:0] ADDR_BUSY = 32'h0000_002C;

  localparam logic [DATA_W-1:0] GPU_ID = 32'h4250_4755;
  localparam logic [DATA_W-1:0] GPU_VERSION = 32'h0001_0000;
  localparam logic [1:0] FB_FORMAT_RGB565 = 2'd1;

  logic [DATA_W-1:0] control_reg;
  logic [DATA_W-1:0] interrupt_status_reg;
  logic [DATA_W-1:0] interrupt_enable_reg;

  assign core_enable = control_reg[0];
  assign test_pattern_enable = control_reg[4];

  always_comb begin
    read_data = '0;

    if (read_valid) begin
      case (read_addr)
        ADDR_GPU_ID: read_data = GPU_ID;
        ADDR_GPU_VERSION: read_data = GPU_VERSION;
        ADDR_STATUS: read_data = {{(DATA_W - 9) {1'b0}}, status_errors, status_busy};
        ADDR_CONTROL: read_data = control_reg;
        ADDR_FB_BASE: read_data = fb_base;
        ADDR_FB_WIDTH: read_data = {{(DATA_W - COORD_W) {1'b0}}, fb_width};
        ADDR_FB_HEIGHT: read_data = {{(DATA_W - COORD_W) {1'b0}}, fb_height};
        ADDR_FB_FORMAT: read_data = {{(DATA_W - 2) {1'b0}}, fb_format};
        ADDR_INTERRUPT_STATUS: read_data = interrupt_status_reg;
        ADDR_INTERRUPT_ENABLE: read_data = interrupt_enable_reg;
        ADDR_BUSY: read_data = {{(DATA_W - 1) {1'b0}}, status_busy};
        default: read_data = '0;
      endcase
    end
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      control_reg <= '0;
      interrupt_status_reg <= '0;
      interrupt_enable_reg <= '0;
      fb_base <= '0;
      fb_width <= COORD_W'(FB_WIDTH_DEFAULT);
      fb_height <= COORD_W'(FB_HEIGHT_DEFAULT);
      fb_format <= FB_FORMAT_RGB565;
      soft_reset_pulse <= 1'b0;
      clear_errors_pulse <= 1'b0;
    end else begin
      soft_reset_pulse <= 1'b0;
      clear_errors_pulse <= 1'b0;

      if (write_valid) begin
        case (write_addr)
          ADDR_CONTROL: begin
            control_reg[0] <= write_data[0];
            control_reg[3] <= write_data[3];
            control_reg[4] <= write_data[4];
            soft_reset_pulse <= write_data[1];
            clear_errors_pulse <= write_data[2];
          end
          ADDR_FB_BASE: fb_base <= write_data;
          ADDR_FB_WIDTH: begin
            if (write_data[COORD_W-1:0] != '0) begin
              fb_width <= write_data[COORD_W-1:0];
            end
          end
          ADDR_FB_HEIGHT: begin
            if (write_data[COORD_W-1:0] != '0) begin
              fb_height <= write_data[COORD_W-1:0];
            end
          end
          ADDR_FB_FORMAT: begin
            if (write_data[1:0] == FB_FORMAT_RGB565) begin
              fb_format <= write_data[1:0];
            end
          end
          ADDR_INTERRUPT_STATUS: interrupt_status_reg <= interrupt_status_reg & ~write_data;
          ADDR_INTERRUPT_ENABLE: interrupt_enable_reg <= write_data;
          default: begin
          end
        endcase
      end
    end
  end
endmodule
