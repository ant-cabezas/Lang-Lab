>>SOURCE FORMAT FREE
*> tak, BINARY variant (COBOL side study). Same recursion and checksum as tak.cob /
*> languages/c/tak.c. Differences: COBOL 2002 BINARY-LONG / BINARY-DOUBLE items, and the
*> argument decrements are MOVE + SUBTRACT instead of COMPUTE (in GnuCOBOL 3.2 every COMPUTE
*> goes through cob_decimal / GMP; SUBTRACT on a native binary item is plain C).
IDENTIFICATION DIVISION.
PROGRAM-ID. tak-bin.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-N            BINARY-LONG VALUE 6.
01 WS-ARG          PIC X(16)         VALUE SPACES.
01 WS-X            BINARY-LONG.
01 WS-Y            BINARY-LONG.
01 WS-Z            BINARY-LONG.
01 WS-RESULT       BINARY-LONG.
01 WS-CALLS        BINARY-DOUBLE VALUE 0.
01 ED-CALLS        PIC -(18)9.
01 ED-N            PIC -(9)9.
01 ED-R            PIC -(9)9.
PROCEDURE DIVISION.
MAIN-PARA.
    DISPLAY 1 UPON ARGUMENT-NUMBER
    ACCEPT WS-ARG FROM ARGUMENT-VALUE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-N = FUNCTION NUMVAL(WS-ARG)
    END-IF

    COMPUTE WS-X = 3 * WS-N
    COMPUTE WS-Y = 2 * WS-N
    MOVE WS-N TO WS-Z
    CALL "TAK-FN" USING WS-X WS-Y WS-Z WS-RESULT WS-CALLS

    MOVE WS-CALLS  TO ED-CALLS
    MOVE WS-N      TO ED-N
    MOVE WS-RESULT TO ED-R
    DISPLAY FUNCTION TRIM(ED-CALLS)
    DISPLAY "tak(" FUNCTION TRIM(ED-N) ") = " FUNCTION TRIM(ED-R)
    STOP RUN.
END PROGRAM tak-bin.

*> ---------------------------------------------------------------------------
*> RECURSIVE standalone program. Arguments + temporaries are in LOCAL-STORAGE so
*> every recursive instance has its own frame; the call counter (LK-CALLS) is the
*> caller's single cell, passed BY REFERENCE down the whole tree, so it accumulates
*> every entry to tak across all instances.
IDENTIFICATION DIVISION.
PROGRAM-ID. TAK-FN IS RECURSIVE.
DATA DIVISION.
LOCAL-STORAGE SECTION.
01 LS-T1           BINARY-LONG.
01 LS-T2           BINARY-LONG.
01 LS-T3           BINARY-LONG.
01 LS-A1           BINARY-LONG.
01 LS-A2           BINARY-LONG.
01 LS-A3           BINARY-LONG.
LINKAGE SECTION.
01 LK-X            BINARY-LONG.
01 LK-Y            BINARY-LONG.
01 LK-Z            BINARY-LONG.
01 LK-R            BINARY-LONG.
01 LK-CALLS        BINARY-DOUBLE.
PROCEDURE DIVISION USING LK-X LK-Y LK-Z LK-R LK-CALLS.
TAK-PARA.
    ADD 1 TO LK-CALLS
    IF LK-Y < LK-X
       MOVE LK-X TO LS-A1
       SUBTRACT 1 FROM LS-A1
       CALL "TAK-FN" USING LS-A1 LK-Y LK-Z LS-T1 LK-CALLS
       MOVE LK-Y TO LS-A2
       SUBTRACT 1 FROM LS-A2
       CALL "TAK-FN" USING LS-A2 LK-Z LK-X LS-T2 LK-CALLS
       MOVE LK-Z TO LS-A3
       SUBTRACT 1 FROM LS-A3
       CALL "TAK-FN" USING LS-A3 LK-X LK-Y LS-T3 LK-CALLS
       CALL "TAK-FN" USING LS-T1 LS-T2 LS-T3 LK-R LK-CALLS
    ELSE
       MOVE LK-Z TO LK-R
    END-IF
    EXIT PROGRAM.
END PROGRAM TAK-FN.
