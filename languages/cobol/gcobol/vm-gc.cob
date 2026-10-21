>>SOURCE FORMAT FREE
*> vm, gcobol variant (COBOL side study, GCC 15 front end). Same bytecode VM and the same FIXED 40-int PROG
*> (embedded verbatim) as vm.cob: acc = (acc*31 + i*i) mod 2^32 over i in 0..N-1, 64-bit stack/locals, MUL
*> product before the mask. Written for gcobol's inline-arithmetic rules: BINARY-LONG / BINARY-DOUBLE items
*> only, every operand of a hot ADD/SUBTRACT/MULTIPLY/DIVIDE/MOVE/IF/EVALUATE is a variable (named constants
*> K-xxx, no literals), every subscript is a plain variable (PROG(pc), LOC(slot) are 1-based, so PC and
*> jump targets get an explicit ADD of 1), no COMPUTE / FUNCTION MOD (the 2^32 mask is DIVIDE ... REMAINDER).
IDENTIFICATION DIVISION.
PROGRAM-ID. vm-gc.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-N            BINARY-DOUBLE VALUE 800000.
01 WS-ARG          PIC X(16)         VALUE SPACES.
01 PROG-T.
   05 FILLER       BINARY-LONG VALUE 0.
   05 FILLER       BINARY-LONG VALUE 0.
   05 FILLER       BINARY-LONG VALUE 2.
   05 FILLER       BINARY-LONG VALUE 0.
   05 FILLER       BINARY-LONG VALUE 0.
   05 FILLER       BINARY-LONG VALUE 0.
   05 FILLER       BINARY-LONG VALUE 2.
   05 FILLER       BINARY-LONG VALUE 1.
   05 FILLER       BINARY-LONG VALUE 1.
   05 FILLER       BINARY-LONG VALUE 0.
   05 FILLER       BINARY-LONG VALUE 1.
   05 FILLER       BINARY-LONG VALUE 2.
   05 FILLER       BINARY-LONG VALUE 6.
   05 FILLER       BINARY-LONG VALUE 7.
   05 FILLER       BINARY-LONG VALUE 37.
   05 FILLER       BINARY-LONG VALUE 1.
   05 FILLER       BINARY-LONG VALUE 1.
   05 FILLER       BINARY-LONG VALUE 0.
   05 FILLER       BINARY-LONG VALUE 31.
   05 FILLER       BINARY-LONG VALUE 4.
   05 FILLER       BINARY-LONG VALUE 1.
   05 FILLER       BINARY-LONG VALUE 0.
   05 FILLER       BINARY-LONG VALUE 1.
   05 FILLER       BINARY-LONG VALUE 0.
   05 FILLER       BINARY-LONG VALUE 4.
   05 FILLER       BINARY-LONG VALUE 3.
   05 FILLER       BINARY-LONG VALUE 2.
   05 FILLER       BINARY-LONG VALUE 1.
   05 FILLER       BINARY-LONG VALUE 1.
   05 FILLER       BINARY-LONG VALUE 0.
   05 FILLER       BINARY-LONG VALUE 0.
   05 FILLER       BINARY-LONG VALUE 1.
   05 FILLER       BINARY-LONG VALUE 3.
   05 FILLER       BINARY-LONG VALUE 2.
   05 FILLER       BINARY-LONG VALUE 0.
   05 FILLER       BINARY-LONG VALUE 8.
   05 FILLER       BINARY-LONG VALUE 8.
   05 FILLER       BINARY-LONG VALUE 1.
   05 FILLER       BINARY-LONG VALUE 1.
   05 FILLER       BINARY-LONG VALUE 9.
01 PROG-R REDEFINES PROG-T.
   05 PROG         BINARY-LONG OCCURS 40 TIMES.
01 STACK-T.
   05 STK          BINARY-DOUBLE OCCURS 64 TIMES.
01 LOCALS-T.
   05 LOC          BINARY-DOUBLE OCCURS 3 TIMES.
