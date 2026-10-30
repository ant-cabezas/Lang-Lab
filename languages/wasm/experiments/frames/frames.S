// WebAssembly side study, frames diagnostic: test functions for frames.c (aarch64).
.text
.globl fC0S
fC0S:
    stp x29, x30, [sp, #-0x10]!
    mov x29, sp
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    ldp x29, x30, [sp], #0x10
    ret
.globl fO0S
fO0S:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    ldp x29, x30, [sp], #16
    ret
.globl fC1S
fC1S:
    stp x29, x30, [sp, #-0x10]!
    mov x29, sp
    stp x19, x20, [sp, #-0x10]!
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    ldp x19, x20, [sp], #0x10
    ldp x29, x30, [sp], #0x10
    ret
.globl fO1S
fO1S:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
.globl fC2S
fC2S:
    stp x29, x30, [sp, #-0x10]!
    mov x29, sp
    stp x21, x22, [sp, #-0x10]!
    stp x19, x20, [sp, #-0x10]!
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    ldp x19, x20, [sp], #0x10
    ldp x21, x22, [sp], #0x10
    ldp x29, x30, [sp], #0x10
    ret
.globl fO2S
fO2S:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    ldp x19, x20, [sp, #16]
    ldp x21, x22, [sp, #32]
    ldp x29, x30, [sp], #48
    ret
.globl fC3S
fC3S:
    stp x29, x30, [sp, #-0x10]!
    mov x29, sp
    stp x23, x24, [sp, #-0x10]!
    stp x21, x22, [sp, #-0x10]!
    stp x19, x20, [sp, #-0x10]!
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    ldp x19, x20, [sp], #0x10
    ldp x21, x22, [sp], #0x10
    ldp x23, x24, [sp], #0x10
    ldp x29, x30, [sp], #0x10
    ret
.globl fO3S
fO3S:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    ldp x19, x20, [sp, #16]
    ldp x21, x22, [sp, #32]
    ldp x23, x24, [sp, #48]
    ldp x29, x30, [sp], #64
    ret
.globl fC4S
fC4S:
    stp x29, x30, [sp, #-0x10]!
    mov x29, sp
    stp x25, x26, [sp, #-0x10]!
    stp x23, x24, [sp, #-0x10]!
    stp x21, x22, [sp, #-0x10]!
    stp x19, x20, [sp, #-0x10]!
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    ldp x19, x20, [sp], #0x10
    ldp x21, x22, [sp], #0x10
    ldp x23, x24, [sp], #0x10
    ldp x25, x26, [sp], #0x10
    ldp x29, x30, [sp], #0x10
    ret
.globl fO4S
fO4S:
    stp x29, x30, [sp, #-80]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    ldp x19, x20, [sp, #16]
    ldp x21, x22, [sp, #32]
    ldp x23, x24, [sp, #48]
    ldp x25, x26, [sp, #64]
    ldp x29, x30, [sp], #80
    ret
.globl fC5S
fC5S:
    stp x29, x30, [sp, #-0x10]!
    mov x29, sp
    stp x27, x28, [sp, #-0x10]!
    stp x25, x26, [sp, #-0x10]!
    stp x23, x24, [sp, #-0x10]!
    stp x21, x22, [sp, #-0x10]!
    stp x19, x20, [sp, #-0x10]!
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    ldp x19, x20, [sp], #0x10
    ldp x21, x22, [sp], #0x10
    ldp x23, x24, [sp], #0x10
    ldp x25, x26, [sp], #0x10
    ldp x27, x28, [sp], #0x10
    ldp x29, x30, [sp], #0x10
    ret
.globl fO5S
fO5S:
    stp x29, x30, [sp, #-96]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, x28, [sp, #80]
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    ldp x19, x20, [sp, #16]
    ldp x21, x22, [sp, #32]
    ldp x23, x24, [sp, #48]
    ldp x25, x26, [sp, #64]
    ldp x27, x28, [sp, #80]
    ldp x29, x30, [sp], #96
    ret
.globl fC0L
fC0L:
    stp x29, x30, [sp, #-0x10]!
    mov x29, sp
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2

    ldp x29, x30, [sp], #0x10
    ret
.globl fO0L
fO0L:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2

    ldp x29, x30, [sp], #16
    ret
.globl fC1L
fC1L:
    stp x29, x30, [sp, #-0x10]!
    mov x29, sp
    stp x19, x20, [sp, #-0x10]!
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2

    ldp x19, x20, [sp], #0x10
    ldp x29, x30, [sp], #0x10
    ret
.globl fO1L
fO1L:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2

    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
.globl fC2L
fC2L:
    stp x29, x30, [sp, #-0x10]!
    mov x29, sp
    stp x21, x22, [sp, #-0x10]!
    stp x19, x20, [sp, #-0x10]!
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2

    ldp x19, x20, [sp], #0x10
    ldp x21, x22, [sp], #0x10
    ldp x29, x30, [sp], #0x10
    ret
.globl fO2L
fO2L:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2

    ldp x19, x20, [sp, #16]
    ldp x21, x22, [sp, #32]
    ldp x29, x30, [sp], #48
    ret
.globl fC3L
fC3L:
    stp x29, x30, [sp, #-0x10]!
    mov x29, sp
    stp x23, x24, [sp, #-0x10]!
    stp x21, x22, [sp, #-0x10]!
    stp x19, x20, [sp, #-0x10]!
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2

    ldp x19, x20, [sp], #0x10
    ldp x21, x22, [sp], #0x10
    ldp x23, x24, [sp], #0x10
    ldp x29, x30, [sp], #0x10
    ret
.globl fO3L
fO3L:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2

    ldp x19, x20, [sp, #16]
    ldp x21, x22, [sp, #32]
    ldp x23, x24, [sp, #48]
    ldp x29, x30, [sp], #64
    ret
.globl fC4L
fC4L:
    stp x29, x30, [sp, #-0x10]!
    mov x29, sp
    stp x25, x26, [sp, #-0x10]!
    stp x23, x24, [sp, #-0x10]!
    stp x21, x22, [sp, #-0x10]!
    stp x19, x20, [sp, #-0x10]!
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2

    ldp x19, x20, [sp], #0x10
    ldp x21, x22, [sp], #0x10
    ldp x23, x24, [sp], #0x10
    ldp x25, x26, [sp], #0x10
    ldp x29, x30, [sp], #0x10
    ret
.globl fO4L
fO4L:
    stp x29, x30, [sp, #-80]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2

    ldp x19, x20, [sp, #16]
    ldp x21, x22, [sp, #32]
    ldp x23, x24, [sp, #48]
    ldp x25, x26, [sp, #64]
    ldp x29, x30, [sp], #80
    ret
.globl fC5L
fC5L:
    stp x29, x30, [sp, #-0x10]!
    mov x29, sp
    stp x27, x28, [sp, #-0x10]!
    stp x25, x26, [sp, #-0x10]!
    stp x23, x24, [sp, #-0x10]!
    stp x21, x22, [sp, #-0x10]!
    stp x19, x20, [sp, #-0x10]!
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2

    ldp x19, x20, [sp], #0x10
    ldp x21, x22, [sp], #0x10
    ldp x23, x24, [sp], #0x10
    ldp x25, x26, [sp], #0x10
    ldp x27, x28, [sp], #0x10
    ldp x29, x30, [sp], #0x10
    ret
.globl fO5L
fO5L:
    stp x29, x30, [sp, #-96]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, x28, [sp, #80]
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2
    add x0, x0, #1
    eor x3, x0, x1
    add x0, x0, x3, lsr #3
    add x1, x1, #3
    eor x0, x0, x1
    add x0, x0, #5
    eor x3, x0, x1
    add x0, x0, x3, lsr #2

    ldp x19, x20, [sp, #16]
    ldp x21, x22, [sp, #32]
    ldp x23, x24, [sp, #48]
    ldp x25, x26, [sp, #64]
    ldp x27, x28, [sp, #80]
    ldp x29, x30, [sp], #96
    ret
