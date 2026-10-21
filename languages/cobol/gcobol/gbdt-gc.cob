>>SOURCE FORMAT FREE
*> gbdt, gcobol variant (COBOL side study, GCC 15 front end). Same algorithm, draw order and checksum
*> as gbdt-bin.cob. Differences, all about which statements gcobol 15 compiles to inline machine code:
*>  - every operand of a hot ADD/MULTIPLY/DIVIDE/MOVE/IF is a BINARY-LONG/BINARY-DOUBLE variable
*>    (named constants K-xxx instead of literals) and every subscript is a plain variable;
*>  - no COMPUTE, no FUNCTION, no subscript expressions: the tree is walked with 1-based node
*>    indices (children 2j and 2j+1) and the feature column is formed in a variable first.
IDENTIFICATION DIVISION.
PROGRAM-ID. gbdt-gc.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-N            BINARY-LONG VALUE 5000.
01 WS-ARG          PIC X(16)   VALUE SPACES.
01 WS-S-LCG        BINARY-DOUBLE VALUE 42.
01 K-ZERO          BINARY-LONG VALUE 0.
01 K-ONE           BINARY-LONG VALUE 1.
01 K-TWO           BINARY-LONG VALUE 2.
01 K-EIGHT         BINARY-LONG VALUE 8.
01 K-256           BINARY-LONG VALUE 256.
01 K-10            BINARY-LONG VALUE 10.
01 K-255           BINARY-LONG VALUE 255.
01 K-511           BINARY-LONG VALUE 511.
01 K-200           BINARY-LONG VALUE 200.
01 K-LCG-A         BINARY-DOUBLE VALUE 1103515245.
01 K-LCG-C         BINARY-DOUBLE VALUE 12345.
01 K-LCG-M         BINARY-DOUBLE VALUE 2147483648.
01 K-31            BINARY-DOUBLE VALUE 31.
01 K-P             BINARY-DOUBLE VALUE 1000000007.

01 FEAT-T.
   05 FT-TREE      OCCURS 200 TIMES.
      10 FT        BINARY-LONG OCCURS 511 TIMES.
01 THR-T.
   05 TH-TREE      OCCURS 200 TIMES.
      10 TH        BINARY-LONG OCCURS 511 TIMES.
01 LEAF-T.
   05 LV-TREE      OCCURS 200 TIMES.
      10 LV        BINARY-LONG OCCURS 511 TIMES.
*> sample[N][F], sized for n2 = 20000
01 SAMP-T.
   05 SP-ROW       OCCURS 20000 TIMES.
      10 SP        BINARY-LONG OCCURS 8 TIMES.

01 WS-B            BINARY-LONG.
01 WS-NODE         BINARY-LONG.
01 WS-I            BINARY-LONG.
01 WS-F            BINARY-LONG.
01 WS-D            BINARY-LONG.
01 WS-FIDX         BINARY-LONG.
01 WS-THR          BINARY-LONG.
01 WS-LEAF         BINARY-LONG.
01 WS-T            BINARY-DOUBLE.
01 WS-Q            BINARY-DOUBLE.
01 WS-ACC          BINARY-DOUBLE.
01 WS-H            BINARY-DOUBLE VALUE 0.
01 WS-TOTAL        BINARY-DOUBLE VALUE 0.

01 ED-CK           PIC -(18)9.
01 ED-N            PIC Z(8)9.
01 ED-SEC          PIC -(18)9.

PROCEDURE DIVISION.
MAIN-PARA.
    ACCEPT WS-ARG FROM COMMAND-LINE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-N = FUNCTION NUMVAL(WS-ARG)
    END-IF

    *> --- Build ensemble: per tree, internal nodes (feat then thr), then leaves (1-based node index) ---
    PERFORM VARYING WS-B FROM K-ONE BY K-ONE UNTIL WS-B > K-200
       PERFORM VARYING WS-NODE FROM K-ONE BY K-ONE UNTIL WS-NODE > K-255
          PERFORM LCG-STEP
          DIVIDE WS-S-LCG BY K-EIGHT GIVING WS-Q REMAINDER FT(WS-B, WS-NODE)
          PERFORM LCG-STEP
          DIVIDE WS-S-LCG BY K-256 GIVING WS-Q REMAINDER TH(WS-B, WS-NODE)
       END-PERFORM
       PERFORM VARYING WS-NODE FROM K-256 BY K-ONE UNTIL WS-NODE > K-511
          PERFORM LCG-STEP
          DIVIDE WS-S-LCG BY K-10 GIVING WS-Q REMAINDER LV(WS-B, WS-NODE)
       END-PERFORM
    END-PERFORM

    *> --- Draw samples: N*F draws, row-major ---
    PERFORM VARYING WS-I FROM K-ONE BY K-ONE UNTIL WS-I > WS-N
       PERFORM VARYING WS-F FROM K-ONE BY K-ONE UNTIL WS-F > K-EIGHT
          PERFORM LCG-STEP
          DIVIDE WS-S-LCG BY K-256 GIVING WS-Q REMAINDER SP(WS-I, WS-F)
       END-PERFORM
    END-PERFORM

    *> --- Inference: node j is 1-based (C node k = j - 1): children 2j (<=) and 2j + 1 ---
    PERFORM VARYING WS-I FROM K-ONE BY K-ONE UNTIL WS-I > WS-N
       MOVE K-ZERO TO WS-ACC
       PERFORM VARYING WS-B FROM K-ONE BY K-ONE UNTIL WS-B > K-200
          MOVE K-ONE TO WS-NODE
          PERFORM VARYING WS-D FROM K-ZERO BY K-ONE UNTIL WS-D >= K-EIGHT
             MOVE FT(WS-B, WS-NODE) TO WS-FIDX
             ADD K-ONE TO WS-FIDX
             MOVE TH(WS-B, WS-NODE) TO WS-THR
             ADD WS-NODE TO WS-NODE
             IF SP(WS-I, WS-FIDX) > WS-THR
                ADD K-ONE TO WS-NODE
             END-IF
          END-PERFORM
          MOVE LV(WS-B, WS-NODE) TO WS-LEAF
          ADD WS-LEAF TO WS-ACC
       END-PERFORM

       *> h = (h*31 + acc + 1) % P ; total = (total + acc) % P
       MULTIPLY WS-H BY K-31 GIVING WS-T
       ADD WS-ACC TO WS-T
       ADD K-ONE TO WS-T
       DIVIDE WS-T BY K-P GIVING WS-Q REMAINDER WS-H
       ADD WS-ACC TO WS-TOTAL
       DIVIDE WS-TOTAL BY K-P GIVING WS-Q REMAINDER WS-TOTAL
    END-PERFORM

    MOVE WS-H     TO ED-CK
    MOVE WS-N     TO ED-N
    MOVE WS-TOTAL TO ED-SEC
    DISPLAY FUNCTION TRIM(ED-CK)
    DISPLAY "gbdt(" FUNCTION TRIM(ED-N) ") = "
        FUNCTION TRIM(ED-SEC)
    STOP RUN.

*> s = (s * 1103515245 + 12345) & 0x7fffffff
LCG-STEP.
    MULTIPLY WS-S-LCG BY K-LCG-A GIVING WS-T
    ADD K-LCG-C TO WS-T
    DIVIDE WS-T BY K-LCG-M GIVING WS-Q REMAINDER WS-S-LCG
    .
