# Coding Style

This project uses SystemVerilog RTL with a conservative synchronous style. The
goal is readable, testable hardware rather than clever code.

## RTL Rules

| Rule | Reason |
| --- | --- |
| Use `always_ff` for sequential logic. | Makes clocked state explicit. |
| Use `always_comb` for combinational logic. | Reduces accidental latch risk. |
| Assign defaults at the top of combinational blocks. | Prevents incomplete assignments. |
| Avoid internal tri-state buses. | Keeps synthesis behavior portable. |
| Avoid gated clocks. | Keeps timing and ASIC portability manageable. |
| Keep resets consistent. | Simplifies bring-up and verification. |
| Use parameters for widths and dimensions. | Makes tests and variants easier. |
| Keep clock-domain crossings explicit. | Prevents accidental metastability bugs. |

## Module Template

```systemverilog
module example_unit #(
  parameter int DATA_W = 32
) (
  input  logic              clk,
  input  logic              reset,
  input  logic              in_valid,
  output logic              in_ready,
  input  logic [DATA_W-1:0] in_data,
  output logic              out_valid,
  input  logic              out_ready,
  output logic [DATA_W-1:0] out_data
);

  always_ff @(posedge clk) begin
    if (reset) begin
      out_valid <= 1'b0;
    end else begin
      // State updates.
    end
  end

  always_comb begin
    in_ready = 1'b0;
    out_data = '0;
    // Combinational decisions.
  end

endmodule
```

## Reset Policy

Version 1 uses synchronous reset inside the portable GPU core. Platform wrappers
may condition external reset inputs, but they must present a clean synchronized
reset to the core.

Reset must guarantee:

- no memory writes are active
- command processor is idle
- draw units are idle
- status registers are deterministic
- sticky error bits are cleared unless explicitly retained later

## Assertion Policy

Assertions should document invariants that are easy to violate:

- valid command packets have expected word counts
- FIFOs do not overflow or underflow
- draw units do not assert `done` without a prior `start`
- memory clients hold request payload stable while `valid && !ready`

Assertions should live near the behavior they protect.

## ASIC-Oriented RTL Rules

When implementation starts, use these additional rules:

- avoid declaration-time initialization in synthesizable RTL
- avoid `initial` blocks in portable synthesizable RTL
- use sized constants for datapath logic
- make FSM encodings explicit where helpful for debug
- include illegal-state recovery for control FSMs
- keep memories behind wrappers or interfaces
- document every intended multicycle behavior
- keep valid/ready payload stable during stalls
- make every draw unit's termination condition explicit
- make every counter width bounded by parameters

## Comments

Comment non-obvious hardware behavior:

- timing assumptions
- protocol edge cases
- clipping rules
- address calculations
- arbitration fairness decisions

Do not comment obvious assignments.
