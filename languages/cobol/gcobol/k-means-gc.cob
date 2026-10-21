>>SOURCE FORMAT FREE
*> k-means, gcobol variant (COBOL side study, GCC 15 front end). Same algorithm as k-means.cob: integer
*> Lloyd's clustering (K=16, D=4, ITERS=10, RANGE=256), initial centroids = first K points, strict <
*> lowest-index tie-break, floor-mean update, empty cluster unchanged, poly-hash of centroids + assignments.
*> Written for gcobol's inline-arithmetic rules: BINARY-LONG/BINARY-DOUBLE items only, every operand of a hot
*> ADD/SUBTRACT/MULTIPLY/DIVIDE/MOVE/IF is a variable (named constants K-xxx), every subscript is a plain
*> variable (the flat point/centroid indices are running counters), no COMPUTE/FUNCTION. Cluster ids in
*> ASG are stored 1-based (k + 1); the checksum subtracts 1 again.
IDENTIFICATION DIVISION.
PROGRAM-ID. k-means-gc.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-N            BINARY-LONG VALUE 8000.
01 WS-ARG          PIC X(16)         VALUE SPACES.
01 WS-NTOT         BINARY-LONG.
01 K-ZERO          BINARY-LONG VALUE 0.
01 K-ONE           BINARY-LONG VALUE 1.
01 K-FOUR          BINARY-LONG VALUE 4.
01 K-16            BINARY-LONG VALUE 16.
01 K-64            BINARY-LONG VALUE 64.
01 K-ITERS         BINARY-LONG VALUE 10.
01 K-NEG1          BINARY-LONG VALUE -1.
01 K-256           BINARY-DOUBLE VALUE 256.
01 K-LCG-A         BINARY-DOUBLE VALUE 1103515245.
01 K-LCG-C         BINARY-DOUBLE VALUE 12345.
01 K-LCG-M         BINARY-DOUBLE VALUE 2147483648.
01 K-31            BINARY-DOUBLE VALUE 31.
01 K-P             BINARY-DOUBLE VALUE 1000000007.
01 WS-S            BINARY-DOUBLE VALUE 42.
01 WS-T            BINARY-DOUBLE.
01 WS-Q            BINARY-DOUBLE.
01 WS-H            BINARY-DOUBLE VALUE 0.
01 WS-HV           BINARY-DOUBLE.
01 PT-T.
   05 PT           BINARY-LONG OCCURS 32000 TIMES.
01 CEN-T.
   05 CEN          BINARY-LONG OCCURS 64 TIMES.
01 SSUM-T.
   05 SSUM         BINARY-LONG OCCURS 64 TIMES.
01 CNT-T.
   05 CNT          BINARY-LONG OCCURS 16 TIMES.
01 ASG-T.
   05 ASG          BINARY-LONG OCCURS 8000 TIMES.
