>>SOURCE FORMAT FREE
*> tak, gcobol variant (COBOL side study). Same recursion and checksum as tak.cob / languages/c/tak.c: the naive
*> triple-recursive Takeuchi function, one real RECURSIVE program with LOCAL-STORAGE frames. No memoization, no
*> manual stack. Written for gcobol's rules: BINARY items, single-verb ADD/SUBTRACT/MOVE, named constants.
*> Cost notes: (1) every LOCAL-STORAGE item costs a libgcobol push/pop per CALL, so only the three results that
*> must survive the nested calls are LOCAL-STORAGE; the three decremented arguments are static WORKING-STORAGE
*> items passed BY CONTENT (the callee gets a copy), which is what makes that safe. (2) The self-call goes
*> through a FUNCTION-POINTER set once in the main program: gcobol 16.2 cannot link a literal-name CALL from a
*> RECURSIVE program to itself (undefined reference to symbol tak$fn.0); the pointer form links on 15.2 and 16.2 and
*> costs the same on 15.2 as the literal call. BY VALUE parameters were tried and are NOT reentrant on gcobol
*> 15.2 (wrong answers, segfaults), so they are not used.
IDENTIFICATION DIVISION.
PROGRAM-ID. tak-gc.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-N            BINARY-LONG VALUE 6.
01 WS-ARG          PIC X(16)         VALUE SPACES.
01 WS-X            BINARY-LONG.
01 WS-Y            BINARY-LONG.
01 WS-Z            BINARY-LONG.
01 WS-RESULT       BINARY-LONG.
01 WS-CALLS        BINARY-DOUBLE VALUE 0.
01 EXT-FP FUNCTION-POINTER EXTERNAL.
01 WS-THREE        BINARY-LONG VALUE 3.
01 WS-TWO          BINARY-LONG VALUE 2.
01 ED-CALLS        PIC -(18)9.
01 ED-N            PIC -(9)9.
01 ED-R            PIC -(9)9.
PROCEDURE DIVISION.
MAIN-PARA.
    ACCEPT WS-ARG FROM COMMAND-LINE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-N = FUNCTION NUMVAL(WS-ARG)
    END-IF

    MULTIPLY WS-N BY WS-THREE GIVING WS-X
    MULTIPLY WS-N BY WS-TWO GIVING WS-Y
    MOVE WS-N TO WS-Z
    SET EXT-FP TO ENTRY "TAK-FN"
    CALL EXT-FP USING WS-X WS-Y WS-Z WS-RESULT WS-CALLS

    MOVE WS-CALLS  TO ED-CALLS
    MOVE WS-N      TO ED-N
    MOVE WS-RESULT TO ED-R
    DISPLAY FUNCTION TRIM(ED-CALLS)
    DISPLAY "tak(" FUNCTION TRIM(ED-N) ") = " FUNCTION TRIM(ED-R)
    STOP RUN.
END PROGRAM tak-gc.

*> ---------------------------------------------------------------------------
*> RECURSIVE standalone program. Arguments + temporaries are in LOCAL-STORAGE so
*> every recursive instance has its own frame; the call counter (LK-CALLS) is the
*> caller's single cell, passed BY REFERENCE down the whole tree, so it accumulates
*> every entry to tak across all instances.
IDENTIFICATION DIVISION.
PROGRAM-ID. TAK-FN IS RECURSIVE.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 EXT-FP FUNCTION-POINTER EXTERNAL.
01 K-ONE           BINARY-LONG VALUE 1.
01 K-ONE-D         BINARY-DOUBLE VALUE 1.
01 WS-A1           BINARY-LONG.
01 WS-A2           BINARY-LONG.
01 WS-A3           BINARY-LONG.
LOCAL-STORAGE SECTION.
01 LS-T1           BINARY-LONG.
01 LS-T2           BINARY-LONG.
01 LS-T3           BINARY-LONG.
LINKAGE SECTION.
01 LK-X            BINARY-LONG.
01 LK-Y            BINARY-LONG.
01 LK-Z            BINARY-LONG.
01 LK-R            BINARY-LONG.
01 LK-CALLS        BINARY-DOUBLE.
PROCEDURE DIVISION USING LK-X LK-Y LK-Z LK-R LK-CALLS.
TAK-PARA.
    ADD K-ONE-D TO LK-CALLS
    IF LK-Y < LK-X
       MOVE LK-X TO WS-A1
       SUBTRACT K-ONE FROM WS-A1
       CALL EXT-FP USING BY CONTENT WS-A1 BY REFERENCE LK-Y LK-Z LS-T1 LK-CALLS
       MOVE LK-Y TO WS-A2
       SUBTRACT K-ONE FROM WS-A2
       CALL EXT-FP USING BY CONTENT WS-A2 BY REFERENCE LK-Z LK-X LS-T2 LK-CALLS
       MOVE LK-Z TO WS-A3
       SUBTRACT K-ONE FROM WS-A3
       CALL EXT-FP USING BY CONTENT WS-A3 BY REFERENCE LK-X LK-Y LS-T3 LK-CALLS
       CALL EXT-FP USING LS-T1 LS-T2 LS-T3 LK-R LK-CALLS
    ELSE
       MOVE LK-Z TO LK-R
    END-IF
    EXIT PROGRAM.
END PROGRAM TAK-FN.
