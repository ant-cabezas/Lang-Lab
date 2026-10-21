>>SOURCE FORMAT FREE
*> blur, gcobol variant (COBOL side study, GCC 15 front end). Same algorithm as blur.cob: LCG image, 3x3
*> Gaussian [1,2,1;2,4,2;1,2,1]/16, PASSES=4 double-buffered passes, clamp (edge-replication) borders,
*> integer floor division by 16, poly-hash of the final image. Written for gcobol's inline-arithmetic
*> rules: BINARY-LONG/BINARY-DOUBLE items only, every operand of a hot ADD/MULTIPLY/DIVIDE/MOVE/IF is a
*> variable (named constants K-xxx), every subscript is a plain variable (flat indices are built with
*> MULTIPLY/ADD first, the kernel index is a running counter), no COMPUTE/FUNCTION. The two image buffers
*> are BUF(1, *) and BUF(2, *); SRC/DST select them and are swapped each pass.
IDENTIFICATION DIVISION.
PROGRAM-ID. blur-gc.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-N            BINARY-LONG VALUE 256.
01 WS-NM1          BINARY-LONG.
01 WS-NN           BINARY-LONG.
01 WS-ARG          PIC X(16)         VALUE SPACES.
01 BUFS.
   05 BUF-ROW      OCCURS 2 TIMES.
      10 BUF       BINARY-LONG OCCURS 65536 TIMES.
01 KERN-T.
   05 KW           BINARY-LONG OCCURS 9 TIMES.
01 K-ZERO          BINARY-LONG VALUE 0.
01 K-ONE           BINARY-LONG VALUE 1.
01 K-TWO           BINARY-LONG VALUE 2.
01 K-FOUR          BINARY-LONG VALUE 4.
01 K-NEG1          BINARY-LONG VALUE -1.
01 K-PASSES        BINARY-LONG VALUE 4.
01 K-16            BINARY-DOUBLE VALUE 16.
01 K-256           BINARY-DOUBLE VALUE 256.
01 K-LCG-A         BINARY-DOUBLE VALUE 1103515245.
01 K-LCG-C         BINARY-DOUBLE VALUE 12345.
01 K-LCG-M         BINARY-DOUBLE VALUE 2147483648.
01 K-31            BINARY-DOUBLE VALUE 31.
01 K-P             BINARY-DOUBLE VALUE 1000000007.
01 WS-S            BINARY-DOUBLE VALUE 42.
01 WS-T            BINARY-DOUBLE.
01 WS-Q            BINARY-DOUBLE.
01 WS-PROD         BINARY-DOUBLE.
01 WS-ACC          BINARY-DOUBLE.
01 WS-H            BINARY-DOUBLE VALUE 0.
01 WS-PASS         BINARY-LONG.
01 WS-I            BINARY-LONG.
01 WS-J            BINARY-LONG.
01 WS-DI           BINARY-LONG.
01 WS-DJ           BINARY-LONG.
01 WS-NI           BINARY-LONG.
01 WS-NJ           BINARY-LONG.
01 WS-KIDX         BINARY-LONG.
01 WS-SIDX         BINARY-LONG.
01 WS-DIDX         BINARY-LONG.
01 WS-K            BINARY-LONG.
01 WS-VAL          BINARY-LONG.
01 WS-SRC          BINARY-LONG VALUE 1.
01 WS-DST          BINARY-LONG VALUE 2.
01 WS-SWAP         BINARY-LONG.
01 WS-PVAL         BINARY-DOUBLE.
01 ED-CK           PIC -(18)9.
01 ED-N            PIC Z(8)9.
PROCEDURE DIVISION.
MAIN-PARA.
    ACCEPT WS-ARG FROM COMMAND-LINE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-N = FUNCTION NUMVAL(WS-ARG)
    END-IF
    MULTIPLY WS-N BY WS-N GIVING WS-NN
    MOVE WS-N TO WS-NM1
    SUBTRACT K-ONE FROM WS-NM1

    *> kernel {1,2,1,2,4,2,1,2,1}
    MOVE K-ONE  TO KW(1)  MOVE K-TWO  TO KW(2)  MOVE K-ONE TO KW(3)
    MOVE K-TWO  TO KW(4)  MOVE K-FOUR TO KW(5)  MOVE K-TWO TO KW(6)
    MOVE K-ONE  TO KW(7)  MOVE K-TWO  TO KW(8)  MOVE K-ONE TO KW(9)

    *> generate source image into BUF(1, *)
    PERFORM VARYING WS-K FROM K-ONE BY K-ONE UNTIL WS-K > WS-NN
       MULTIPLY WS-S BY K-LCG-A GIVING WS-T
       ADD K-LCG-C TO WS-T
       DIVIDE WS-T BY K-LCG-M GIVING WS-Q REMAINDER WS-S
       DIVIDE WS-S BY K-256 GIVING WS-Q REMAINDER BUF(WS-SRC, WS-K)
    END-PERFORM

    PERFORM VARYING WS-PASS FROM K-ZERO BY K-ONE UNTIL WS-PASS >= K-PASSES
       PERFORM ONE-PASS
       MOVE WS-SRC TO WS-SWAP
       MOVE WS-DST TO WS-SRC
       MOVE WS-SWAP TO WS-DST
    END-PERFORM

    *> poly-hash the final image (source buffer after the swaps)
    MOVE K-ZERO TO WS-H
    PERFORM VARYING WS-K FROM K-ONE BY K-ONE UNTIL WS-K > WS-NN
       MOVE BUF(WS-SRC, WS-K) TO WS-PVAL
       MULTIPLY WS-H BY K-31 GIVING WS-T
       ADD WS-PVAL TO WS-T
       DIVIDE WS-T BY K-P GIVING WS-Q REMAINDER WS-H
    END-PERFORM

    MOVE WS-H TO ED-CK
    MOVE WS-N TO ED-N
    DISPLAY FUNCTION TRIM(ED-CK)
    DISPLAY "blur(" FUNCTION TRIM(ED-N) ")"
    STOP RUN.

