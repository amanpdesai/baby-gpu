#!/usr/bin/env python3
"""Assemble UrbanaGPU ISA text into 32-bit instruction words."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path


OPCODES = {
    "NOP": 0x00,
    "END": 0x01,
    "MOVI": 0x02,
    "MOVSR": 0x03,
    "ADD": 0x04,
    "MUL": 0x05,
    "LOAD": 0x06,
    "STORE": 0x07,
    "STORE16": 0x08,
    "CMP": 0x09,
    "BRA": 0x0A,
    "SUB": 0x0B,
    "AND": 0x0C,
    "OR": 0x0D,
    "XOR": 0x0E,
    "SHL": 0x0F,
    "SHR": 0x10,
    "PSTORE": 0x11,
    "PSTORE16": 0x12,
}

R_TYPE_OPS = {"ADD", "MUL", "SUB", "AND", "OR", "XOR", "SHL", "SHR"}

CMP_CONDS = {
    "EQ": 0x0,
    "NE": 0x1,
    "LTU": 0x2,
    "GEU": 0x3,
    "LTS": 0x4,
    "GES": 0x5,
}

SPECIAL_REGS = {
    "LANE_ID": 0x00,
    "GLOBAL_ID_X": 0x01,
    "GLOBAL_ID_Y": 0x02,
    "LINEAR_GLOBAL_ID": 0x03,
    "GROUP_ID_X": 0x04,
    "GROUP_ID_Y": 0x05,
    "LOCAL_ID_X": 0x06,
    "LOCAL_ID_Y": 0x07,
    "ARG_BASE": 0x08,
    "FRAMEBUFFER_BASE": 0x09,
    "FRAMEBUFFER_WIDTH": 0x0A,
    "FRAMEBUFFER_HEIGHT": 0x0B,
}

LABEL_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*):")
MEM_RE = re.compile(r"^\[\s*([^+\]\s]+)\s*(?:\+\s*([^\]]+))?\]$")


@dataclass(frozen=True)
class SourceLine:
    line_no: int
    text: str


@dataclass(frozen=True)
class ParsedInstruction:
    line_no: int
    op: str
    args: list[str]


class AsmError(ValueError):
    pass


def strip_comment(line: str) -> str:
    for marker in ("#", ";", "//"):
        index = line.find(marker)
        if index != -1:
            line = line[:index]
    return line.strip()


def split_args(text: str) -> list[str]:
    args: list[str] = []
    current: list[str] = []
    bracket_depth = 0
    saw_comma = False
    for char in text:
        if char == "[":
            bracket_depth += 1
        elif char == "]":
            bracket_depth -= 1
            if bracket_depth < 0:
                raise AsmError("unmatched ']'")
        if char == "," and bracket_depth == 0:
            arg = "".join(current).strip()
            if not arg:
                raise AsmError("empty operand")
            args.append(arg)
            current = []
            saw_comma = True
        else:
            current.append(char)
    if bracket_depth != 0:
        raise AsmError("unmatched '['")
    arg = "".join(current).strip()
    if not arg and saw_comma:
        raise AsmError("empty operand")
    if arg:
        args.append(arg)
    return args


def parse_int(token: str) -> int:
    text = token.strip().replace("_", "")
    if not text:
        raise AsmError("empty integer")
    try:
        return int(text, 0)
    except ValueError as exc:
        raise AsmError(f"invalid integer '{token}'") from exc


def require_range(value: int, width: int, field: str) -> int:
    max_value = (1 << width) - 1
    if value < 0 or value > max_value:
        raise AsmError(f"{field} value {value} does not fit unsigned {width}-bit field")
    return value


def require_signed_range(value: int, width: int, field: str) -> int:
    min_value = -(1 << (width - 1))
    max_value = (1 << (width - 1)) - 1
    if value < min_value or value > max_value:
        raise AsmError(f"{field} value {value} does not fit signed {width}-bit field")
    return value & ((1 << width) - 1)


def parse_reg(token: str) -> int:
    text = token.strip().upper()
    if not re.fullmatch(r"R(?:[0-9]|1[0-5])", text):
        raise AsmError(f"invalid register '{token}'")
    return int(text[1:])


def parse_special(token: str) -> int:
    text = token.strip().upper()
    if text in SPECIAL_REGS:
        return SPECIAL_REGS[text]
    raise AsmError(f"unknown special register '{token}'")


def parse_mem(token: str) -> tuple[int, int]:
    match = MEM_RE.match(token.strip())
    if not match:
        raise AsmError(f"invalid memory operand '{token}'")
    base = parse_reg(match.group(1))
    offset = 0 if match.group(2) is None else parse_int(match.group(2))
    return base, require_range(offset, 18, "memory offset")


def parse_pred_mem(token: str) -> tuple[int, int]:
    base, offset = parse_mem(token)
    return base, require_range(offset, 14, "predicated memory offset")


def parse_source(path: Path) -> tuple[list[ParsedInstruction], dict[str, int]]:
    instructions: list[ParsedInstruction] = []
    labels: dict[str, int] = {}

    for source in [SourceLine(i, line) for i, line in enumerate(path.read_text().splitlines(), 1)]:
        text = strip_comment(source.text)
        while text:
            match = LABEL_RE.match(text)
            if not match:
                break
            label = match.group(1)
            if label in labels:
                raise AsmError(f"{path}:{source.line_no}: duplicate label '{label}'")
            labels[label] = len(instructions)
            text = text[match.end() :].strip()
        if not text:
            continue

        parts = text.split(None, 1)
        op = parts[0].upper()
        try:
            args = split_args(parts[1]) if len(parts) > 1 else []
        except AsmError as exc:
            raise AsmError(f"{path}:{source.line_no}: {exc}") from exc
        instructions.append(ParsedInstruction(source.line_no, op, args))

    return instructions, labels


def r_type(op: int, rd: int, ra: int, rb: int) -> int:
    return (op << 26) | (rd << 22) | (ra << 18) | (rb << 14)


def cmp_type(rd: int, ra: int, rb: int, cond: int) -> int:
    return (OPCODES["CMP"] << 26) | (rd << 22) | (ra << 18) | (rb << 14) | cond


def i_type(op: int, rd: int, ra: int, imm18: int) -> int:
    return (op << 26) | (rd << 22) | (ra << 18) | imm18


def m_type(op: int, rd_rs: int, ra: int, offset18: int) -> int:
    return (op << 26) | (rd_rs << 22) | (ra << 18) | offset18


def p_type(op: int, rs: int, ra: int, pred: int, offset14: int) -> int:
    return (op << 26) | (rs << 22) | (ra << 18) | (pred << 14) | offset14


def b_type(pred: int, offset22: int) -> int:
    return (OPCODES["BRA"] << 26) | (pred << 22) | offset22


def s_type(rd: int, special_id: int) -> int:
    return (OPCODES["MOVSR"] << 26) | (rd << 22) | (special_id << 16)


def resolve_branch_offset(target: str, pc: int, labels: dict[str, int]) -> int:
    if target in labels:
        return labels[target] - (pc + 1)
    return parse_int(target)


def assemble_instruction(inst: ParsedInstruction, pc: int, labels: dict[str, int]) -> int:
    op = inst.op
    args = inst.args

    if op == ".WORD":
        if len(args) != 1:
            raise AsmError(".WORD expects one 32-bit value")
        return require_range(parse_int(args[0]), 32, ".WORD value")

    if "." in op:
        base_op, suffix = op.split(".", 1)
        if base_op != "CMP":
            raise AsmError(f"unknown mnemonic '{op}'")
        op = base_op
        args = [*args, suffix]

    if op not in OPCODES:
        raise AsmError(f"unknown mnemonic '{inst.op}'")

    if op in {"NOP", "END"}:
        if args:
            raise AsmError(f"{op} takes no operands")
        return OPCODES[op] << 26

    if op in R_TYPE_OPS:
        if len(args) != 3:
            raise AsmError(f"{op} expects rd, ra, rb")
        return r_type(OPCODES[op], parse_reg(args[0]), parse_reg(args[1]), parse_reg(args[2]))

    if op == "CMP":
        if len(args) != 4:
            raise AsmError("CMP expects rd, ra, rb, cond")
        cond_name = args[3].upper()
        if cond_name not in CMP_CONDS:
            raise AsmError(f"invalid CMP condition '{args[3]}'")
        return cmp_type(parse_reg(args[0]), parse_reg(args[1]), parse_reg(args[2]), CMP_CONDS[cond_name])

    if op == "MOVI":
        if len(args) != 2:
            raise AsmError("MOVI expects rd, imm18")
        return i_type(OPCODES[op], parse_reg(args[0]), 0, require_range(parse_int(args[1]), 18, "MOVI immediate"))

    if op == "MOVSR":
        if len(args) != 2:
            raise AsmError("MOVSR expects rd, special")
        return s_type(parse_reg(args[0]), parse_special(args[1]))

    if op == "LOAD":
        if len(args) != 2:
            raise AsmError("LOAD expects rd, [ra + offset]")
        ra, offset = parse_mem(args[1])
        return m_type(OPCODES[op], parse_reg(args[0]), ra, offset)

    if op in {"STORE", "STORE16"}:
        if len(args) != 2:
            raise AsmError(f"{op} expects [ra + offset], rs")
        ra, offset = parse_mem(args[0])
        return m_type(OPCODES[op], parse_reg(args[1]), ra, offset)

    if op in {"PSTORE", "PSTORE16"}:
        if len(args) != 3:
            raise AsmError(f"{op} expects [ra + offset], rs, pred")
        ra, offset = parse_pred_mem(args[0])
        return p_type(OPCODES[op], parse_reg(args[1]), ra, parse_reg(args[2]), offset)

    if op == "BRA":
        if len(args) != 2:
            raise AsmError("BRA expects pred, target")
        offset = resolve_branch_offset(args[1], pc, labels)
        return b_type(parse_reg(args[0]), require_signed_range(offset, 22, "branch offset"))

    raise AsmError(f"unhandled mnemonic '{op}'")


def assemble(path: Path) -> list[int]:
    instructions, labels = parse_source(path)
    words: list[int] = []
    for pc, inst in enumerate(instructions):
        try:
            words.append(assemble_instruction(inst, pc, labels))
        except AsmError as exc:
            raise AsmError(f"{path}:{inst.line_no}: {exc}") from exc
    return words


def write_words(words: list[int], path: Path | None) -> None:
    text = "".join(f"{word:08x}\n" for word in words)
    if path is None:
        sys.stdout.write(text)
    else:
        path.write_text(text)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="assembly source file")
    parser.add_argument("-o", "--output", type=Path, help="output hex file")
    args = parser.parse_args(argv)

    try:
        words = assemble(args.source)
        write_words(words, args.output)
    except AsmError as exc:
        print(f"kgpu_asm: error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
