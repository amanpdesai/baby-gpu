# UrbanaGPU Assembler

`tools/assembler/kgpu_asm.py` assembles the current UrbanaGPU ISA text format
into one 32-bit hexadecimal instruction word per line. The output is suitable
for `$readmemh`-style instruction memory fixtures and for host-side tooling that
needs deterministic kernel images before a C compiler exists.

This is an assembler only. It does not define a C ABI, perform register
allocation, schedule instructions, or lower C control flow.

## Usage

```bash
python3 tools/assembler/kgpu_asm.py kernel.kgpu -o kernel.memh
```

The default output format is plain text:

```text
08400007
04000000
```

Each line is one 32-bit instruction word in hexadecimal.

## Source Format

The assembler accepts:

- one instruction per line
- labels using `name:`
- comments beginning with `#`, `;`, or `//`
- registers `R0` through `R15`
- named special registers from the implemented ISA
- decimal or `0x` integer literals
- `_` separators inside integer literals

Example:

```text
start:
  MOVSR R1, GLOBAL_ID_X
  MOVI  R2, 0x4
  SHL   R3, R1, R2
  LOAD  R4, [R12 + 0]
  STORE [R13 + 16], R4
  END
```

## Supported Mnemonics

The assembler tracks the implemented base ISA:

```text
NOP END MOVI MOVSR
ADD MUL SUB AND OR XOR SHL SHR
LOAD STORE STORE16
CMP BRA
PSTORE PSTORE16
```

`CMP` accepts either suffix or operand condition form:

```text
CMP.LTU R3, R1, R2
CMP R3, R1, R2, LTU
```

Supported compare conditions:

```text
EQ NE LTU GEU LTS GES
```

Branches use signed instruction-word offsets relative to the next instruction.
When a label is used, the assembler computes that offset:

```text
loop:
  CMP.NE R1, R2, R0
  BRA R1, loop
```

Memory operands use unsigned offsets:

```text
LOAD R4, [R12 + 0]
STORE [R13 + 16], R4
STORE16 [R13 + 2], R4
PSTORE [R13 + 16], R4, R1
PSTORE16 [R13 + 2], R4, R1
```

The current RTL treats `MOVI` and memory offsets as unsigned fields. Signed
immediates should be added as an explicit ISA extension rather than inferred by
the assembler. Numeric special-register IDs outside the implemented names are
rejected so normal kernel images cannot accidentally encode illegal special
register accesses.

## Verification

Tool tests live in `tests/test_kgpu_asm.py` and can be run with:

```bash
make test-tools
```

Checked-in kernel fixtures live under `tests/kernels/`. Each committed `.memh`
image should have a matching `.kgpu` source file and a host-tool test proving
the assembler output is identical to the checked-in image used by RTL
simulation.

Hardware changes still require the normal RTL gates:

```bash
make sim
make lint
make formal
make synth-yosys
```
