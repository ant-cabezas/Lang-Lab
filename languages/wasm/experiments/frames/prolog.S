// WebAssembly side study, frames diagnostic: test functions for prolog.c (aarch64).
// x0 = accumulator, x2 = fake vmctx (points to a struct whose [8] -> struct whose [0x18] = 0 limit)
#define WORK  add x0, x0, #1; eor x3, x0, x1; add x0, x0, x3, lsr #3; add x1, x1, #3; eor x0, x0, x1; add x0, x0, #5; eor x3, x0, x1; add x0, x0, x3, lsr #2
.text
.globl fA, fB, fC, fD
// A: Cranelift style: chained pre-index pushes of 5 callee-saved pairs, stack-limit check via 2 dependent loads
fA: stp x29, x30, [sp, #-0x10]!
    mov x29, sp
    ldur x16, [x2, #8]
    ldur x16, [x16, #0x18]
    add x16, x16, #0x60
    cmp sp, x16
    b.lo 1f
    stp x27, x28, [sp, #-0x10]!
    stp x25, x26, [sp, #-0x10]!
    stp x23, x24, [sp, #-0x10]!
    stp x21, x22, [sp, #-0x10]!
    stp x19, x20, [sp, #-0x10]!
    WORK
    ldp x19, x20, [sp], #0x10
    ldp x21, x22, [sp], #0x10
    ldp x23, x24, [sp], #0x10
    ldp x25, x26, [sp], #0x10
    ldp x27, x28, [sp], #0x10
    ldp x29, x30, [sp], #0x10
    ret
1:  udf #0
// B: same instructions, one sp adjustment, offset-addressed saves (gcc/clang style)
fB: stp x29, x30, [sp, #-0x60]!
    mov x29, sp
    ldur x16, [x2, #8]
    ldur x16, [x16, #0x18]
    add x16, x16, #0x60
    cmp sp, x16
    b.lo 1f
    stp x27, x28, [sp, #0x10]
    stp x25, x26, [sp, #0x20]
    stp x23, x24, [sp, #0x30]
    stp x21, x22, [sp, #0x40]
    stp x19, x20, [sp, #0x50]
    WORK
    ldp x19, x20, [sp, #0x50]
    ldp x21, x22, [sp, #0x40]
    ldp x23, x24, [sp, #0x30]
    ldp x25, x26, [sp, #0x20]
    ldp x27, x28, [sp, #0x10]
    ldp x29, x30, [sp], #0x60
    ret
1:  udf #0
// C: like A without the stack-limit check (replaced by same count of independent ALU ops)
fC: stp x29, x30, [sp, #-0x10]!
    mov x29, sp
    mov x16, #0
    mov x17, #0
    add x16, x16, #0x60
    cmp x16, x17
    b.lo 1f
    stp x27, x28, [sp, #-0x10]!
    stp x25, x26, [sp, #-0x10]!
    stp x23, x24, [sp, #-0x10]!
    stp x21, x22, [sp, #-0x10]!
    stp x19, x20, [sp, #-0x10]!
    WORK
    ldp x19, x20, [sp], #0x10
    ldp x21, x22, [sp], #0x10
    ldp x23, x24, [sp], #0x10
    ldp x25, x26, [sp], #0x10
    ldp x27, x28, [sp], #0x10
    ldp x29, x30, [sp], #0x10
    ret
1:  udf #0
// D: B without the check
fD: stp x29, x30, [sp, #-0x60]!
    mov x29, sp
    mov x16, #0
    mov x17, #0
    add x16, x16, #0x60
    cmp x16, x17
    b.lo 1f
    stp x27, x28, [sp, #0x10]
    stp x25, x26, [sp, #0x20]
    stp x23, x24, [sp, #0x30]
    stp x21, x22, [sp, #0x40]
    stp x19, x20, [sp, #0x50]
    WORK
    ldp x19, x20, [sp, #0x50]
    ldp x21, x22, [sp, #0x40]
    ldp x23, x24, [sp, #0x30]
    ldp x25, x26, [sp, #0x20]
    ldp x27, x28, [sp, #0x10]
    ldp x29, x30, [sp], #0x60
    ret
1:  udf #0
.globl fE, fF, fG
// E: chained pre-index pushes, single-writeback epilogue
fE: stp x29, x30, [sp, #-0x10]!
    mov x29, sp
    ldur x16, [x2, #8]
    ldur x16, [x16, #0x18]
    add x16, x16, #0x60
    cmp sp, x16
    b.lo 1f
    stp x27, x28, [sp, #-0x10]!
    stp x25, x26, [sp, #-0x10]!
    stp x23, x24, [sp, #-0x10]!
    stp x21, x22, [sp, #-0x10]!
    stp x19, x20, [sp, #-0x10]!
    WORK
    ldp x19, x20, [sp, #0x00]
    ldp x21, x22, [sp, #0x10]
    ldp x23, x24, [sp, #0x20]
    ldp x25, x26, [sp, #0x30]
    ldp x27, x28, [sp, #0x40]
    ldp x29, x30, [sp, #0x50]
    add sp, sp, #0x60
    ret
1:  udf #0
// F: single-writeback prologue, chained post-index pops
fF: sub sp, sp, #0x60
    stp x29, x30, [sp, #0x50]
    add x29, sp, #0x50
    ldur x16, [x2, #8]
    ldur x16, [x16, #0x18]
    add x16, x16, #0x60
    cmp sp, x16
    b.lo 1f
    stp x27, x28, [sp, #0x40]
    stp x25, x26, [sp, #0x30]
    stp x23, x24, [sp, #0x20]
    stp x21, x22, [sp, #0x10]
    stp x19, x20, [sp, #0x00]
    WORK
    ldp x19, x20, [sp], #0x10
    ldp x21, x22, [sp], #0x10
    ldp x23, x24, [sp], #0x10
    ldp x25, x26, [sp], #0x10
    ldp x27, x28, [sp], #0x10
    ldp x29, x30, [sp], #0x10
    ret
1:  udf #0
// G: make()-sized Cranelift frame: fp/lr + 1 single + 1 pair, chained
fG: stp x29, x30, [sp, #-0x10]!
    mov x29, sp
    ldur x16, [x2, #8]
    ldur x16, [x16, #0x18]
    add x16, x16, #0x30
    cmp sp, x16
    b.lo 1f
    str x21, [sp, #-0x10]!
    stp x19, x20, [sp, #-0x10]!
    WORK
    ldp x19, x20, [sp], #0x10
    ldr x21, [sp], #0x10
    ldp x29, x30, [sp], #0x10
    ret
1:  udf #0
