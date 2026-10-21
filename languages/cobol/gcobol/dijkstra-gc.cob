>>SOURCE FORMAT FREE
*> dijkstra, gcobol variant (COBOL side study, GCC 15 front end). Same algorithm as dijkstra.cob: LCG digraph
*> (N nodes, 8N edges, weights 1..100), CSR adjacency, HAND-WRITTEN binary min-heap of packed keys
*> dist*2^21 + node, poly-hash of dist[]. Written for gcobol's inline-arithmetic rules: BINARY-LONG /
*> BINARY-DOUBLE items only, every operand of a hot ADD/SUBTRACT/MULTIPLY/DIVIDE/MOVE/IF is a variable
*> (named constants K-xxx), every subscript is a plain variable, no COMPUTE/FUNCTION. Nodes and heap slots
*> are 1-based (node ids are shifted by +1, which keeps every packed-key comparison, hence every heap
*> operation, identical; heap parent of slot j is j/2, children 2j and 2j+1).
IDENTIFICATION DIVISION.
PROGRAM-ID. dijkstra-gc.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-N            BINARY-LONG VALUE 10000.
01 WS-ND-N         BINARY-DOUBLE.
01 WS-ARG          PIC X(16)         VALUE SPACES.
01 WS-M            BINARY-LONG.
01 WS-S            BINARY-DOUBLE VALUE 42.
01 WS-T            BINARY-DOUBLE.
01 WS-Q            BINARY-DOUBLE.
01 WS-E            BINARY-LONG.
01 WS-I            BINARY-LONG.
01 WS-I2           BINARY-LONG.
01 WS-POS          BINARY-LONG.
01 WS-U            BINARY-LONG.
01 WS-U2           BINARY-LONG.
01 WS-V            BINARY-LONG.
01 WS-EEND         BINARY-LONG.
01 WS-D            BINARY-DOUBLE.
01 WS-ND           BINARY-DOUBLE.
01 WS-KEY          BINARY-DOUBLE.
01 WS-DI           BINARY-DOUBLE.
01 WS-H            BINARY-DOUBLE VALUE 0.

*> constants
01 K-ZERO          BINARY-LONG VALUE 0.
01 K-ONE           BINARY-LONG VALUE 1.
01 K-TWO           BINARY-LONG VALUE 2.
01 K-EIGHT         BINARY-LONG VALUE 8.
01 K-P             BINARY-DOUBLE VALUE 1000000007.
01 K-31            BINARY-DOUBLE VALUE 31.
01 K-INF           BINARY-DOUBLE VALUE 4611686018427387904.
01 K-BASE          BINARY-DOUBLE VALUE 2097152.
01 K-MAXW          BINARY-DOUBLE VALUE 100.
01 K-LCG-A         BINARY-DOUBLE VALUE 1103515245.
01 K-LCG-C         BINARY-DOUBLE VALUE 12345.
01 K-LCG-M         BINARY-DOUBLE VALUE 2147483648.

*> edge arrays (M = 8N; size for n2=20000 -> 160000)
01 EDGE-U-T.
   05 E-U          BINARY-LONG OCCURS 160000 TIMES.
01 EDGE-V-T.
   05 E-V          BINARY-LONG OCCURS 160000 TIMES.
01 EDGE-W-T.
   05 E-W          BINARY-LONG OCCURS 160000 TIMES.

*> CSR adjacency
01 START-T.
   05 ST           BINARY-LONG OCCURS 20001 TIMES.
01 CNT-T.
   05 CN           BINARY-LONG OCCURS 20000 TIMES.
01 ADJV-T.
   05 ADJV         BINARY-LONG OCCURS 160000 TIMES.
01 ADJW-T.
   05 ADJW         BINARY-LONG OCCURS 160000 TIMES.

*> dist[]
01 DIST-T.
   05 DST          BINARY-DOUBLE OCCURS 20000 TIMES.

*> binary min-heap of packed keys (1-based, size M+1)
01 HEAP-T.
   05 HP           BINARY-DOUBLE OCCURS 160001 TIMES.
01 WS-HSIZE        BINARY-LONG VALUE 0.

