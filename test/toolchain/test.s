# ============================================================
# RV32I comprehensive test program
# Register usage convention:
#   x1  = scratch / results
#   x2  = scratch
#   x3  = expected value for comparison
#   x10 = RAM base address (0x10000000)
#   x31 = test counter (increments each test)
# ============================================================

# ── Setup ────────────────────────────────────────────────────
    lui  x10, 0x10000       # x10 = 0x10000000 (RAM base)
    addi x31, x0, 0         # test counter = 0

# ── LUI / AUIPC ──────────────────────────────────────────────
    lui   x1, 0x12345       # x1  = 0x12345000
    auipc x2, 0             # x2  = PC of this instruction
    auipc x3, 1             # x3  = PC + 0x1000

# ── I-type ALU ───────────────────────────────────────────────
    addi x1, x0,  1         # x1  = 1
    addi x2, x0, -1         # x2  = 0xFFFFFFFF
    addi x3, x1,  5         # x3  = 6
    slti  x1, x2,  0        # x1  = 0 (0xFFFFFFFF >= 0 signed? no — -1 < 0 → 1)
    sltiu x1, x2,  1        # x1  = 0 (0xFFFFFFFF >= 1 unsigned)
    xori  x1, x2,  0xFF     # x1  = 0xFFFFFF00
    ori   x1, x0,  0x123    # x1  = 0x123
    andi  x1, x2,  0xFF     # x1  = 0xFF
    slli  x1, x3,  2        # x1  = 24
    srli  x1, x1,  1        # x1  = 12
    srai  x2, x2,  1        # x2  = 0xFFFFFFFF (sign extends)

# ── R-type ALU ───────────────────────────────────────────────
    addi x1, x0, 15         # x1  = 15
    addi x2, x0, 10         # x2  = 10
    add  x3, x1, x2         # x3  = 25
    sub  x3, x1, x2         # x3  = 5
    and  x3, x1, x2         # x3  = 10 & 15 = 10
    or   x3, x1, x2         # x3  = 15
    xor  x3, x1, x2         # x3  = 5
    sll  x3, x2, x1         # x3  = 10 << 15 = 0x00050000 (lower 5 bits of x1 = 15)
    srl  x3, x3, x1         # x3  = 0x00050000 >> 15 = 10
    addi x4, x0, -1         # x4  = 0xFFFFFFFF
    sra  x3, x4, x2         # x3  = 0xFFFFFFFF >>> 10 = 0xFFFFFFFF
    slt  x3, x4, x0         # x3  = 1 (-1 < 0 signed)
    slt  x3, x0, x4         # x3  = 0 (0 < -1 signed? no)
    sltu x3, x0, x4         # x3  = 1 (0 < 0xFFFFFFFF unsigned)
    sltu x3, x4, x0         # x3  = 0 (0xFFFFFFFF < 0 unsigned? no)

# ── Store / Load — full word ──────────────────────────────────
    addi x1, x0, 0x42       # x1  = 0x42
    sw   x1, 0(x10)         # mem[RAM+0]  = 0x42
    lw   x2, 0(x10)         # x2  = 0x42

# ── Store / Load — halfword ───────────────────────────────────
    lui  x1, 0x1            # x1  = 0x0000_1000
    addi x1, x1, 0x234      # x1  = 0x1234 (positive halfword)
    sh   x1, 4(x10)         # mem[RAM+4]  low halfword = 0x1234
    lh   x2, 4(x10)         # x2  = 0x00001234 (sign extended, MSB=0)
    lhu  x2, 4(x10)         # x2  = 0x00001234

    lui  x1, 0xFFFFF        # x1  = 0xFFFFF000
    addi x1, x0, -1         # x1  = 0xFFFFFFFF
    sh   x1, 8(x10)         # mem[RAM+8]  low halfword = 0xFFFF
    lh   x2, 8(x10)         # x2  = 0xFFFFFFFF (sign extended, MSB=1)
    lhu  x2, 8(x10)         # x2  = 0x0000FFFF (zero extended)

# ── Store / Load — byte ───────────────────────────────────────
    addi x1, x0, 0x7F       # x1  = 0x7F (positive byte)
    sb   x1, 12(x10)        # mem[RAM+12] byte0 = 0x7F
    lb   x2, 12(x10)        # x2  = 0x0000007F (sign extended, MSB=0)
    lbu  x2, 12(x10)        # x2  = 0x0000007F

    addi x1, x0, -1         # x1  = 0xFFFFFFFF
    sb   x1, 16(x10)        # mem[RAM+16] byte0 = 0xFF
    lb   x2, 16(x10)        # x2  = 0xFFFFFFFF (sign extended, MSB=1)
    lbu  x2, 16(x10)        # x2  = 0x000000FF (zero extended)

