>>SOURCE FORMAT FREE
*> gbdt, BINARY variant (COBOL side study). Same algorithm, LCG draw order and checksum as
*> gbdt.cob / languages/c/gbdt.c (B=200 trees, depth D=8, F=8 features, NODES=511).
*> Differences from gbdt.cob, all about how GnuCOBOL 3.2 compiles arithmetic:
*>  - COBOL 2002 BINARY-LONG / BINARY-DOUBLE items instead of PIC S9(n) COMP-5.
*>  - Two-dimensional tables FT(tree, node) / SP(sample, feature) instead of flat tables with
*>    a COMPUTEd base + offset index: the subscript arithmetic is then generated as plain C.
*>  - node = 2*node + 1 / + 2 is written ADD NODE TO NODE, ADD 1 / 2 TO NODE.
*>  In GnuCOBOL 3.2 every COMPUTE goes through cob_decimal (GMP); ADD/SUBTRACT/MOVE/IF on
*>  native binary items compile to plain C. The LCG and the per-sample poly-hash keep a
*>  COMPUTE for the multiply and use DIVIDE ... REMAINDER for the modulus (FUNCTION MOD goes
*>  through the slower intrinsic-field path); neither has a non-decimal form in 3.2.
IDENTIFICATION DIVISION.
PROGRAM-ID. gbdt-bin.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-N            BINARY-LONG VALUE 5000.
01 WS-ARG          PIC X(16)   VALUE SPACES.
01 WS-S-LCG        BINARY-DOUBLE VALUE 42.

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
    DISPLAY 1 UPON ARGUMENT-NUMBER
    ACCEPT WS-ARG FROM ARGUMENT-VALUE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-N = FUNCTION NUMVAL(WS-ARG)
    END-IF

    *> --- Build ensemble: per tree, internal nodes (feat then thr), then leaves ---
    PERFORM VARYING WS-B FROM 1 BY 1 UNTIL WS-B > 200
       PERFORM VARYING WS-NODE FROM 1 BY 1 UNTIL WS-NODE > 255
          PERFORM LCG-STEP
          DIVIDE WS-S-LCG BY 8 GIVING WS-Q REMAINDER FT(WS-B, WS-NODE)
          PERFORM LCG-STEP
          DIVIDE WS-S-LCG BY 256 GIVING WS-Q REMAINDER TH(WS-B, WS-NODE)
       END-PERFORM
       PERFORM VARYING WS-NODE FROM 256 BY 1 UNTIL WS-NODE > 511
          PERFORM LCG-STEP
          DIVIDE WS-S-LCG BY 10 GIVING WS-Q REMAINDER LV(WS-B, WS-NODE)
       END-PERFORM
    END-PERFORM

    *> --- Draw samples: N*F draws, row-major ---
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-N
       PERFORM VARYING WS-F FROM 1 BY 1 UNTIL WS-F > 8
          PERFORM LCG-STEP
          DIVIDE WS-S-LCG BY 256 GIVING WS-Q REMAINDER SP(WS-I, WS-F)
       END-PERFORM
    END-PERFORM

    *> --- Inference (node is 0-based as in C; table subscripts are node + 1) ---
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-N
       MOVE 0 TO WS-ACC
       PERFORM VARYING WS-B FROM 1 BY 1 UNTIL WS-B > 200
          MOVE 0 TO WS-NODE
          PERFORM VARYING WS-D FROM 0 BY 1 UNTIL WS-D >= 8
             MOVE FT(WS-B, WS-NODE + 1) TO WS-FIDX
             MOVE TH(WS-B, WS-NODE + 1) TO WS-THR
             IF SP(WS-I, WS-FIDX + 1) <= WS-THR
                ADD WS-NODE TO WS-NODE
                ADD 1 TO WS-NODE
             ELSE
                ADD WS-NODE TO WS-NODE
                ADD 2 TO WS-NODE
             END-IF
          END-PERFORM
          MOVE LV(WS-B, WS-NODE + 1) TO WS-LEAF
          ADD WS-LEAF TO WS-ACC
       END-PERFORM

       *> h = (h*31 + acc + 1) % P ; total = (total + acc) % P
       COMPUTE WS-T = WS-H * 31 + WS-ACC + 1
       DIVIDE WS-T BY 1000000007 GIVING WS-Q REMAINDER WS-H
       ADD WS-ACC TO WS-TOTAL
       DIVIDE WS-TOTAL BY 1000000007 GIVING WS-Q REMAINDER WS-TOTAL
    END-PERFORM

    MOVE WS-H     TO ED-CK
    MOVE WS-N     TO ED-N
    MOVE WS-TOTAL TO ED-SEC
    DISPLAY FUNCTION TRIM(ED-CK)
    DISPLAY "gbdt(" FUNCTION TRIM(ED-N) ") = "
        FUNCTION TRIM(ED-SEC)
    STOP RUN.

*> s = (s * 1103515245 + 12345) & 0x7fffffff (2147483648 = 2^31)
LCG-STEP.
    COMPUTE WS-T = WS-S-LCG * 1103515245 + 12345
    DIVIDE WS-T BY 2147483648 GIVING WS-Q REMAINDER WS-S-LCG
    .
