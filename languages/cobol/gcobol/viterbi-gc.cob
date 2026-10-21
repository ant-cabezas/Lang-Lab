>>SOURCE FORMAT FREE
*> viterbi, gcobol variant (COBOL side study, GCC 15 front end). Same HMM (S=8 states, ALPHA=4), LCG draw
*> order, STRICT > max-plus trellis, backtrace and checksum as viterbi-bin.cob. Written for gcobol's
*> inline-arithmetic rules: every operand of a hot ADD/SUBTRACT/MULTIPLY/DIVIDE/MOVE/IF is a BINARY-LONG /
*> BINARY-DOUBLE variable (named constants K-xxx, no literals), every subscript is a plain variable, no
*> COMPUTE/FUNCTION. Symbols and states are therefore stored 1-based (obs+1, back = state+1, path = state+1;
*> the checksum term path+1 is then the stored path value itself).
IDENTIFICATION DIVISION.
PROGRAM-ID. viterbi-gc.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-T            BINARY-LONG VALUE 20000.
01 WS-ARG          PIC X(16)   VALUE SPACES.
01 WS-S-LCG        BINARY-DOUBLE VALUE 42.
01 WS-LT           BINARY-DOUBLE.
01 WS-Q            BINARY-DOUBLE.
01 K-ZERO          BINARY-LONG VALUE 0.
01 K-ONE           BINARY-LONG VALUE 1.
01 K-TWO           BINARY-LONG VALUE 2.
01 K-FOUR          BINARY-LONG VALUE 4.
01 K-EIGHT         BINARY-LONG VALUE 8.
01 K-100           BINARY-DOUBLE VALUE 100.
01 K-4D            BINARY-DOUBLE VALUE 4.
01 K-NEG1          BINARY-DOUBLE VALUE -1.
01 K-LCG-A         BINARY-DOUBLE VALUE 1103515245.
01 K-LCG-C         BINARY-DOUBLE VALUE 12345.
01 K-LCG-M         BINARY-DOUBLE VALUE 2147483648.
01 K-31            BINARY-DOUBLE VALUE 31.
01 K-P             BINARY-DOUBLE VALUE 1000000007.

01 TRANS-T.
   05 TR-ROW       OCCURS 8 TIMES.
      10 TR        BINARY-LONG OCCURS 8 TIMES.
01 EMIT-T.
   05 EM-ROW       OCCURS 8 TIMES.
      10 EM        BINARY-LONG OCCURS 4 TIMES.
