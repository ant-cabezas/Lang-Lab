' vm: a tiny stack-based bytecode virtual machine running a FIXED program (PROG, shared verbatim
' by every language) that computes acc = (acc*31 + i*i) mod 2^32 over i in 0..N-1.
' All VM values are 64-bit (products fit); arithmetic ops mask to 32 bits.
Imports System

Module Vm
    Const P As Long = 1000000007L
    Const MASK As Long = &HFFFFFFFFL

    ' opcodes: 0 PUSH imm, 1 LOAD slot, 2 STORE slot, 3 ADD, 4 MUL, 5 SUB, 6 LT, 7 JZ addr, 8 JMP addr, 9 HALT
    ReadOnly PROG As Long() = New Long() {0, 0, 2, 0, 0, 0, 2, 1, 1, 0, 1, 2, 6, 7, 37, 1, 1, 0, 31, 4, 1, 0, 1, 0, 4, 3, 2, 1, 1, 0, 0, 1, 3, 2, 0, 8, 8, 1, 1, 9}

    Function Run(n As Integer) As Long
        Dim stack As Long() = New Long(63) {}
        Dim sp As Integer = 0
        Dim locals As Long() = New Long() {0, 0, n}
        Dim pc As Integer = 0
        Dim result As Long = 0
        Do
            Dim op As Long = PROG(pc)
            pc += 1
            If op = 0 Then
                stack(sp) = PROG(pc)
                sp += 1
                pc += 1
            ElseIf op = 1 Then
                stack(sp) = locals(CInt(PROG(pc)))
                sp += 1
                pc += 1
            ElseIf op = 2 Then
                sp -= 1
                locals(CInt(PROG(pc))) = stack(sp)
                pc += 1
            ElseIf op = 3 Then
                sp -= 1
                Dim b As Long = stack(sp)
                sp -= 1
                Dim a As Long = stack(sp)
                stack(sp) = (a + b) And MASK
                sp += 1
            ElseIf op = 4 Then
                sp -= 1
                Dim b As Long = stack(sp)
                sp -= 1
                Dim a As Long = stack(sp)
                stack(sp) = (a * b) And MASK
                sp += 1
            ElseIf op = 5 Then
                sp -= 1
                Dim b As Long = stack(sp)
                sp -= 1
                Dim a As Long = stack(sp)
                stack(sp) = (a - b) And MASK
                sp += 1
            ElseIf op = 6 Then
                sp -= 1
                Dim b As Long = stack(sp)
                sp -= 1
                Dim a As Long = stack(sp)
                stack(sp) = If(a < b, 1L, 0L)
                sp += 1
            ElseIf op = 7 Then
                sp -= 1
                Dim c As Long = stack(sp)
                If c = 0 Then
                    pc = CInt(PROG(pc))
                Else
                    pc += 1
                End If
            ElseIf op = 8 Then
                pc = CInt(PROG(pc))
            ElseIf op = 9 Then
                result = stack(sp - 1)
                Exit Do
            End If
        Loop
        Return result Mod P
    End Function

    Sub Main(args As String())
        Dim n As Integer = If(args.Length > 0, Integer.Parse(args(0)), 800000)
        Console.WriteLine(Run(n))
        Console.WriteLine($"vm({n})")
    End Sub
End Module