01 WS-SP           BINARY-LONG VALUE 0.
01 WS-PC           BINARY-LONG VALUE 1.
01 WS-OP           BINARY-LONG.
01 WS-SLOT         BINARY-LONG.
01 WS-A            BINARY-DOUBLE.
01 WS-B            BINARY-DOUBLE.
01 WS-C            BINARY-DOUBLE.
01 WS-T            BINARY-DOUBLE.
01 WS-Q            BINARY-DOUBLE.
01 WS-RESULT       BINARY-DOUBLE VALUE 0.
01 WS-OUT          BINARY-DOUBLE.
01 WS-RUNNING      BINARY-LONG VALUE 1.
01 K-ZERO          BINARY-LONG VALUE 0.
01 K-ONE           BINARY-LONG VALUE 1.
01 K-OP0           BINARY-LONG VALUE 0.
01 K-OP1           BINARY-LONG VALUE 1.
01 K-OP2           BINARY-LONG VALUE 2.
01 K-OP3           BINARY-LONG VALUE 3.
01 K-OP4           BINARY-LONG VALUE 4.
01 K-OP5           BINARY-LONG VALUE 5.
01 K-OP6           BINARY-LONG VALUE 6.
01 K-OP7           BINARY-LONG VALUE 7.
01 K-OP8           BINARY-LONG VALUE 8.
01 K-OP9           BINARY-LONG VALUE 9.
01 K-ZERO-D        BINARY-DOUBLE VALUE 0.
01 K-ONE-D         BINARY-DOUBLE VALUE 1.
01 MASK32          BINARY-DOUBLE VALUE 4294967296.
01 MODP            BINARY-DOUBLE VALUE 1000000007.
01 ED-CK           PIC -(18)9.
01 ED-N            PIC -(18)9.
PROCEDURE DIVISION.
MAIN-PARA.
    ACCEPT WS-ARG FROM COMMAND-LINE
    IF WS-ARG NOT = SPACES
       COMPUTE WS-N = FUNCTION NUMVAL(WS-ARG)
    END-IF

    *> locals[0]=0, locals[1]=0, locals[2]=N ; pc=0 (PC is 1-based: PC = pc + 1) ; sp=0
    MOVE K-ZERO-D TO LOC(1)
    MOVE K-ZERO-D TO LOC(2)
    MOVE WS-N     TO LOC(3)
    MOVE K-ZERO   TO WS-SP
    MOVE K-ONE    TO WS-PC

    PERFORM UNTIL WS-RUNNING = K-ZERO
       *> op = PROG[pc++]
       MOVE PROG(WS-PC) TO WS-OP
       ADD K-ONE TO WS-PC
       EVALUATE WS-OP
          WHEN K-OP0
             *> PUSH imm: stack[sp++]=PROG[pc++]
             ADD K-ONE TO WS-SP
             MOVE PROG(WS-PC) TO STK(WS-SP)
             ADD K-ONE TO WS-PC
          WHEN K-OP1
             *> LOAD slot: stack[sp++]=locals[PROG[pc++]]
             ADD K-ONE TO WS-SP
             MOVE PROG(WS-PC) TO WS-SLOT
             ADD K-ONE TO WS-SLOT
             MOVE LOC(WS-SLOT) TO STK(WS-SP)
             ADD K-ONE TO WS-PC
          WHEN K-OP2
             *> STORE slot: locals[PROG[pc++]]=stack[--sp]
             MOVE PROG(WS-PC) TO WS-SLOT
             ADD K-ONE TO WS-SLOT
             MOVE STK(WS-SP) TO LOC(WS-SLOT)
             SUBTRACT K-ONE FROM WS-SP
             ADD K-ONE TO WS-PC
          WHEN K-OP3
             *> ADD: b=stack[--sp],a=stack[--sp]; stack[sp++]=(a+b)&MASK
             MOVE STK(WS-SP) TO WS-B
             SUBTRACT K-ONE FROM WS-SP
             MOVE STK(WS-SP) TO WS-A
             MOVE WS-A TO WS-T
             ADD WS-B TO WS-T
             DIVIDE WS-T BY MASK32 GIVING WS-Q REMAINDER WS-C
             MOVE WS-C TO STK(WS-SP)
          WHEN K-OP4
             *> MUL: stack[sp++]=(a*b)&MASK  (64-bit product before mask)
             MOVE STK(WS-SP) TO WS-B
             SUBTRACT K-ONE FROM WS-SP
             MOVE STK(WS-SP) TO WS-A
             MULTIPLY WS-A BY WS-B GIVING WS-T
             DIVIDE WS-T BY MASK32 GIVING WS-Q REMAINDER WS-C
             MOVE WS-C TO STK(WS-SP)
          WHEN K-OP5
             *> SUB: stack[sp++]=(a-b)&MASK  (remainder made non-negative)
             MOVE STK(WS-SP) TO WS-B
             SUBTRACT K-ONE FROM WS-SP
             MOVE STK(WS-SP) TO WS-A
             MOVE WS-A TO WS-T
             SUBTRACT WS-B FROM WS-T
             DIVIDE WS-T BY MASK32 GIVING WS-Q REMAINDER WS-C
             IF WS-C < K-ZERO-D
                ADD MASK32 TO WS-C
             END-IF
             MOVE WS-C TO STK(WS-SP)
          WHEN K-OP6
             *> LT: stack[sp++]=(a<b)?1:0
             MOVE STK(WS-SP) TO WS-B
             SUBTRACT K-ONE FROM WS-SP
             MOVE STK(WS-SP) TO WS-A
             IF WS-A < WS-B
                MOVE K-ONE-D TO STK(WS-SP)
             ELSE
                MOVE K-ZERO-D TO STK(WS-SP)
             END-IF
          WHEN K-OP7
             *> JZ addr: c=stack[--sp]; if c==0 pc=PROG[pc] else pc++
             MOVE STK(WS-SP) TO WS-C
             SUBTRACT K-ONE FROM WS-SP
             IF WS-C = K-ZERO-D
                MOVE PROG(WS-PC) TO WS-PC
                ADD K-ONE TO WS-PC
             ELSE
                ADD K-ONE TO WS-PC
             END-IF
          WHEN K-OP8
             *> JMP addr: pc=PROG[pc]
             MOVE PROG(WS-PC) TO WS-PC
             ADD K-ONE TO WS-PC
          WHEN K-OP9
             *> HALT: result=stack[sp-1]; break
             MOVE STK(WS-SP) TO WS-RESULT
             MOVE K-ZERO TO WS-RUNNING
       END-EVALUATE
    END-PERFORM

    DIVIDE WS-RESULT BY MODP GIVING WS-Q REMAINDER WS-OUT
    MOVE WS-OUT TO ED-CK
    MOVE WS-N   TO ED-N
    DISPLAY FUNCTION TRIM(ED-CK)
    DISPLAY "vm(" FUNCTION TRIM(ED-N) ")"
    STOP RUN.