01 WS-I            BINARY-LONG.
01 WS-K            BINARY-LONG.
01 WS-D            BINARY-LONG.
01 WS-ITER         BINARY-LONG.
01 WS-BEST         BINARY-LONG.
01 WS-BD           BINARY-LONG.
01 WS-DIST         BINARY-LONG.
01 WS-DF           BINARY-LONG.
01 WS-SQ           BINARY-LONG.
01 WS-PSTART       BINARY-LONG.
01 WS-CSTART       BINARY-LONG.
01 WS-IP           BINARY-LONG.
01 WS-IC           BINARY-LONG.
01 WS-TMP          BINARY-LONG.
01 ED-CK           PIC -(18)9.
01 ED-N            PIC Z(8)9.
PROCEDURE DIVISION.
MAIN-PARA.
    ACCEPT WS-ARG FROM COMMAND-LINE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-N = FUNCTION NUMVAL(WS-ARG)
    END-IF

    *> generate N*D points via LCG
    MULTIPLY WS-N BY K-FOUR GIVING WS-NTOT
    PERFORM VARYING WS-I FROM K-ONE BY K-ONE UNTIL WS-I > WS-NTOT
       MULTIPLY WS-S BY K-LCG-A GIVING WS-T
       ADD K-LCG-C TO WS-T
       DIVIDE WS-T BY K-LCG-M GIVING WS-Q REMAINDER WS-S
       DIVIDE WS-S BY K-256 GIVING WS-Q REMAINDER PT(WS-I)
    END-PERFORM

    *> initial centroids = first K points (K*D = 64 values)
    PERFORM VARYING WS-I FROM K-ONE BY K-ONE UNTIL WS-I > K-64
       MOVE PT(WS-I) TO CEN(WS-I)
    END-PERFORM

    *> Lloyd iterations
    PERFORM VARYING WS-ITER FROM K-ZERO BY K-ONE UNTIL WS-ITER >= K-ITERS
       PERFORM ASSIGN-STEP

       *> update step: floor-mean, empty cluster unchanged
       PERFORM VARYING WS-I FROM K-ONE BY K-ONE UNTIL WS-I > K-64
          MOVE K-ZERO TO SSUM(WS-I)
       END-PERFORM
       PERFORM VARYING WS-K FROM K-ONE BY K-ONE UNTIL WS-K > K-16
          MOVE K-ZERO TO CNT(WS-K)
       END-PERFORM
       MOVE K-ONE TO WS-PSTART
       PERFORM VARYING WS-I FROM K-ONE BY K-ONE UNTIL WS-I > WS-N
          MOVE ASG(WS-I) TO WS-K
          ADD K-ONE TO CNT(WS-K)
          MOVE WS-K TO WS-TMP
          SUBTRACT K-ONE FROM WS-TMP
          MULTIPLY WS-TMP BY K-FOUR GIVING WS-CSTART
          ADD K-ONE TO WS-CSTART
          MOVE WS-PSTART TO WS-IP
          MOVE WS-CSTART TO WS-IC
          PERFORM VARYING WS-D FROM K-ZERO BY K-ONE UNTIL WS-D >= K-FOUR
             ADD PT(WS-IP) TO SSUM(WS-IC)
             ADD K-ONE TO WS-IP
             ADD K-ONE TO WS-IC
          END-PERFORM
          ADD K-FOUR TO WS-PSTART
       END-PERFORM
       MOVE K-ONE TO WS-CSTART
       PERFORM VARYING WS-K FROM K-ONE BY K-ONE UNTIL WS-K > K-16
          IF CNT(WS-K) > K-ZERO
             MOVE WS-CSTART TO WS-IC
             PERFORM VARYING WS-D FROM K-ZERO BY K-ONE UNTIL WS-D >= K-FOUR
                DIVIDE SSUM(WS-IC) BY CNT(WS-K) GIVING CEN(WS-IC)
                ADD K-ONE TO WS-IC
             END-PERFORM
          END-IF
          ADD K-FOUR TO WS-CSTART
       END-PERFORM
    END-PERFORM

    *> final assignment with final centroids
    PERFORM ASSIGN-STEP

    *> checksum: poly-hash final centroids then all assignments, mod 1e9+7
    MOVE K-ZERO TO WS-H
    PERFORM VARYING WS-I FROM K-ONE BY K-ONE UNTIL WS-I > K-64
       MOVE CEN(WS-I) TO WS-HV
       MULTIPLY WS-H BY K-31 GIVING WS-T
       ADD WS-HV TO WS-T
       DIVIDE WS-T BY K-P GIVING WS-Q REMAINDER WS-H
    END-PERFORM
    PERFORM VARYING WS-I FROM K-ONE BY K-ONE UNTIL WS-I > WS-N
       MOVE ASG(WS-I) TO WS-HV
       SUBTRACT K-ONE FROM WS-HV
       MULTIPLY WS-H BY K-31 GIVING WS-T
       ADD WS-HV TO WS-T
       DIVIDE WS-T BY K-P GIVING WS-Q REMAINDER WS-H
    END-PERFORM

    MOVE WS-H TO ED-CK
    MOVE WS-N TO ED-N
    DISPLAY FUNCTION TRIM(ED-CK)
    DISPLAY "k-means(" FUNCTION TRIM(ED-N) ")"
    STOP RUN.

*> assignment step: nearest centroid by integer squared distance, STRICT < (lowest k wins)
ASSIGN-STEP.
    MOVE K-ONE TO WS-PSTART
    PERFORM VARYING WS-I FROM K-ONE BY K-ONE UNTIL WS-I > WS-N
       MOVE K-ONE  TO WS-BEST
       MOVE K-NEG1 TO WS-BD
       MOVE K-ONE  TO WS-CSTART
       PERFORM VARYING WS-K FROM K-ONE BY K-ONE UNTIL WS-K > K-16
          MOVE K-ZERO TO WS-DIST
          MOVE WS-PSTART TO WS-IP
          MOVE WS-CSTART TO WS-IC
          PERFORM VARYING WS-D FROM K-ZERO BY K-ONE UNTIL WS-D >= K-FOUR
             MOVE PT(WS-IP) TO WS-DF
             SUBTRACT CEN(WS-IC) FROM WS-DF
             MULTIPLY WS-DF BY WS-DF GIVING WS-SQ
             ADD WS-SQ TO WS-DIST
             ADD K-ONE TO WS-IP
             ADD K-ONE TO WS-IC
          END-PERFORM
          IF WS-BD < K-ZERO OR WS-DIST < WS-BD
             MOVE WS-DIST TO WS-BD
             MOVE WS-K    TO WS-BEST
          END-IF
          ADD K-FOUR TO WS-CSTART
       END-PERFORM
       MOVE WS-BEST TO ASG(WS-I)
       ADD K-FOUR TO WS-PSTART
    END-PERFORM
    .