*> obs[T] (1-based symbol), back[T][S] (1-based state), path[T] (1-based state): sized for n2 = 80000
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
01 WS-TI0          BINARY-LONG.
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
    ACCEPT WS-ARG FROM COMMAND-LINE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-T = FUNCTION NUMVAL(WS-ARG)
    END-IF

    *> 1. trans[i][j] = s % 100 + 1, row-major
    PERFORM VARYING WS-I FROM K-ONE BY K-ONE UNTIL WS-I > K-EIGHT
       PERFORM VARYING WS-J FROM K-ONE BY K-ONE UNTIL WS-J > K-EIGHT
          PERFORM LCG-STEP
          DIVIDE WS-S-LCG BY K-100 GIVING WS-Q REMAINDER TR(WS-I, WS-J)
          ADD K-ONE TO TR(WS-I, WS-J)
       END-PERFORM
    END-PERFORM
    *> 2. emit[j][sym] = s % 100 + 1
    PERFORM VARYING WS-J FROM K-ONE BY K-ONE UNTIL WS-J > K-EIGHT
       PERFORM VARYING WS-X FROM K-ONE BY K-ONE UNTIL WS-X > K-FOUR
          PERFORM LCG-STEP
          DIVIDE WS-S-LCG BY K-100 GIVING WS-Q REMAINDER EM(WS-J, WS-X)
          ADD K-ONE TO EM(WS-J, WS-X)
       END-PERFORM
    END-PERFORM
    *> 3. obs[t] = s % 4 (stored +1)
    PERFORM VARYING WS-TI FROM K-ONE BY K-ONE UNTIL WS-TI > WS-T
       PERFORM LCG-STEP
       DIVIDE WS-S-LCG BY K-4D GIVING WS-Q REMAINDER OB(WS-TI)
       ADD K-ONE TO OB(WS-TI)
    END-PERFORM

    *> 4. column 0: vit_prev[j] = emit[j][obs[0]]
    MOVE OB(K-ONE) TO WS-SYM
    PERFORM VARYING WS-J FROM K-ONE BY K-ONE UNTIL WS-J > K-EIGHT
       MOVE EM(WS-J, WS-SYM) TO WS-E-VAL
       MOVE WS-E-VAL TO WS-SC
       MOVE WS-SC TO VIT(WS-PREV, WS-J)
    END-PERFORM

    *> 5. forward trellis, t = 1 .. T-1 (row t + 1)
    PERFORM VARYING WS-TI FROM K-TWO BY K-ONE UNTIL WS-TI > WS-T
       MOVE OB(WS-TI) TO WS-SYM
       PERFORM VARYING WS-J FROM K-ONE BY K-ONE UNTIL WS-J > K-EIGHT
          MOVE K-NEG1 TO WS-BEST
          MOVE K-ZERO TO WS-BI
          MOVE EM(WS-J, WS-SYM) TO WS-E-VAL
          PERFORM VARYING WS-I FROM K-ONE BY K-ONE UNTIL WS-I > K-EIGHT
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
          MOVE WS-BI TO BK(WS-TI, WS-J)
       END-PERFORM
       MOVE WS-PREV TO WS-SWAP
       MOVE WS-NEXT TO WS-PREV
       MOVE WS-SWAP TO WS-NEXT
    END-PERFORM

    *> 6. final state (STRICT > -> lowest j wins); bf is 1-based
    MOVE K-ONE TO WS-BF
    MOVE VIT(WS-PREV, K-ONE) TO WS-BEST
    PERFORM VARYING WS-J FROM K-TWO BY K-ONE UNTIL WS-J > K-EIGHT
       MOVE VIT(WS-PREV, WS-J) TO WS-SC
       IF WS-SC > WS-BEST
          MOVE WS-SC TO WS-BEST
          MOVE WS-J TO WS-BF
       END-IF
    END-PERFORM

    *> 7. backtrace: PT(T) = bf; PT(i) = BK(i + 1, PT(i + 1))   (TI0 = i, TI = i + 1)
    MOVE WS-BF TO PT(WS-T)
    MOVE WS-T TO WS-TI
    MOVE WS-T TO WS-TI0
    SUBTRACT K-ONE FROM WS-TI0
    PERFORM UNTIL WS-TI0 < K-ONE
       MOVE PT(WS-TI) TO WS-CUR
       MOVE BK(WS-TI, WS-CUR) TO PT(WS-TI0)
       SUBTRACT K-ONE FROM WS-TI
       SUBTRACT K-ONE FROM WS-TI0
    END-PERFORM

    *> 8. checksum h = (h*31 + path[t] + 1) % P   (stored path value = path[t] + 1)
    MOVE K-ZERO TO WS-H
    PERFORM VARYING WS-TI FROM K-ONE BY K-ONE UNTIL WS-TI > WS-T
       MOVE PT(WS-TI) TO WS-CUR
       MULTIPLY WS-H BY K-31 GIVING WS-LT
       ADD WS-CUR TO WS-LT
       DIVIDE WS-LT BY K-P GIVING WS-Q REMAINDER WS-H
    END-PERFORM

    *> 9. secondary = vit_prev[bf] % P
    MOVE VIT(WS-PREV, WS-BF) TO WS-SEC
    DIVIDE WS-SEC BY K-P GIVING WS-Q REMAINDER WS-SEC

    MOVE WS-H   TO ED-CK
    MOVE WS-T   TO ED-N
    MOVE WS-SEC TO ED-SEC
    DISPLAY FUNCTION TRIM(ED-CK)
    DISPLAY "viterbi(" FUNCTION TRIM(ED-N) ") = "
        FUNCTION TRIM(ED-SEC)
    STOP RUN.

*> s = (s * 1103515245 + 12345) & 0x7fffffff
LCG-STEP.
    MULTIPLY WS-S-LCG BY K-LCG-A GIVING WS-LT
    ADD K-LCG-C TO WS-LT
    DIVIDE WS-LT BY K-LCG-M GIVING WS-Q REMAINDER WS-S-LCG
    .