# ── Byte offsets within word ──────────────────────────────────
    addi x1, x0, 0x11       # x1 = 0x11
    sb   x1,  20(x10)       # byte offset 0
    addi x1, x0, 0x22
    sb   x1,  21(x10)       # byte offset 1
    addi x1, x0, 0x33
    sb   x1,  22(x10)       # byte offset 2
    addi x1, x0, 0x44
    sb   x1,  23(x10)       # byte offset 3
    lw   x2,  20(x10)       # x2 = 0x44332211

# ── JAL / JALR ───────────────────────────────────────────────
    addi x5, x0, 0          # x5 = 0 (will be set by subroutine)
    jal  x6, subr           # x6 = PC+4, jump to subr
    addi x5, x5, 100        # should be skipped
    addi x5, x5, 200        # should be skipped
after_subr:
    # x5 should be 42 here, x6 = address of skipped addi

    # JALR — jump back via register
    addi x7, x0, 1          # x7 = 1 (will be set by jalr target)
    la   x8, jalr_target    # x8 = address of jalr_target
                             # (assembled as auipc + addi pair)
    jalr x9, 0(x8)          # x9 = PC+4, jump to jalr_target
    addi x7, x7, 100        # should be skipped
jalr_target:
    addi x7, x7, 10         # x7 = 11

# ── Branches ─────────────────────────────────────────────────
    addi x1, x0, 5
    addi x2, x0, 5

    # BEQ taken
    beq  x1, x2, beq_ok
    addi x3, x0, -1      # should be skipped
beq_ok:
    addi x3, x0, 1          # x3 = 1

    # BNE taken
    addi x2, x0, 6
    bne  x1, x2, bne_ok
    addi x3, x0, 0x7FF
bne_ok:
    addi x3, x3, 1          # x3 = 2

    # BEQ not taken
    beq  x1, x2, bad_beq
    addi x3, x3, 1          # x3 = 3 — should execute
    jal  x0, after_bad_beq
bad_beq:
    addi x3, x0, 0x7FF
after_bad_beq:

    # BLT taken (5 < 6 signed)
    blt  x1, x2, blt_ok
    addi x3, x0, 0x7FF
blt_ok:
    addi x3, x3, 1          # x3 = 4

    # BGE taken (6 >= 5 signed)
    bge  x2, x1, bge_ok
    addi x3, x0,-1
bge_ok:
    addi x3, x3, 1          # x3 = 5

    # BGE not taken (5 >= 6? no)
    bge  x1, x2, bad_bge
    addi x3, x3, 1          # x3 = 6 — should execute
    jal  x0, after_bad_bge
bad_bge:
    addi x3, x0, -1
after_bad_bge:

    # BLTU / BGEU with unsigned comparison
    addi x1, x0, -1         # x1 = 0xFFFFFFFF (large unsigned)
    addi x2, x0,  1         # x2 = 1

    # BLTU not taken (0xFFFFFFFF < 1 unsigned? no)
    bltu x1, x2, bad_bltu
    addi x3, x3, 1          # x3 = 7 — should execute
    jal  x0, after_bad_bltu
bad_bltu:
    addi x3, x0, -1
after_bad_bltu:

    # BLTU taken (1 < 0xFFFFFFFF unsigned)
    bltu x2, x1, bltu_ok
    addi x3, x0, 10
bltu_ok:
    addi x3, x3, 1          # x3 = 8

    # BGEU taken (0xFFFFFFFF >= 1 unsigned)
    bgeu x1, x2, bgeu_ok
    addi x3, x0, 0x243
bgeu_ok:
    addi x3, x3, 1          # x3 = 9

# ecall:
#     ecall
# ── Infinite loop ─────────────────────────────────────────────
done:
    jal  x0, 0              # loop forever

# ── Trap Handler ─────────────────────────────────────────────
# trap_handler:
#     j .

# ── Subroutine ────────────────────────────────────────────────
subr:
    addi x5, x0, 42         # x5 = 42
    jalr x0, 0(x6)          # return to caller via x6
