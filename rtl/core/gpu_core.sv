module gpu_core #(
    parameter int FB_WIDTH = 160,
    parameter int FB_HEIGHT = 120,
    parameter int FIFO_DEPTH = 16,
    parameter int ADDR_W = 32,
    parameter int DATA_W = 32,
    parameter int COORD_W = 16,
    parameter int COLOR_W = 16,
    parameter int LANES = 4,
    parameter int PC_W = 8,
    parameter int REGS = 16,
    parameter int INSTR_W = 32
) (
    input logic clk,
    input logic reset,
    input logic enable,
    input logic clear_errors,

    input logic cmd_valid,
    output logic cmd_ready,
    input logic [DATA_W-1:0] cmd_data,

    input logic imem_write_en,
    input logic [PC_W-1:0] imem_write_addr,
    input logic [INSTR_W-1:0] imem_write_data,

    output logic busy,
    output logic [7:0] error_status,

    output logic mem_req_valid,
    input logic mem_req_ready,
    output logic mem_req_write,
    output logic [ADDR_W-1:0] mem_req_addr,
    output logic [DATA_W-1:0] mem_req_wdata,
    output logic [(DATA_W/8)-1:0] mem_req_wmask,
    input logic mem_rsp_valid,
    output logic mem_rsp_ready,
    input logic [DATA_W-1:0] mem_rsp_rdata
);
  localparam int FIFO_COUNT_W = $clog2(FIFO_DEPTH + 1);

  logic fifo_valid;
  logic fifo_ready;
  logic [DATA_W-1:0] fifo_data;
  logic fifo_empty;
  logic [FIFO_COUNT_W-1:0] fifo_count;

  logic cp_busy;
  logic [7:0] cp_error_status;

  logic register_soft_reset;
  logic register_clear_errors;
  logic [ADDR_W-1:0] register_fb_base;
  logic [COORD_W-1:0] register_fb_width;
  logic [COORD_W-1:0] register_fb_height;
  logic [1:0] register_fb_format;
  logic combined_reset;
  logic combined_clear_errors;
  logic [ADDR_W-1:0] register_stride_bytes;
  logic [ADDR_W-1:0] register_launch_program_base;
  logic [COORD_W-1:0] register_launch_grid_x;
  logic [COORD_W-1:0] register_launch_grid_y;
  logic [COORD_W-1:0] register_launch_group_size_x;
  logic [COORD_W-1:0] register_launch_group_size_y;
  logic [ADDR_W-1:0] register_launch_arg_base;
  logic [DATA_W-1:0] register_launch_flags;
  logic launch_start;
  logic launch_busy;
  logic [DATA_W-1:0] launch_program_base_latched;
  logic [COORD_W-1:0] launch_grid_x_latched;
  logic [COORD_W-1:0] launch_grid_y_latched;
  logic [COORD_W-1:0] launch_group_size_x_latched;
  logic [COORD_W-1:0] launch_group_size_y_latched;
  logic [DATA_W-1:0] launch_arg_base_latched;
  logic [DATA_W-1:0] launch_flags_latched;
  logic programmable_launch_ready;
  logic programmable_busy;
  logic programmable_done;
  logic programmable_error;
  logic [PC_W-1:0] programmable_instruction_addr;
  logic [PC_W-1:0] imem_fetch_addr;
  logic [INSTR_W-1:0] programmable_instruction;
  logic imem_fetch_error;
  logic programmable_data_req_valid;
  logic programmable_data_req_ready;
  logic programmable_data_req_write;
  logic [ADDR_W-1:0] programmable_data_req_addr;
  logic [31:0] programmable_data_req_wdata;
  logic [3:0] programmable_data_req_wmask;
  logic programmable_data_rsp_ready;
  logic [(LANES*DATA_W)-1:0] programmable_debug_read_data;

  logic clear_start;
  logic [COLOR_W-1:0] clear_color;
  logic clear_busy;
  logic clear_done;
  logic clear_error;
  logic clear_pixel_valid;
  logic clear_pixel_ready;
  logic [COORD_W-1:0] clear_pixel_x;
  logic [COORD_W-1:0] clear_pixel_y;
  logic [COLOR_W-1:0] clear_pixel_color;

  logic rect_start;
  logic [COORD_W-1:0] rect_x;
  logic [COORD_W-1:0] rect_y;
  logic [COORD_W-1:0] rect_width;
  logic [COORD_W-1:0] rect_height;
  logic [COLOR_W-1:0] rect_color;
  logic rect_busy;
  logic rect_done;
  logic rect_error;
  logic rect_pixel_valid;
  logic rect_pixel_ready;
  logic [COORD_W-1:0] rect_pixel_x;
  logic [COORD_W-1:0] rect_pixel_y;
  logic [COLOR_W-1:0] rect_pixel_color;

  logic writer_pixel_valid;
  logic writer_pixel_ready;
  logic [COORD_W-1:0] writer_pixel_x;
  logic [COORD_W-1:0] writer_pixel_y;
  logic [COLOR_W-1:0] writer_pixel_color;
  logic writer_mem_req_valid;
  logic writer_mem_req_ready;
  logic writer_mem_req_write;
  logic [ADDR_W-1:0] writer_mem_req_addr;
  logic [DATA_W-1:0] writer_mem_req_wdata;
  logic [(DATA_W/8)-1:0] writer_mem_req_wmask;

  logic reg_write_valid;
  logic [DATA_W-1:0] reg_write_addr;
  logic [DATA_W-1:0] reg_write_data;

  assign combined_clear_errors = clear_errors || register_clear_errors;
  assign combined_reset = reset || register_soft_reset;
  assign register_stride_bytes = ADDR_W'(register_fb_width) << 1;
  assign launch_busy = programmable_busy || !programmable_launch_ready || launch_start;
  assign busy = cp_busy || !fifo_empty;
  assign error_status = cp_error_status |
      {clear_error, rect_error, programmable_error | imem_fetch_error, 5'b00000};

  assign imem_fetch_addr = programmable_instruction_addr + PC_W'(launch_program_base_latched[PC_W-1:0]);

  register_file #(
      .ADDR_W(ADDR_W),
      .DATA_W(DATA_W),
      .COORD_W(COORD_W),
      .FB_WIDTH_DEFAULT(FB_WIDTH),
      .FB_HEIGHT_DEFAULT(FB_HEIGHT)
  ) u_register_file (
      .clk(clk),
      .reset(reset),
      .write_valid(reg_write_valid),
      .write_addr(reg_write_addr),
      .write_data(reg_write_data),
      .read_valid(1'b0),
      .read_addr('0),
      .read_data(),
      .status_busy(busy),
      .status_errors(error_status),
      .core_enable(),
      .soft_reset_pulse(register_soft_reset),
      .clear_errors_pulse(register_clear_errors),
      .test_pattern_enable(),
      .fb_base(register_fb_base),
      .fb_width(register_fb_width),
      .fb_height(register_fb_height),
      .fb_format(register_fb_format),
      .launch_program_base(register_launch_program_base),
      .launch_grid_x(register_launch_grid_x),
      .launch_grid_y(register_launch_grid_y),
      .launch_group_size_x(register_launch_group_size_x),
      .launch_group_size_y(register_launch_group_size_y),
      .launch_arg_base(register_launch_arg_base),
      .launch_flags(register_launch_flags)
  );

  command_fifo #(
      .DATA_W(DATA_W),
      .DEPTH(FIFO_DEPTH)
  ) u_command_fifo (
      .clk(clk),
      .reset(combined_reset),
      .flush(combined_clear_errors),
      .in_valid(cmd_valid),
      .in_ready(cmd_ready),
      .in_data(cmd_data),
      .out_valid(fifo_valid),
      .out_ready(fifo_ready),
      .out_data(fifo_data),
      .full(),
      .empty(fifo_empty),
      .count(fifo_count)
  );

  command_processor #(
      .WORD_W(DATA_W),
      .COORD_W(COORD_W),
      .COLOR_W(COLOR_W)
  ) u_command_processor (
      .clk(clk),
      .reset(combined_reset),
      .enable(enable),
      .clear_errors(combined_clear_errors),
      .cmd_valid(fifo_valid),
      .cmd_ready(fifo_ready),
      .cmd_data(fifo_data),
      .clear_start(clear_start),
      .clear_color(clear_color),
      .clear_busy(clear_busy),
      .clear_done(clear_done),
      .rect_start(rect_start),
      .rect_x(rect_x),
      .rect_y(rect_y),
      .rect_width(rect_width),
      .rect_height(rect_height),
      .rect_color(rect_color),
      .rect_busy(rect_busy),
      .rect_done(rect_done),
      .launch_start(launch_start),
      .launch_busy(launch_busy),
      .launch_program_base(DATA_W'(register_launch_program_base)),
      .launch_grid_x(register_launch_grid_x),
      .launch_grid_y(register_launch_grid_y),
      .launch_group_size_x(register_launch_group_size_x),
      .launch_group_size_y(register_launch_group_size_y),
      .launch_arg_base(DATA_W'(register_launch_arg_base)),
      .launch_flags(register_launch_flags),
      .launch_program_base_latched(launch_program_base_latched),
      .launch_grid_x_latched(launch_grid_x_latched),
      .launch_grid_y_latched(launch_grid_y_latched),
      .launch_group_size_x_latched(launch_group_size_x_latched),
      .launch_group_size_y_latched(launch_group_size_y_latched),
      .launch_arg_base_latched(launch_arg_base_latched),
      .launch_flags_latched(launch_flags_latched),
      .reg_write_valid(reg_write_valid),
      .reg_write_addr(reg_write_addr),
      .reg_write_data(reg_write_data),
      .busy(cp_busy),
      .error_status(cp_error_status)
  );

  instruction_memory #(
      .WORD_W(INSTR_W),
      .ADDR_W(PC_W),
      .DEPTH(1 << PC_W)
  ) u_instruction_memory (
      .clk(clk),
      .write_en(imem_write_en),
      .write_addr(imem_write_addr),
      .write_data(imem_write_data),
      .fetch_addr(imem_fetch_addr),
      .fetch_instruction(programmable_instruction),
      .fetch_error(imem_fetch_error)
  );

  programmable_core #(
      .LANES(LANES),
      .DATA_W(DATA_W),
      .COORD_W(COORD_W),
      .ADDR_W(ADDR_W),
      .PC_W(PC_W),
      .REGS(REGS)
  ) u_programmable_core (
      .clk(clk),
      .reset(combined_reset),
      .launch_valid(launch_start),
      .launch_ready(programmable_launch_ready),
      .grid_x(launch_grid_x_latched),
      .grid_y(launch_grid_y_latched),
      .arg_base(ADDR_W'(launch_arg_base_latched)),
      .framebuffer_base(register_fb_base),
      .framebuffer_width(register_fb_width),
      .framebuffer_height(register_fb_height),
      .instruction_addr(programmable_instruction_addr),
      .instruction(programmable_instruction),
      .data_req_valid(programmable_data_req_valid),
      .data_req_ready(programmable_data_req_ready),
      .data_req_write(programmable_data_req_write),
      .data_req_addr(programmable_data_req_addr),
      .data_req_wdata(programmable_data_req_wdata),
      .data_req_wmask(programmable_data_req_wmask),
      .data_rsp_valid(mem_rsp_valid),
      .data_rsp_ready(programmable_data_rsp_ready),
      .data_rsp_rdata(mem_rsp_rdata[31:0]),
      .busy(programmable_busy),
      .done(programmable_done),
      .error(programmable_error),
      .debug_read_addr('0),
      .debug_read_data(programmable_debug_read_data)
  );

  clear_engine #(
      .FB_WIDTH(FB_WIDTH),
      .FB_HEIGHT(FB_HEIGHT),
      .COORD_W(COORD_W),
      .COLOR_W(COLOR_W)
  ) u_clear_engine (
      .clk(clk),
      .reset(combined_reset),
      .start(clear_start),
      .start_color(clear_color),
      .busy(clear_busy),
      .done(clear_done),
      .error(clear_error),
      .pixel_valid(clear_pixel_valid),
      .pixel_ready(clear_pixel_ready),
      .pixel_x(clear_pixel_x),
      .pixel_y(clear_pixel_y),
      .pixel_color(clear_pixel_color)
  );

  rect_fill_engine #(
      .FB_WIDTH(FB_WIDTH),
      .FB_HEIGHT(FB_HEIGHT),
      .COORD_W(COORD_W),
      .COLOR_W(COLOR_W)
  ) u_rect_fill_engine (
      .clk(clk),
      .reset(combined_reset),
      .start(rect_start),
      .rect_x(rect_x),
      .rect_y(rect_y),
      .rect_width(rect_width),
      .rect_height(rect_height),
      .rect_color(rect_color),
      .busy(rect_busy),
      .done(rect_done),
      .error(rect_error),
      .pixel_valid(rect_pixel_valid),
      .pixel_ready(rect_pixel_ready),
      .pixel_x(rect_pixel_x),
      .pixel_y(rect_pixel_y),
      .pixel_color(rect_pixel_color)
  );

  assign writer_pixel_valid = clear_pixel_valid || rect_pixel_valid;
  assign writer_pixel_x = clear_pixel_valid ? clear_pixel_x : rect_pixel_x;
  assign writer_pixel_y = clear_pixel_valid ? clear_pixel_y : rect_pixel_y;
  assign writer_pixel_color = clear_pixel_valid ? clear_pixel_color : rect_pixel_color;
  assign clear_pixel_ready = clear_pixel_valid ? writer_pixel_ready : 1'b0;
  assign rect_pixel_ready = (!clear_pixel_valid && rect_pixel_valid) ? writer_pixel_ready : 1'b0;

  framebuffer_writer #(
      .ADDR_W(ADDR_W),
      .DATA_W(DATA_W),
      .COORD_W(COORD_W),
      .COLOR_W(COLOR_W)
  ) u_framebuffer_writer (
      .pixel_valid(writer_pixel_valid),
      .pixel_ready(writer_pixel_ready),
      .pixel_x(writer_pixel_x),
      .pixel_y(writer_pixel_y),
      .pixel_color(writer_pixel_color),
      .fb_base(register_fb_base),
      .fb_width(register_fb_width),
      .fb_height(register_fb_height),
      .stride_bytes(register_stride_bytes),
      .mem_req_valid(writer_mem_req_valid),
      .mem_req_ready(writer_mem_req_ready),
      .mem_req_write(writer_mem_req_write),
      .mem_req_addr(writer_mem_req_addr),
      .mem_req_wdata(writer_mem_req_wdata),
      .mem_req_wmask(writer_mem_req_wmask)
  );

  assign mem_req_valid = writer_mem_req_valid || programmable_data_req_valid;
  assign mem_req_write = writer_mem_req_valid ? writer_mem_req_write : programmable_data_req_write;
  assign mem_req_addr = writer_mem_req_valid ? writer_mem_req_addr : programmable_data_req_addr;
  assign mem_req_wdata = writer_mem_req_valid ? writer_mem_req_wdata : DATA_W'(programmable_data_req_wdata);
  assign mem_req_wmask = writer_mem_req_valid ? writer_mem_req_wmask : (DATA_W / 8)'(programmable_data_req_wmask);
  assign writer_mem_req_ready = mem_req_ready;
  assign programmable_data_req_ready = !writer_mem_req_valid && mem_req_ready;
  assign mem_rsp_ready = programmable_busy ? programmable_data_rsp_ready : 1'b1;
endmodule
