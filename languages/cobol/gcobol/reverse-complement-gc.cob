>>SOURCE FORMAT FREE
*> reverse-complement, gcobol variant (COBOL side study, GCC 15 front end). Same algorithm as
*> reverse-complement.cob: integer-LCG DNA sequence, in-place two-pointer reverse-and-complement
*> (A<->T, C<->G), then the hand polynomial hash h = (h*31 + ascii) mod 1e9+7. Written for gcobol's
*> inline-arithmetic rules: the sequence is a table of BINARY-CHAR UNSIGNED holding the ASCII codes (so
*> comparing and hashing a base is integer work, not alphanumeric compare + FUNCTION ORD), every operand of
*> a hot ADD/SUBTRACT/MULTIPLY/DIVIDE/MOVE/IF is a variable (named constants K-xxx), no COMPUTE/FUNCTION.
IDENTIFICATION DIVISION.
PROGRAM-ID. reverse-complement-gc.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-L            BINARY-LONG VALUE 100000.
01 WS-ARG          PIC X(16)         VALUE SPACES.
01 SEQ-T.
   05 SQ           BINARY-CHAR UNSIGNED OCCURS 400000 TIMES.
01 WS-SEED         BINARY-DOUBLE VALUE 42.
01 WS-T            BINARY-DOUBLE.
01 WS-Q            BINARY-DOUBLE.
01 WS-I            BINARY-LONG.
01 WS-J            BINARY-LONG.
01 WS-K            BINARY-LONG.
01 WS-H            BINARY-DOUBLE VALUE 0.
01 WS-A            BINARY-LONG.
01 WS-BYTE         BINARY-LONG.
01 K-ONE           BINARY-LONG VALUE 1.
01 K-ZERO-D        BINARY-DOUBLE VALUE 0.
01 K-SA            BINARY-DOUBLE VALUE 3877.
01 K-SC            BINARY-DOUBLE VALUE 29573.
01 K-SM            BINARY-DOUBLE VALUE 139968.
01 K-T1            BINARY-DOUBLE VALUE 42000.
01 K-T2            BINARY-DOUBLE VALUE 70000.
01 K-T3            BINARY-DOUBLE VALUE 98000.
01 K-CA            BINARY-LONG VALUE 65.
01 K-CC            BINARY-LONG VALUE 67.
01 K-CG            BINARY-LONG VALUE 71.
01 K-CT            BINARY-LONG VALUE 84.
01 K-31            BINARY-DOUBLE VALUE 31.
01 K-P             BINARY-DOUBLE VALUE 1000000007.
01 ED-CK           PIC -(18)9.
01 ED-N            PIC Z(8)9.
PROCEDURE DIVISION.
MAIN-PARA.
    ACCEPT WS-ARG FROM COMMAND-LINE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-L = FUNCTION NUMVAL(WS-ARG)
    END-IF

    *> Generate the sequence with the integer LCG (seed starts at 42).
    PERFORM VARYING WS-I FROM K-ONE BY K-ONE UNTIL WS-I > WS-L
       MULTIPLY WS-SEED BY K-SA GIVING WS-T
       ADD K-SC TO WS-T
       DIVIDE WS-T BY K-SM GIVING WS-Q REMAINDER WS-SEED
       IF WS-SEED < K-T1
          MOVE K-CA TO SQ(WS-I)
       ELSE
          IF WS-SEED < K-T2
             MOVE K-CC TO SQ(WS-I)
          ELSE
             IF WS-SEED < K-T3
                MOVE K-CG TO SQ(WS-I)
             ELSE
                MOVE K-CT TO SQ(WS-I)
             END-IF
          END-IF
       END-IF
    END-PERFORM

    *> Two-pointer reverse-and-complement, in place (1-indexed).
    MOVE K-ONE TO WS-I
    MOVE WS-L  TO WS-J
    PERFORM UNTIL WS-I >= WS-J
       MOVE SQ(WS-I) TO WS-BYTE
       PERFORM COMPLEMENT
       MOVE WS-BYTE TO WS-A
       MOVE SQ(WS-J) TO WS-BYTE
       PERFORM COMPLEMENT
       MOVE WS-BYTE TO SQ(WS-I)
       MOVE WS-A    TO SQ(WS-J)
       ADD K-ONE TO WS-I
       SUBTRACT K-ONE FROM WS-J
    END-PERFORM
    IF WS-I = WS-J
       MOVE SQ(WS-I) TO WS-BYTE
       PERFORM COMPLEMENT
       MOVE WS-BYTE TO SQ(WS-I)
    END-IF

    *> Hand polynomial hash over each character: h = (h*31 + ascii) mod 1e9+7.
    MOVE K-ZERO-D TO WS-H
    PERFORM VARYING WS-K FROM K-ONE BY K-ONE UNTIL WS-K > WS-L
       MOVE SQ(WS-K) TO WS-T
       MULTIPLY WS-H BY K-31 GIVING WS-Q
       ADD WS-Q TO WS-T
       DIVIDE WS-T BY K-P GIVING WS-Q REMAINDER WS-H
    END-PERFORM

    MOVE WS-H TO ED-CK
    MOVE WS-L TO ED-N
    DISPLAY FUNCTION TRIM(ED-CK)
    DISPLAY "reverse-complement(" FUNCTION TRIM(ED-N) ")"
    STOP RUN.

*> A<->T, C<->G; only A/C/G/T occur. Mirrors C's comp() chain.
COMPLEMENT.
    IF WS-BYTE = K-CA
       MOVE K-CT TO WS-BYTE
    ELSE
       IF WS-BYTE = K-CC
          MOVE K-CG TO WS-BYTE
       ELSE
          IF WS-BYTE = K-CG
             MOVE K-CC TO WS-BYTE
          ELSE
             MOVE K-CA TO WS-BYTE
          END-IF
       END-IF
    END-IF.
