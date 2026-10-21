>>SOURCE FORMAT FREE
*> lz77, BINARY variant (COBOL side study). Same algorithm (WINDOW=512, MIN_MATCH=3,
*> MAX_MATCH=255, 6-symbol alphabet, nearest distance wins ties), LCG and checksum as
*> lz77.cob / languages/c/lz77.c. Differences, all about how GnuCOBOL 3.2 compiles arithmetic
*> (every COMPUTE and every arithmetic expression inside a condition is evaluated through
*> cob_decimal / GMP; ADD/SUBTRACT/MOVE/IF on plain native binary items are plain C):
*>  - COBOL 2002 BINARY-LONG / BINARY-DOUBLE items.
*>  - The match loop keeps pos+l and cand+l as their own counters (ADD 1 to each) instead
*>    of testing IF POS + L >= N, and compares the two symbols through a scalar copy.
*>  - Differences such as pos - cand are MOVE + SUBTRACT; the LCG and the poly-hash keep a
*>    COMPUTE for the multiply and use DIVIDE ... REMAINDER for the modulus.
IDENTIFICATION DIVISION.
PROGRAM-ID. lz77-bin.
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
01 P-MOD           BINARY-DOUBLE VALUE 1000000007.
01 ED-H            PIC -(18)9.
01 ED-N            PIC Z(8)9.
PROCEDURE DIVISION.
MAIN-PARA.
    DISPLAY 1 UPON ARGUMENT-NUMBER
    ACCEPT WS-ARG FROM ARGUMENT-VALUE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-N = FUNCTION NUMVAL(WS-ARG)
    END-IF

    *> generate input: s = lcg(s); in[i] = s % 6
    MOVE 42 TO WS-S
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-N
       COMPUTE WS-T = WS-S * 1103515245 + 12345
       DIVIDE WS-T BY 2147483648 GIVING WS-Q REMAINDER WS-S
       DIVIDE WS-S BY 6 GIVING WS-Q REMAINDER IN-B(WS-I)
    END-PERFORM

    MOVE 0 TO WS-POS
    PERFORM UNTIL WS-POS >= WS-N
       MOVE 0 TO WS-BEST-LEN
       MOVE 0 TO WS-BEST-DIST
       MOVE WS-POS TO WS-START
       SUBTRACT 512 FROM WS-START
       IF WS-START < 0
          MOVE 0 TO WS-START
       END-IF
       *> closest distance first: cand from pos-1 down to start
       MOVE WS-POS TO WS-CAND
       SUBTRACT 1 FROM WS-CAND
       PERFORM UNTIL WS-CAND < WS-START
          MOVE 0 TO WS-L
          MOVE WS-POS  TO WS-PL
          MOVE WS-CAND TO WS-CL
          MOVE 0 TO WS-MATCH
          PERFORM UNTIL WS-MATCH = 1
             IF WS-PL >= WS-N OR WS-L >= 255
                MOVE 1 TO WS-MATCH
             ELSE
                MOVE IN-B(WS-PL + 1) TO WS-CUR
                IF IN-B(WS-CL + 1) = WS-CUR
                   ADD 1 TO WS-L
                   ADD 1 TO WS-PL
                   ADD 1 TO WS-CL
                ELSE
                   MOVE 1 TO WS-MATCH
                END-IF
             END-IF
          END-PERFORM
          IF WS-L > WS-BEST-LEN
             MOVE WS-L TO WS-BEST-LEN
             MOVE WS-POS TO WS-BEST-DIST
             SUBTRACT WS-CAND FROM WS-BEST-DIST
          END-IF
          SUBTRACT 1 FROM WS-CAND
       END-PERFORM

       IF WS-BEST-LEN >= 3
          MOVE 1 TO WS-CUR
          PERFORM HASH-STEP
          MOVE WS-BEST-DIST TO WS-CUR
          PERFORM HASH-STEP
          MOVE WS-BEST-LEN TO WS-CUR
          PERFORM HASH-STEP
          ADD WS-BEST-LEN TO WS-POS
       ELSE
          MOVE 0 TO WS-CUR
          PERFORM HASH-STEP
          MOVE IN-B(WS-POS + 1) TO WS-CUR
          PERFORM HASH-STEP
          ADD 1 TO WS-POS
       END-IF
    END-PERFORM

    MOVE WS-H TO ED-H
    MOVE WS-N TO ED-N
    DISPLAY FUNCTION TRIM(ED-H)
    DISPLAY "lz77(" FUNCTION TRIM(ED-N) ")"
    STOP RUN.

*> h = (h*31 + cur) % P
HASH-STEP.
    COMPUTE WS-T = WS-H * 31 + WS-CUR
    DIVIDE WS-T BY P-MOD GIVING WS-Q REMAINDER WS-H
    .
