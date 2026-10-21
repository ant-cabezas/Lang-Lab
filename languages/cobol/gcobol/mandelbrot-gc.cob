>>SOURCE FORMAT FREE
*> mandelbrot, gcobol variant (COBOL side study, GCC 15 front end). Same algorithm as mandelbrot.cob (count in-set
*> pixels over an N x N grid of [-1.5,0.5]x[-1.0,1.0], FMA-proof t = zr*zi; zi = t + t + ci). The loop is written as
*> single-operation MULTIPLY / ADD / SUBTRACT / DIVIDE statements on FLOAT-LONG (IEEE double) items with named
*> constants, the form gcobol's float arithmetic is routed through its library for (see the study notes: gcobol has
*> NO inline path for floating point in GCC 15 or 16, every float operation is a libgcobol call).
*> STATUS: passes the checksum gate on gcobol 15.2 and 16.2. The first draft of this file failed (n=128 gave 7402,
*> expected 6518) because of a gcobol 15.2 miscompile: `SUBTRACT a FROM b GIVING c` on FLOAT-LONG items stores 0
*> (fixed in 16.2). The workaround, MOVE b TO c then SUBTRACT a FROM c, is used below. Float arithmetic has no inline
*> path in gcobol 15 or 16: every operation is a libgcobol call, so this cell measures library call overhead.
IDENTIFICATION DIVISION.
PROGRAM-ID. mandelbrot-gc.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-N            BINARY-LONG VALUE 128.
01 WS-ARG          PIC X(16)         VALUE SPACES.
01 WS-COUNT        BINARY-DOUBLE VALUE 0.
01 WS-X            BINARY-LONG.
01 WS-Y            BINARY-LONG.
01 WS-I            BINARY-LONG.
01 K-ZERO          BINARY-LONG VALUE 0.
01 K-ONE           BINARY-LONG VALUE 1.
01 K-50            BINARY-LONG VALUE 50.
01 K-ZF            FLOAT-LONG VALUE 0.
01 K-2F            FLOAT-LONG VALUE 2.
01 K-1F            FLOAT-LONG VALUE 1.
01 K-15F           FLOAT-LONG VALUE 1.5.
01 K-4F            FLOAT-LONG VALUE 4.
01 WS-FX           FLOAT-LONG.
01 WS-CI           FLOAT-LONG.
01 WS-CR           FLOAT-LONG.
01 WS-ZR           FLOAT-LONG.
01 WS-ZI           FLOAT-LONG.
01 WS-TR           FLOAT-LONG.
01 WS-TI           FLOAT-LONG.
01 WS-T            FLOAT-LONG.
01 WS-S            FLOAT-LONG.
01 WS-ND           FLOAT-LONG.
01 ED-CK           PIC -(18)9.
01 ED-N            PIC Z(8)9.
PROCEDURE DIVISION.
MAIN-PARA.
    ACCEPT WS-ARG FROM COMMAND-LINE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-N = FUNCTION NUMVAL(WS-ARG)
    END-IF
    MOVE WS-N TO WS-ND

    PERFORM VARYING WS-Y FROM K-ZERO BY K-ONE UNTIL WS-Y >= WS-N
       MOVE WS-Y TO WS-FX
       MULTIPLY WS-FX BY K-2F GIVING WS-CI
       DIVIDE WS-CI BY WS-ND GIVING WS-CI
       SUBTRACT K-1F FROM WS-CI
       PERFORM VARYING WS-X FROM K-ZERO BY K-ONE UNTIL WS-X >= WS-N
          MOVE WS-X TO WS-FX
          MULTIPLY WS-FX BY K-2F GIVING WS-CR
          DIVIDE WS-CR BY WS-ND GIVING WS-CR
          SUBTRACT K-15F FROM WS-CR
          MOVE K-ZF TO WS-ZR
          MOVE K-ZF TO WS-ZI
          MOVE K-ZF TO WS-TR
          MOVE K-ZF TO WS-TI
          MOVE K-ZERO TO WS-I
          MOVE K-ZF TO WS-S
          PERFORM UNTIL WS-I >= K-50 OR WS-S > K-4F
             MULTIPLY WS-ZR BY WS-ZI GIVING WS-T
             ADD WS-T WS-T GIVING WS-ZI
             ADD WS-CI TO WS-ZI
             MOVE WS-TR TO WS-ZR
             SUBTRACT WS-TI FROM WS-ZR
             ADD WS-CR TO WS-ZR
             MULTIPLY WS-ZR BY WS-ZR GIVING WS-TR
             MULTIPLY WS-ZI BY WS-ZI GIVING WS-TI
             ADD WS-TR WS-TI GIVING WS-S
             ADD K-ONE TO WS-I
          END-PERFORM
          IF WS-S <= K-4F
             ADD K-ONE TO WS-COUNT
          END-IF
       END-PERFORM
    END-PERFORM

    MOVE WS-COUNT TO ED-CK
    MOVE WS-N     TO ED-N
    DISPLAY FUNCTION TRIM(ED-CK)
    DISPLAY "mandelbrot(" FUNCTION TRIM(ED-N) ")"
    STOP RUN.
