>>SOURCE FORMAT FREE
*> viterbi, BINARY variant (COBOL side study). Same HMM (S=8 states, ALPHA=4), LCG draw
*> order (trans, emit, obs), max-plus trellis with STRICT > (lowest index wins), backtrace
*> and checksum as viterbi.cob / languages/c/viterbi.c. Differences, all about how
*> GnuCOBOL 3.2 compiles arithmetic (every COMPUTE goes through cob_decimal / GMP;
*> ADD/SUBTRACT/MOVE/IF on native binary items are plain C):
*>  - COBOL 2002 BINARY-LONG / BINARY-DOUBLE items.
*>  - Two-dimensional tables TR(i, j), EM(j, sym), BK(t, j) and VIT(buffer, i) instead of
*>    flat tables indexed by a COMPUTEd i*S + j: the subscript arithmetic is plain C.
*>  - sc = prev[i] + trans[i][j] + emit[j][obs[t]] is a MOVE and two ADDs.
*>  - The LCG and the poly-hash keep a COMPUTE for the multiply and use DIVIDE ... REMAINDER
*>    for the modulus.
*> Trellis scores grow by at most 200 per step (<= 16,000,200 at T = 80000), so BINARY-LONG
*> holds trans/emit and the per-step addends; the column values stay BINARY-DOUBLE as in C.
IDENTIFICATION DIVISION.
PROGRAM-ID. viterbi-bin.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-T            BINARY-LONG VALUE 20000.
01 WS-ARG          PIC X(16)   VALUE SPACES.
01 WS-S-LCG        BINARY-DOUBLE VALUE 42.
01 WS-LT           BINARY-DOUBLE.
01 WS-Q            BINARY-DOUBLE.

01 TRANS-T.
   05 TR-ROW       OCCURS 8 TIMES.
      10 TR        BINARY-LONG OCCURS 8 TIMES.
01 EMIT-T.
   05 EM-ROW       OCCURS 8 TIMES.
      10 EM        BINARY-LONG OCCURS 4 TIMES.
*> obs[T], back[T][S], path[T]: sized for n2 = 80000
01 OBS-T.
   05 OB           BINARY-LONG OCCURS 80000 TIMES.
01 BACK-T.
   05 BK-ROW       OCCURS 80000 TIMES.
      10 BK        BINARY-LONG OCCURS 8 TIMES.
01 PATH-T.
   05 PT           BINARY-LONG OCCURS 80000 TIMES.
*> VIT(1, *) and VIT(2, *) are the two column buffers; PREV/NEXT select them.
01 VIT-T.
   05 VIT-BUF      OCCURS 2 TIMES.
      10 VIT       BINARY-DOUBLE OCCURS 8 TIMES.

01 WS-PREV         BINARY-LONG VALUE 1.
01 WS-NEXT         BINARY-LONG VALUE 2.
01 WS-SWAP         BINARY-LONG.
01 WS-X            BINARY-LONG.
01 WS-I            BINARY-LONG.
01 WS-J            BINARY-LONG.
01 WS-TI           BINARY-LONG.
01 WS-SYM          BINARY-LONG.
01 WS-E-VAL        BINARY-LONG.
01 WS-TR-VAL       BINARY-LONG.
01 WS-BI           BINARY-LONG.
01 WS-BF           BINARY-LONG.
01 WS-CUR          BINARY-LONG.
01 WS-BEST         BINARY-DOUBLE.
01 WS-SC           BINARY-DOUBLE.
01 WS-H            BINARY-DOUBLE VALUE 0.
01 WS-SEC          BINARY-DOUBLE.

01 ED-CK           PIC -(18)9.
01 ED-N            PIC Z(8)9.
01 ED-SEC          PIC -(18)9.

