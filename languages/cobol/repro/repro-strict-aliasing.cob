>>SOURCE FORMAT FREE
*> Minimal reproducer for the gcobol miscompile found by the COBOL side study (aarch64; gcobol-15=15.2.0-16ubuntu1
*> and gcobol-16=16.2.0-3 both hang): a Hoare partition scan over a BINARY-LONG table, written with single-verb
*> ADD / SUBTRACT / MOVE. Build: gcobol-15 -O2 -ffree-form repro-strict-aliasing.cob -o x
*> Expected output "1 2 3 4 5 6 7 8". At plain -O2 the scan never terminates; correct at -O0, -O1 and
*> -O2 -fno-strict-aliasing. Kept for a future upstream report (nothing has been reported).
IDENTIFICATION DIVISION.
PROGRAM-ID. alias.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 ARR-T.
   05 A            BINARY-LONG OCCURS 8 TIMES.
01 K-ONE           BINARY-LONG VALUE 1.
01 K-ZERO          BINARY-LONG VALUE 0.
01 QS-I            BINARY-LONG.
01 QS-J            BINARY-LONG.
01 QS-T            BINARY-LONG.
01 QS-PIVOT        BINARY-LONG.
01 WS-X            BINARY-LONG.
01 ED              PIC -(9)9.
PROCEDURE DIVISION.
    MOVE 5 TO A(1) MOVE 3 TO A(2) MOVE 8 TO A(3) MOVE 1 TO A(4)
    MOVE 7 TO A(5) MOVE 2 TO A(6) MOVE 6 TO A(7) MOVE 4 TO A(8)
    PERFORM VARYING WS-X FROM K-ONE BY K-ONE UNTIL WS-X > 8
       MOVE WS-X TO A(WS-X)
    END-PERFORM
    MOVE 4 TO QS-PIVOT
    MOVE K-ZERO TO QS-I
    MOVE 9 TO QS-J
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
    PERFORM VARYING WS-X FROM K-ONE BY K-ONE UNTIL WS-X > 8
       MOVE A(WS-X) TO ED
       DISPLAY FUNCTION TRIM(ED) " " WITH NO ADVANCING
    END-PERFORM
    DISPLAY " "
    STOP RUN.
