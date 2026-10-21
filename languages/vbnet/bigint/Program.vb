' bigint: hand-rolled multi-precision arithmetic. Compute N! as base-2^32 limbs by repeated
' bignum*smallint multiplication (cur = limb*k + carry; keep low 32 bits, propagate the rest),
' then poly-hash the limbs. No System.Numerics.BigInteger. Limbs live in Long (UInteger/ULong
' arithmetic is overflow-checked in VB and is not used).
Imports System

Module BigInt
    Const P As Long = 1000000007L
    Const MASK As Long = &HFFFFFFFFL

    Function Run(n As Integer) As Long
        ' limbs: least-significant limb first, base 2^32. The big number IS this array.
        Dim limbs As Long() = New Long(n + 63) {}
        Dim len As Integer = 1
        limbs(0) = 1

        For k As Long = 2 To n
            Dim carry As Long = 0
            For i As Integer = 0 To len - 1
                Dim cur As Long = limbs(i) * k + carry ' 64-bit intermediate (~2^46)
                limbs(i) = cur And MASK ' low 32 bits stay
                carry = cur >> 32 ' high bits propagate
            Next
            While carry > 0
                limbs(len) = carry And MASK
                len += 1
                carry >>= 32
            End While
        Next

        Dim h As Long = 0
        For i As Integer = 0 To len - 1 ' poly-hash, least-significant limb first
            h = (h * 31 + limbs(i)) Mod P
        Next
        Return h
    End Function

    Sub Main(args As String())
        Dim n As Integer = If(args.Length > 0, Integer.Parse(args(0)), 6000)
        Console.WriteLine(Run(n))
        Console.WriteLine($"bigint({n})")
    End Sub
End Module