PROCEDURE DIVISION.
MAIN-PARA.
    DISPLAY 1 UPON ARGUMENT-NUMBER
    ACCEPT WS-ARG FROM ARGUMENT-VALUE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-T = FUNCTION NUMVAL(WS-ARG)
    END-IF

    *> 1. trans[i][j] = s % 100 + 1, row-major (same order as the flat C table)
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 8
       PERFORM VARYING WS-J FROM 1 BY 1 UNTIL WS-J > 8
          PERFORM LCG-STEP
          DIVIDE WS-S-LCG BY 100 GIVING WS-Q REMAINDER TR(WS-I, WS-J)
          ADD 1 TO TR(WS-I, WS-J)
       END-PERFORM
    END-PERFORM
    *> 2. emit[j][sym] = s % 100 + 1
    PERFORM VARYING WS-J FROM 1 BY 1 UNTIL WS-J > 8
       PERFORM VARYING WS-X FROM 1 BY 1 UNTIL WS-X > 4
          PERFORM LCG-STEP
          DIVIDE WS-S-LCG BY 100 GIVING WS-Q REMAINDER EM(WS-J, WS-X)
          ADD 1 TO EM(WS-J, WS-X)
       END-PERFORM
    END-PERFORM
    *> 3. obs[t] = s % 4
    PERFORM VARYING WS-TI FROM 1 BY 1 UNTIL WS-TI > WS-T
       PERFORM LCG-STEP
       DIVIDE WS-S-LCG BY 4 GIVING WS-Q REMAINDER OB(WS-TI)
    END-PERFORM

    *> 4. column 0: vit_prev[j] = emit[j][obs[0]]
    MOVE OB(1) TO WS-SYM
    PERFORM VARYING WS-J FROM 1 BY 1 UNTIL WS-J > 8
       MOVE EM(WS-J, WS-SYM + 1) TO WS-E-VAL
       MOVE WS-E-VAL TO WS-SC
       MOVE WS-SC TO VIT(WS-PREV, WS-J)
    END-PERFORM

    *> 5. forward trellis, t = 1 .. T-1 (COBOL row t + 1)
    PERFORM VARYING WS-TI FROM 2 BY 1 UNTIL WS-TI > WS-T
       MOVE OB(WS-TI) TO WS-SYM
       PERFORM VARYING WS-J FROM 1 BY 1 UNTIL WS-J > 8
          MOVE -1 TO WS-BEST
          MOVE 0  TO WS-BI
          MOVE EM(WS-J, WS-SYM + 1) TO WS-E-VAL
          PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 8
             MOVE VIT(WS-PREV, WS-I) TO WS-SC
             MOVE TR(WS-I, WS-J) TO WS-TR-VAL
             ADD WS-TR-VAL TO WS-SC
             ADD WS-E-VAL TO WS-SC
             IF WS-SC > WS-BEST
                MOVE WS-SC TO WS-BEST
                MOVE WS-I  TO WS-BI
             END-IF
          END-PERFORM
          MOVE WS-BEST TO VIT(WS-NEXT, WS-J)
          *> bi is 1-based here; back[] stores the 0-based state as in C
          SUBTRACT 1 FROM WS-BI
          MOVE WS-BI TO BK(WS-TI, WS-J)
       END-PERFORM
       MOVE WS-PREV TO WS-SWAP
       MOVE WS-NEXT TO WS-PREV
       MOVE WS-SWAP TO WS-NEXT
    END-PERFORM

    *> 6. final state (STRICT > -> lowest j wins); bf is 0-based
    MOVE 0 TO WS-BF
    MOVE VIT(WS-PREV, 1) TO WS-BEST
    PERFORM VARYING WS-J FROM 2 BY 1 UNTIL WS-J > 8
       MOVE VIT(WS-PREV, WS-J) TO WS-SC
       IF WS-SC > WS-BEST
          MOVE WS-SC TO WS-BEST
          MOVE WS-J TO WS-BF
          SUBTRACT 1 FROM WS-BF
       END-IF
    END-PERFORM

    *> 7. backtrace: path[T-1] = bf; path[t] = back[t+1][path[t+1]]
    MOVE WS-BF TO PT(WS-T)
    MOVE WS-T TO WS-TI
    SUBTRACT 1 FROM WS-TI
    PERFORM UNTIL WS-TI < 1
       MOVE PT(WS-TI + 1) TO WS-CUR
       MOVE BK(WS-TI + 1, WS-CUR + 1) TO PT(WS-TI)
       SUBTRACT 1 FROM WS-TI
    END-PERFORM

    *> 8. checksum h = (h*31 + path[t] + 1) % P
    MOVE 0 TO WS-H
    PERFORM VARYING WS-TI FROM 1 BY 1 UNTIL WS-TI > WS-T
       MOVE PT(WS-TI) TO WS-CUR
       ADD 1 TO WS-CUR
       COMPUTE WS-LT = WS-H * 31 + WS-CUR
       DIVIDE WS-LT BY 1000000007 GIVING WS-Q REMAINDER WS-H
    END-PERFORM

    *> 9. secondary = vit_prev[bf] % P
    MOVE VIT(WS-PREV, WS-BF + 1) TO WS-SEC
    DIVIDE WS-SEC BY 1000000007 GIVING WS-Q REMAINDER WS-SEC

    MOVE WS-H   TO ED-CK
    MOVE WS-T   TO ED-N
    MOVE WS-SEC TO ED-SEC
    DISPLAY FUNCTION TRIM(ED-CK)
    DISPLAY "viterbi(" FUNCTION TRIM(ED-N) ") = "
        FUNCTION TRIM(ED-SEC)
    STOP RUN.

*> s = (s * 1103515245 + 12345) & 0x7fffffff (2147483648 = 2^31)
LCG-STEP.
    COMPUTE WS-LT = WS-S-LCG * 1103515245 + 12345
    DIVIDE WS-LT BY 2147483648 GIVING WS-Q REMAINDER WS-S-LCG
    .
