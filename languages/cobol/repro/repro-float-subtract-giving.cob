>>SOURCE FORMAT FREE
*> Minimal reproducer for a gcobol 15.2 (gcobol-15=15.2.0-16ubuntu1, aarch64) miscompile: `SUBTRACT a FROM b GIVING c`
*> on FLOAT-LONG items stores 0 in c, and so does a subtraction inside a COMPUTE expression (this is why the
*> natural mandelbrot.cob gets a wrong checksum on 15.2). Expected output: sub giving=0.890625 and compute=0.890625
*> (both correct in gcobol-16=16.2.0-3).
*> Build: gcobol-15 -O2 -ffree-form repro-float-subtract-giving.cob -o x. Nothing has been reported upstream.
IDENTIFICATION DIVISION.
PROGRAM-ID. q.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 TR FLOAT-LONG VALUE 1.890625.
01 TI FLOAT-LONG VALUE 1.
01 ZR FLOAT-LONG VALUE 0.
01 CR FLOAT-LONG VALUE -1.375.
01 IA BINARY-LONG VALUE 7.
01 IB BINARY-LONG VALUE 3.
01 IC BINARY-LONG.
PROCEDURE DIVISION.
    SUBTRACT TI FROM TR GIVING ZR
    DISPLAY "sub giving=" ZR
    COMPUTE ZR = TR - TI
    DISPLAY "compute=" ZR
    MOVE TR TO ZR
    SUBTRACT TI FROM ZR
    DISPLAY "sub from=" ZR
    ADD CR TO ZR
    DISPLAY "add to=" ZR
    SUBTRACT IB FROM IA GIVING IC
    DISPLAY "int sub giving=" IC
    STOP RUN.