ONE-PASS.
    MOVE K-ONE TO WS-DIDX
    PERFORM VARYING WS-I FROM K-ZERO BY K-ONE UNTIL WS-I >= WS-N
       PERFORM VARYING WS-J FROM K-ZERO BY K-ONE UNTIL WS-J >= WS-N
          MOVE K-ZERO TO WS-ACC
          MOVE K-ONE TO WS-KIDX
          PERFORM VARYING WS-DI FROM K-NEG1 BY K-ONE UNTIL WS-DI > K-ONE
             MOVE WS-I TO WS-NI
             ADD WS-DI TO WS-NI
             IF WS-NI < K-ZERO
                MOVE K-ZERO TO WS-NI
             ELSE
                IF WS-NI >= WS-N
                   MOVE WS-NM1 TO WS-NI
                END-IF
             END-IF
             PERFORM VARYING WS-DJ FROM K-NEG1 BY K-ONE UNTIL WS-DJ > K-ONE
                MOVE WS-J TO WS-NJ
                ADD WS-DJ TO WS-NJ
                IF WS-NJ < K-ZERO
                   MOVE K-ZERO TO WS-NJ
                ELSE
                   IF WS-NJ >= WS-N
                      MOVE WS-NM1 TO WS-NJ
                   END-IF
                END-IF
                MULTIPLY WS-NI BY WS-N GIVING WS-SIDX
                ADD WS-NJ TO WS-SIDX
                ADD K-ONE TO WS-SIDX
                MOVE BUF(WS-SRC, WS-SIDX) TO WS-VAL
                MULTIPLY KW(WS-KIDX) BY WS-VAL GIVING WS-PROD
                ADD WS-PROD TO WS-ACC
                ADD K-ONE TO WS-KIDX
             END-PERFORM
          END-PERFORM
          DIVIDE WS-ACC BY K-16 GIVING WS-PROD
          MOVE WS-PROD TO BUF(WS-DST, WS-DIDX)
          ADD K-ONE TO WS-DIDX
       END-PERFORM
    END-PERFORM.
