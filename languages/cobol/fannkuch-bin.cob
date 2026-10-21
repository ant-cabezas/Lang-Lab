>>SOURCE FORMAT FREE
*> fannkuch-redux, BINARY variant (COBOL side study): same algorithm as fannkuch.cob, but
*> COBOL 2002 BINARY-LONG/BINARY-DOUBLE items and no COMPUTE in the hot loops. In GnuCOBOL 3.2
*> every COMPUTE (and FUNCTION MOD) is evaluated through cob_decimal (GMP); ADD/SUBTRACT/MOVE
*> on native binary items compile to plain C. So j = k + 1 is MOVE + ADD, and the parity of
*> perm_idx (C: perm_idx % 2) is a 0/1 flag toggled when perm_idx is incremented. Output: line 1 = parity-weighted checksum, line 2 =
*> Pfannkuchen(n) = max flips. Native ELF via cobc -> bit-exact under qemu+insn.
IDENTIFICATION DIVISION.
PROGRAM-ID. fannkuch-bin.
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
01 ED-CK           PIC -(18)9.
01 ED-N            PIC Z(8)9.
01 ED-MF           PIC Z(8)9.
PROCEDURE DIVISION.
MAIN-PARA.
    DISPLAY 1 UPON ARGUMENT-NUMBER
    ACCEPT WS-ARG FROM ARGUMENT-VALUE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-N = FUNCTION NUMVAL(WS-ARG)
    END-IF

    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-N
       MOVE WS-I TO P1(WS-I)
       SUBTRACT 1 FROM P1(WS-I)
    END-PERFORM
    MOVE WS-N TO WS-R

    PERFORM UNTIL WS-NEVER = 1
       PERFORM UNTIL WS-R = 1
          MOVE WS-R TO CC(WS-R)
          SUBTRACT 1 FROM WS-R
       END-PERFORM

       PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-N
          MOVE P1(WS-I) TO PP(WS-I)
       END-PERFORM

       MOVE 0 TO WS-FLIPS
       PERFORM UNTIL PP(1) = 0
          MOVE PP(1) TO WS-K
          MOVE 1 TO WS-I
          MOVE WS-K TO WS-J
          ADD 1 TO WS-J
          PERFORM UNTIL WS-I >= WS-J
             MOVE PP(WS-I) TO WS-T
             MOVE PP(WS-J) TO PP(WS-I)
             MOVE WS-T     TO PP(WS-J)
             ADD 1 TO WS-I
             SUBTRACT 1 FROM WS-J
          END-PERFORM
          ADD 1 TO WS-FLIPS
       END-PERFORM

       IF WS-FLIPS > WS-MAXFLIPS
          MOVE WS-FLIPS TO WS-MAXFLIPS
       END-IF
       IF WS-PARITY = 0
          ADD WS-FLIPS TO WS-CHECKSUM
       ELSE
          SUBTRACT WS-FLIPS FROM WS-CHECKSUM
       END-IF

       MOVE 0 TO WS-DONE
       PERFORM UNTIL WS-DONE = 1
          IF WS-R = WS-N
             MOVE WS-CHECKSUM TO ED-CK
             MOVE WS-N        TO ED-N
             MOVE WS-MAXFLIPS TO ED-MF
             DISPLAY FUNCTION TRIM(ED-CK)
             DISPLAY "Pfannkuchen(" FUNCTION TRIM(ED-N) ") = "
                     FUNCTION TRIM(ED-MF)
             STOP RUN
          END-IF
          MOVE P1(1) TO WS-FIRST
          PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-R
             MOVE P1(WS-I + 1) TO P1(WS-I)
          END-PERFORM
          MOVE WS-FIRST TO P1(WS-R + 1)
          SUBTRACT 1 FROM CC(WS-R + 1)
          IF CC(WS-R + 1) > 0
             MOVE 1 TO WS-DONE
          ELSE
             ADD 1 TO WS-R
          END-IF
       END-PERFORM
       ADD 1 TO WS-PERMIDX
       IF WS-PARITY = 0
          MOVE 1 TO WS-PARITY
       ELSE
          MOVE 0 TO WS-PARITY
       END-IF
    END-PERFORM
    STOP RUN.