01 HI              BINARY-LONG.
01 HP-PAR          BINARY-LONG.
01 HL              BINARY-LONG.
01 HR              BINARY-LONG.
01 HM              BINARY-LONG.
01 HS1             BINARY-LONG.
01 HT              BINARY-DOUBLE.
01 PUSH-K          BINARY-DOUBLE.
01 POP-TOP         BINARY-DOUBLE.
01 BREAK-FLAG      BINARY-LONG.

01 ED-CK           PIC -(18)9.
01 ED-N            PIC Z(8)9.
PROCEDURE DIVISION.
MAIN-PARA.
    ACCEPT WS-ARG FROM COMMAND-LINE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-N = FUNCTION NUMVAL(WS-ARG)
    END-IF
    MOVE WS-N TO WS-ND-N
    MULTIPLY K-EIGHT BY WS-N GIVING WS-M

    *> generate edges (1-based node ids: u = s mod N + 1)
    PERFORM VARYING WS-E FROM K-ONE BY K-ONE UNTIL WS-E > WS-M
       PERFORM LCG-STEP
       DIVIDE WS-S BY WS-ND-N GIVING WS-Q REMAINDER E-U(WS-E)
       ADD K-ONE TO E-U(WS-E)
       PERFORM LCG-STEP
       DIVIDE WS-S BY WS-ND-N GIVING WS-Q REMAINDER E-V(WS-E)
       ADD K-ONE TO E-V(WS-E)
       PERFORM LCG-STEP
       DIVIDE WS-S BY K-MAXW GIVING WS-Q REMAINDER E-W(WS-E)
       ADD K-ONE TO E-W(WS-E)
    END-PERFORM

    *> CSR adjacency in forward (edge-generation) order; ST(u) = 0-based start offset of node u
    MOVE WS-N TO WS-I2
    ADD K-ONE TO WS-I2
    PERFORM VARYING WS-I FROM K-ONE BY K-ONE UNTIL WS-I > WS-I2
       MOVE K-ZERO TO ST(WS-I)
    END-PERFORM
    *> count[u + 1]++
    PERFORM VARYING WS-E FROM K-ONE BY K-ONE UNTIL WS-E > WS-M
       MOVE E-U(WS-E) TO WS-U
       MOVE WS-U TO WS-U2
       ADD K-ONE TO WS-U2
       ADD K-ONE TO ST(WS-U2)
    END-PERFORM
    *> prefix sums: ST(i + 1) += ST(i), i = 1..N
    PERFORM VARYING WS-I FROM K-ONE BY K-ONE UNTIL WS-I > WS-N
       MOVE WS-I TO WS-I2
       ADD K-ONE TO WS-I2
       ADD ST(WS-I) TO ST(WS-I2)
    END-PERFORM
    PERFORM VARYING WS-I FROM K-ONE BY K-ONE UNTIL WS-I > WS-N
       MOVE K-ZERO TO CN(WS-I)
    END-PERFORM
    *> scatter into adjV/adjW: pos = start[u] + cnt[u]++ (ADJ index = pos + 1)
    PERFORM VARYING WS-E FROM K-ONE BY K-ONE UNTIL WS-E > WS-M
       MOVE E-U(WS-E) TO WS-U
       MOVE ST(WS-U) TO WS-POS
       ADD CN(WS-U) TO WS-POS
       ADD K-ONE TO WS-POS
       ADD K-ONE TO CN(WS-U)
       MOVE E-V(WS-E) TO ADJV(WS-POS)
       MOVE E-W(WS-E) TO ADJW(WS-POS)
    END-PERFORM

    *> dist[] = INF, dist[source node 1] = 0
    PERFORM VARYING WS-I FROM K-ONE BY K-ONE UNTIL WS-I > WS-N
       MOVE K-INF TO DST(WS-I)
    END-PERFORM
    MOVE K-ZERO TO DST(K-ONE)

    *> heap: push key 0 + node 1
    MOVE K-ZERO TO WS-HSIZE
    MOVE K-ONE TO PUSH-K
    PERFORM HPUSH

    PERFORM UNTIL WS-HSIZE <= K-ZERO
       PERFORM HPOP
       MOVE POP-TOP TO WS-KEY
       DIVIDE WS-KEY BY K-BASE GIVING WS-D REMAINDER WS-U
       *> stale heap entry?
       IF WS-D <= DST(WS-U)
          *> relax edges ST(u)+1 .. ST(u+1)
          MOVE WS-U TO WS-U2
          ADD K-ONE TO WS-U2
          MOVE ST(WS-U) TO WS-E
          ADD K-ONE TO WS-E
          MOVE ST(WS-U2) TO WS-EEND
          PERFORM UNTIL WS-E > WS-EEND
             MOVE ADJV(WS-E) TO WS-V
             MOVE WS-D TO WS-ND
             ADD ADJW(WS-E) TO WS-ND
             IF WS-ND < DST(WS-V)
                MOVE WS-ND TO DST(WS-V)
                MULTIPLY WS-ND BY K-BASE GIVING PUSH-K
                ADD WS-V TO PUSH-K
                PERFORM HPUSH
             END-IF
             ADD K-ONE TO WS-E
          END-PERFORM
       END-IF
    END-PERFORM

    *> checksum: poly-hash of dist[] (unreachable -> 0)
    MOVE K-ZERO TO WS-H
    PERFORM VARYING WS-I FROM K-ONE BY K-ONE UNTIL WS-I > WS-N
       IF DST(WS-I) < K-INF
          MOVE DST(WS-I) TO WS-DI
       ELSE
          MOVE K-ZERO TO WS-DI
       END-IF
       DIVIDE WS-DI BY K-P GIVING WS-Q REMAINDER WS-DI
       MULTIPLY WS-H BY K-31 GIVING WS-T
       ADD WS-DI TO WS-T
       DIVIDE WS-T BY K-P GIVING WS-Q REMAINDER WS-H
    END-PERFORM

    MOVE WS-H TO ED-CK
    MOVE WS-N TO ED-N
    DISPLAY FUNCTION TRIM(ED-CK)
    DISPLAY "dijkstra(" FUNCTION TRIM(ED-N) ")"
    STOP RUN.

