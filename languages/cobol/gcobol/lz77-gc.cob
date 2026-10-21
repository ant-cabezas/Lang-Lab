>>SOURCE FORMAT FREE
*> lz77, gcobol variant (COBOL side study, GCC 15 front end). Same algorithm (WINDOW=512, MIN_MATCH=3,
*> MAX_MATCH=255, 6-symbol alphabet, nearest distance wins ties), LCG and checksum as lz77-bin.cob.
*> Written for gcobol's inline-arithmetic rules: every operand of a hot ADD/SUBTRACT/MULTIPLY/DIVIDE/MOVE/IF
*> is a BINARY-LONG/BINARY-DOUBLE variable (named constants K-xxx, no literals), every subscript is a plain
*> variable (positions are 1-based throughout, so IN-B(WS-PL + 1) becomes IN-B(WS-PL)), no COMPUTE/FUNCTION.
IDENTIFICATION DIVISION.
PROGRAM-ID. lz77-gc.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-N            BINARY-LONG VALUE 24000.
01 WS-ARG          PIC X(16)         VALUE SPACES.
01 IN-T.
   05 IN-B         BINARY-LONG OCCURS 24001 TIMES.
01 WS-S            BINARY-DOUBLE VALUE 42.
01 WS-H            BINARY-DOUBLE VALUE 0.
01 WS-POS          BINARY-LONG.
01 WS-BEST-LEN     BINARY-LONG.
01 WS-BEST-DIST    BINARY-LONG.
01 WS-START        BINARY-LONG.
01 WS-CAND         BINARY-LONG.
01 WS-L            BINARY-LONG.
01 WS-I            BINARY-LONG.
01 WS-MATCH        BINARY-LONG VALUE 0.
01 WS-PL           BINARY-LONG.
01 WS-CL           BINARY-LONG.
01 WS-CUR          BINARY-LONG.
01 WS-T            BINARY-DOUBLE.
01 WS-Q            BINARY-DOUBLE.
01 K-ZERO          BINARY-LONG VALUE 0.
01 K-ONE           BINARY-LONG VALUE 1.
01 K-THREE         BINARY-LONG VALUE 3.
01 K-SIX           BINARY-DOUBLE VALUE 6.
01 K-255           BINARY-LONG VALUE 255.
01 K-512           BINARY-LONG VALUE 512.
01 K-LCG-A         BINARY-DOUBLE VALUE 1103515245.
01 K-LCG-C         BINARY-DOUBLE VALUE 12345.
01 K-LCG-M         BINARY-DOUBLE VALUE 2147483648.
01 K-31            BINARY-DOUBLE VALUE 31.
01 P-MOD           BINARY-DOUBLE VALUE 1000000007.
01 ED-H            PIC -(18)9.
01 ED-N            PIC Z(8)9.
PROCEDURE DIVISION.
MAIN-PARA.
    ACCEPT WS-ARG FROM COMMAND-LINE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-N = FUNCTION NUMVAL(WS-ARG)
    END-IF

    *> generate input: s = lcg(s); in[i] = s % 6
    PERFORM VARYING WS-I FROM K-ONE BY K-ONE UNTIL WS-I > WS-N
       MULTIPLY WS-S BY K-LCG-A GIVING WS-T
       ADD K-LCG-C TO WS-T
       DIVIDE WS-T BY K-LCG-M GIVING WS-Q REMAINDER WS-S
       DIVIDE WS-S BY K-SIX GIVING WS-Q REMAINDER IN-B(WS-I)
    END-PERFORM

    *> WS-POS is 1-based (C pos = WS-POS - 1)
    MOVE K-ONE TO WS-POS
    PERFORM UNTIL WS-POS > WS-N
       MOVE K-ZERO TO WS-BEST-LEN
       MOVE K-ZERO TO WS-BEST-DIST
       MOVE WS-POS TO WS-START
       SUBTRACT K-512 FROM WS-START
       IF WS-START < K-ONE
          MOVE K-ONE TO WS-START
       END-IF
       *> closest distance first: cand from pos-1 down to start
       MOVE WS-POS TO WS-CAND
       SUBTRACT K-ONE FROM WS-CAND
       PERFORM UNTIL WS-CAND < WS-START
          MOVE K-ZERO TO WS-L
          MOVE WS-POS  TO WS-PL
          MOVE WS-CAND TO WS-CL
          MOVE K-ZERO TO WS-MATCH
          PERFORM UNTIL WS-MATCH = K-ONE
             IF WS-PL > WS-N OR WS-L >= K-255
                MOVE K-ONE TO WS-MATCH
             ELSE
                MOVE IN-B(WS-PL) TO WS-CUR
                IF IN-B(WS-CL) = WS-CUR
                   ADD K-ONE TO WS-L
                   ADD K-ONE TO WS-PL
                   ADD K-ONE TO WS-CL
                ELSE
                   MOVE K-ONE TO WS-MATCH
                END-IF
             END-IF
          END-PERFORM
          IF WS-L > WS-BEST-LEN
             MOVE WS-L TO WS-BEST-LEN
             MOVE WS-POS TO WS-BEST-DIST
             SUBTRACT WS-CAND FROM WS-BEST-DIST
          END-IF
          SUBTRACT K-ONE FROM WS-CAND
       END-PERFORM

       IF WS-BEST-LEN >= K-THREE
          MOVE K-ONE TO WS-CUR
          PERFORM HASH-STEP
          MOVE WS-BEST-DIST TO WS-CUR
          PERFORM HASH-STEP
          MOVE WS-BEST-LEN TO WS-CUR
          PERFORM HASH-STEP
          ADD WS-BEST-LEN TO WS-POS
       ELSE
          MOVE K-ZERO TO WS-CUR
          PERFORM HASH-STEP
          MOVE IN-B(WS-POS) TO WS-CUR
          PERFORM HASH-STEP
          ADD K-ONE TO WS-POS
       END-IF
    END-PERFORM

    MOVE WS-H TO ED-H
    MOVE WS-N TO ED-N
    DISPLAY FUNCTION TRIM(ED-H)
    DISPLAY "lz77(" FUNCTION TRIM(ED-N) ")"
    STOP RUN.

*> h = (h*31 + cur) % P
HASH-STEP.
    MULTIPLY WS-H BY K-31 GIVING WS-T
    ADD WS-CUR TO WS-T
    DIVIDE WS-T BY P-MOD GIVING WS-Q REMAINDER WS-H
    .
