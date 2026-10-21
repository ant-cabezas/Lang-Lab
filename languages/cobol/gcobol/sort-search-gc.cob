>>SOURCE FORMAT FREE
*> sort-search, gcobol variant (COBOL side study, GCC 15 front end). Same algorithm as sort-search.cob:
*> glibc-style LCG, hand-written median-of-three Hoare quicksort (explicit stack), N binary searches folded
*> into h = (h*31 + idx+1) mod 1e9+7. Written for gcobol's inline-arithmetic rules: BINARY-LONG/BINARY-DOUBLE
*> items only (no PIC S9(n) COMP-5), every operand of a hot ADD/SUBTRACT/MULTIPLY/DIVIDE/MOVE/IF is a variable
*> (named constants K-xxx, no literals), every subscript is a plain variable, no COMPUTE/FUNCTION. All indices
*> are 1-based throughout (the C code's a[x] is A(x + 1) there; every index expression is shift-invariant).
*> Floor division / modulus use DIVIDE ... GIVING q REMAINDER r on non-negative operands.
IDENTIFICATION DIVISION.
PROGRAM-ID. sort-search-gc.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-N            BINARY-LONG VALUE 100000.
01 WS-ARG          PIC X(16)         VALUE SPACES.
01 ARR-T.
   05 A            BINARY-LONG OCCURS 200001 TIMES.
01 STK-LO-T.
   05 STK-LO       BINARY-LONG OCCURS 128 TIMES.
01 STK-HI-T.
   05 STK-HI       BINARY-LONG OCCURS 128 TIMES.
01 WS-SP           BINARY-LONG VALUE 0.
01 WS-STATE        BINARY-DOUBLE VALUE 42.
01 WS-T            BINARY-DOUBLE.
01 WS-QD           BINARY-DOUBLE.
01 WS-CHECKSUM     BINARY-DOUBLE VALUE 0.
01 K-ZERO          BINARY-LONG VALUE 0.
01 K-ONE           BINARY-LONG VALUE 1.
01 K-TWO           BINARY-LONG VALUE 2.
01 K-LCG-A         BINARY-DOUBLE VALUE 1103515245.
01 K-LCG-C         BINARY-DOUBLE VALUE 12345.
01 K-LCG-M         BINARY-DOUBLE VALUE 2147483648.
01 K-31            BINARY-DOUBLE VALUE 31.
01 K-P             BINARY-DOUBLE VALUE 1000000007.
01 WS-NN           BINARY-DOUBLE.
01 WS-I            BINARY-LONG.
01 WS-Q            BINARY-LONG.
01 WS-IDX          BINARY-LONG.
01 WS-KEY          BINARY-LONG.
*> qsort locals
01 QS-LO           BINARY-LONG.
01 QS-HI           BINARY-LONG.
01 QS-MID          BINARY-LONG.
01 QS-PIVOT        BINARY-LONG.
01 QS-I            BINARY-LONG.
01 QS-J            BINARY-LONG.
01 QS-J1           BINARY-LONG.
01 QS-T            BINARY-LONG.
01 QS-D            BINARY-LONG.
01 QS-H            BINARY-LONG.
*> binary-search locals
01 BS-LO           BINARY-LONG.
01 BS-HI           BINARY-LONG.
01 BS-MID          BINARY-LONG.
01 BS-FOUND        BINARY-LONG VALUE 0.
01 ED-CK           PIC -(18)9.
01 ED-N            PIC Z(17)9.
PROCEDURE DIVISION.
MAIN-PARA.
    ACCEPT WS-ARG FROM COMMAND-LINE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-N = FUNCTION NUMVAL(WS-ARG)
    END-IF
    MOVE WS-N TO WS-NN

    *> generate N ints
    PERFORM VARYING WS-I FROM K-ONE BY K-ONE UNTIL WS-I > WS-N
       PERFORM LCG-NEXT
       MOVE WS-STATE TO A(WS-I)
    END-PERFORM

    MOVE K-ONE TO QS-LO
    MOVE WS-N  TO QS-HI
    PERFORM QSORT-H

    *> N binary searches, fold idx+1 into the checksum
    MOVE K-ZERO TO WS-CHECKSUM
    PERFORM VARYING WS-Q FROM K-ONE BY K-ONE UNTIL WS-Q > WS-N
       PERFORM LCG-NEXT
       *> key = a[state % N]  -> A(state % N + 1)
       DIVIDE WS-STATE BY WS-NN GIVING WS-QD REMAINDER WS-IDX
       ADD K-ONE TO WS-IDX
       MOVE A(WS-IDX) TO WS-KEY
       PERFORM BSEARCH-I
       *> h = (h * 31 + (idx + 1)) % P ; WS-IDX is the 1-based hit index (= C idx + 1), 0 on miss
       MULTIPLY WS-CHECKSUM BY K-31 GIVING WS-T
       ADD WS-IDX TO WS-T
       DIVIDE WS-T BY K-P GIVING WS-QD REMAINDER WS-CHECKSUM
    END-PERFORM

    MOVE WS-CHECKSUM TO ED-CK
    MOVE WS-N        TO ED-N
    DISPLAY FUNCTION TRIM(ED-CK)
    DISPLAY "sort-search(" FUNCTION TRIM(ED-N) ")"
    STOP RUN.

*> state = (state * 1103515245 + 12345) mod 2^31 ; product fits signed 64-bit
LCG-NEXT.
    MULTIPLY WS-STATE BY K-LCG-A GIVING WS-T
    ADD K-LCG-C TO WS-T
    DIVIDE WS-T BY K-LCG-M GIVING WS-QD REMAINDER WS-STATE
    .

*> median-of-three + Hoare partition, both sides; explicit stack replaces recursion.
QSORT-H.
    MOVE K-ONE TO WS-SP
    MOVE QS-LO TO STK-LO(WS-SP)
    MOVE QS-HI TO STK-HI(WS-SP)
    PERFORM UNTIL WS-SP = K-ZERO
       MOVE STK-LO(WS-SP) TO QS-LO
       MOVE STK-HI(WS-SP) TO QS-HI
       SUBTRACT K-ONE FROM WS-SP
       IF QS-LO < QS-HI
          *> mid = lo + (hi - lo) / 2  (floor division)
          MOVE QS-HI TO QS-D
          SUBTRACT QS-LO FROM QS-D
          DIVIDE QS-D BY K-TWO GIVING QS-H
          MOVE QS-LO TO QS-MID
          ADD QS-H TO QS-MID
          *> median-of-three on a[lo], a[mid], a[hi]
          IF A(QS-MID) < A(QS-LO)
             MOVE A(QS-LO)  TO QS-T
             MOVE A(QS-MID) TO A(QS-LO)
             MOVE QS-T      TO A(QS-MID)
          END-IF
          IF A(QS-HI) < A(QS-LO)
             MOVE A(QS-LO) TO QS-T
             MOVE A(QS-HI) TO A(QS-LO)
             MOVE QS-T     TO A(QS-HI)
          END-IF
          IF A(QS-HI) < A(QS-MID)
             MOVE A(QS-MID) TO QS-T
             MOVE A(QS-HI)  TO A(QS-MID)
             MOVE QS-T      TO A(QS-HI)
          END-IF
          MOVE A(QS-MID) TO QS-PIVOT
          MOVE QS-LO TO QS-I
          SUBTRACT K-ONE FROM QS-I
          MOVE QS-HI TO QS-J
          ADD K-ONE TO QS-J
          PERFORM UNTIL QS-I >= QS-J
             ADD K-ONE TO QS-I
             PERFORM UNTIL A(QS-I) >= QS-PIVOT
                ADD K-ONE TO QS-I
             END-PERFORM
             SUBTRACT K-ONE FROM QS-J
             PERFORM UNTIL A(QS-J) <= QS-PIVOT
                SUBTRACT K-ONE FROM QS-J
             END-PERFORM
             IF QS-I < QS-J
                MOVE A(QS-I) TO QS-T
                MOVE A(QS-J) TO A(QS-I)
                MOVE QS-T    TO A(QS-J)
             END-IF
          END-PERFORM
          *> recurse(lo, j) and recurse(j+1, hi) -> push both ranges
          ADD K-ONE TO WS-SP
          MOVE QS-LO TO STK-LO(WS-SP)
          MOVE QS-J  TO STK-HI(WS-SP)
          ADD K-ONE TO WS-SP
          MOVE QS-J TO QS-J1
          ADD K-ONE TO QS-J1
          MOVE QS-J1 TO STK-LO(WS-SP)
          MOVE QS-HI TO STK-HI(WS-SP)
       END-IF
    END-PERFORM.

*> iterative binary search over A(1..N). Sets WS-IDX to the 1-based hit index, or 0 on miss.
BSEARCH-I.
    MOVE K-ONE TO BS-LO
    MOVE WS-N  TO BS-HI
    MOVE K-ZERO TO BS-FOUND
    MOVE K-ZERO TO WS-IDX
    PERFORM UNTIL BS-LO > BS-HI OR BS-FOUND = K-ONE
       MOVE BS-HI TO QS-D
       SUBTRACT BS-LO FROM QS-D
       DIVIDE QS-D BY K-TWO GIVING QS-H
       MOVE BS-LO TO BS-MID
       ADD QS-H TO BS-MID
       IF A(BS-MID) < WS-KEY
          MOVE BS-MID TO BS-LO
          ADD K-ONE TO BS-LO
       ELSE
          IF A(BS-MID) > WS-KEY
             MOVE BS-MID TO BS-HI
             SUBTRACT K-ONE FROM BS-HI
          ELSE
             MOVE BS-MID TO WS-IDX
             MOVE K-ONE TO BS-FOUND
          END-IF
       END-IF
    END-PERFORM.