*> s = (s * 1103515245 + 12345) & 0x7fffffff
LCG-STEP.
    MULTIPLY WS-S BY K-LCG-A GIVING WS-T
    ADD K-LCG-C TO WS-T
    DIVIDE WS-T BY K-LCG-M GIVING WS-Q REMAINDER WS-S
    .

*> hpush(PUSH-K): append at slot hsize + 1, sift up
HPUSH.
    ADD K-ONE TO WS-HSIZE
    MOVE WS-HSIZE TO HI
    MOVE PUSH-K TO HP(HI)
    MOVE K-ZERO TO BREAK-FLAG
    PERFORM UNTIL HI <= K-ONE OR BREAK-FLAG = K-ONE
       DIVIDE HI BY K-TWO GIVING HP-PAR
       IF HP(HP-PAR) <= HP(HI)
          MOVE K-ONE TO BREAK-FLAG
       ELSE
          MOVE HP(HP-PAR) TO HT
          MOVE HP(HI)     TO HP(HP-PAR)
          MOVE HT         TO HP(HI)
          MOVE HP-PAR TO HI
       END-IF
    END-PERFORM
    .

*> hpop -> POP-TOP: take slot 1, move the last slot to the root, sift down
HPOP.
    MOVE HP(K-ONE) TO POP-TOP
    MOVE WS-HSIZE TO HS1
    SUBTRACT K-ONE FROM WS-HSIZE
    MOVE HP(HS1) TO HP(K-ONE)
    MOVE K-ONE TO HI
    MOVE K-ZERO TO BREAK-FLAG
    PERFORM UNTIL BREAK-FLAG = K-ONE
       MOVE HI TO HL
       ADD HI TO HL
       MOVE HL TO HR
       ADD K-ONE TO HR
       MOVE HI TO HM
       IF HL <= WS-HSIZE
          IF HP(HL) < HP(HM)
             MOVE HL TO HM
          END-IF
       END-IF
       IF HR <= WS-HSIZE
          IF HP(HR) < HP(HM)
             MOVE HR TO HM
          END-IF
       END-IF
       IF HM = HI
          MOVE K-ONE TO BREAK-FLAG
       ELSE
          MOVE HP(HM) TO HT
          MOVE HP(HI) TO HP(HM)
          MOVE HT     TO HP(HI)
          MOVE HM TO HI
       END-IF
    END-PERFORM
    .
