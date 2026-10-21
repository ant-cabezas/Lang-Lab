>>SOURCE FORMAT FREE
*> fannkuch-redux, gcobol variant (COBOL side study, GCC 15 front end). Same algorithm and checksum as
*> fannkuch-bin.cob. Differences, all about which statements gcobol 15 compiles to inline machine code:
*>  - every operand of a hot ADD/SUBTRACT/MOVE/IF is a BINARY-LONG variable: literals are replaced by
*>    the named constants K-ZERO / K-ONE (a literal operand goes through libgcobol decimal-scaling helpers);
*>  - every subscript is a plain variable (P1(WS-I + 1) becomes MOVE + ADD into WS-I1 first);
*>  - no COMPUTE / FUNCTION in the loops. Output: line 1 = parity-weighted checksum, line 2 = max flips.
IDENTIFICATION DIVISION.
PROGRAM-ID. fannkuch-gc.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-N            BINARY-LONG VALUE 7.
01 WS-ARG          PIC X(16)         VALUE SPACES.
01 PERM1-T.
   05 P1           BINARY-LONG OCCURS 32 TIMES.
01 PERM-T.
   05 PP           BINARY-LONG OCCURS 32 TIMES.
01 CNT-T.
   05 CC           BINARY-LONG OCCURS 32 TIMES.
01 WS-MAXFLIPS     BINARY-LONG VALUE 0.
01 WS-CHECKSUM     BINARY-DOUBLE VALUE 0.
01 WS-R            BINARY-LONG.
01 WS-PERMIDX      BINARY-DOUBLE VALUE 0.
01 WS-FLIPS        BINARY-LONG.
01 WS-K            BINARY-LONG.
01 WS-I            BINARY-LONG.
01 WS-J            BINARY-LONG.
01 WS-T            BINARY-LONG.
01 WS-FIRST        BINARY-LONG.
01 WS-PARITY       BINARY-LONG VALUE 0.
01 WS-DONE         BINARY-LONG VALUE 0.
01 WS-NEVER        BINARY-LONG VALUE 0.
01 K-ZERO         BINARY-LONG VALUE 0.
01 K-ONE          BINARY-LONG VALUE 1.
01 WS-I1          BINARY-LONG.
01 WS-R1          BINARY-LONG.
01 ED-CK           PIC -(18)9.
01 ED-N            PIC Z(8)9.
01 ED-MF           PIC Z(8)9.
PROCEDURE DIVISION.
MAIN-PARA.
    ACCEPT WS-ARG FROM COMMAND-LINE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-N = FUNCTION NUMVAL(WS-ARG)
    END-IF

    PERFORM VARYING WS-I FROM K-ONE BY K-ONE UNTIL WS-I > WS-N
       MOVE WS-I TO P1(WS-I)
       SUBTRACT K-ONE FROM P1(WS-I)
    END-PERFORM
    MOVE WS-N TO WS-R

    PERFORM UNTIL WS-NEVER = K-ONE
       PERFORM UNTIL WS-R = K-ONE
          MOVE WS-R TO CC(WS-R)
          SUBTRACT K-ONE FROM WS-R
       END-PERFORM

       PERFORM VARYING WS-I FROM K-ONE BY K-ONE UNTIL WS-I > WS-N
          MOVE P1(WS-I) TO PP(WS-I)
       END-PERFORM

       MOVE K-ZERO TO WS-FLIPS
       PERFORM UNTIL PP(K-ONE) = K-ZERO
          MOVE PP(K-ONE) TO WS-K
          MOVE K-ONE TO WS-I
          MOVE WS-K TO WS-J
          ADD K-ONE TO WS-J
          PERFORM UNTIL WS-I >= WS-J
             MOVE PP(WS-I) TO WS-T
             MOVE PP(WS-J) TO PP(WS-I)
             MOVE WS-T     TO PP(WS-J)
             ADD K-ONE TO WS-I
             SUBTRACT K-ONE FROM WS-J
          END-PERFORM
          ADD K-ONE TO WS-FLIPS
       END-PERFORM

       IF WS-FLIPS > WS-MAXFLIPS
          MOVE WS-FLIPS TO WS-MAXFLIPS
       END-IF
       IF WS-PARITY = K-ZERO
          ADD WS-FLIPS TO WS-CHECKSUM
       ELSE
          SUBTRACT WS-FLIPS FROM WS-CHECKSUM
       END-IF

       MOVE K-ZERO TO WS-DONE
       PERFORM UNTIL WS-DONE = K-ONE
          IF WS-R = WS-N
             MOVE WS-CHECKSUM TO ED-CK
             MOVE WS-N        TO ED-N
             MOVE WS-MAXFLIPS TO ED-MF
             DISPLAY FUNCTION TRIM(ED-CK)
             DISPLAY "Pfannkuchen(" FUNCTION TRIM(ED-N) ") = "
                     FUNCTION TRIM(ED-MF)
             STOP RUN
          END-IF
          MOVE P1(K-ONE) TO WS-FIRST
          PERFORM VARYING WS-I FROM K-ONE BY K-ONE UNTIL WS-I > WS-R
             MOVE WS-I TO WS-I1
             ADD K-ONE TO WS-I1
             MOVE P1(WS-I1) TO P1(WS-I)
          END-PERFORM
          MOVE WS-R TO WS-R1
          ADD K-ONE TO WS-R1
          MOVE WS-FIRST TO P1(WS-R1)
          SUBTRACT K-ONE FROM CC(WS-R1)
          IF CC(WS-R1) > K-ZERO
             MOVE K-ONE TO WS-DONE
          ELSE
             ADD K-ONE TO WS-R
          END-IF
       END-PERFORM
       ADD K-ONE TO WS-PERMIDX
       IF WS-PARITY = K-ZERO
          MOVE K-ONE TO WS-PARITY
       ELSE
          MOVE K-ZERO TO WS-PARITY
       END-IF
    END-PERFORM
    STOP RUN.
