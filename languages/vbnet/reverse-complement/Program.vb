' reverse-complement: generate a DNA sequence, reverse it in place while complementing each
' base (A<->T, C<->G) with a hand-written two-pointer loop, then reduce it to a polynomial
' hash with a per-character loop. Integer only.
Imports System

Module ReverseComplement
    Const P As Long = 1000000007L
    Const IM As Long = 139968
    Const IA As Long = 3877
    Const IC As Long = 29573
    Const CA As Byte = 65
    Const CC As Byte = 67
    Const CG As Byte = 71
    Const CT As Byte = 84

    Function Comp(c As Byte) As Byte ' A<->T, C<->G; only A/C/G/T occur
        Return If(c = CA, CT, If(c = CC, CG, If(c = CG, CC, CA)))
    End Function

    Sub Main(args As String())
        Dim len As Integer = If(args.Length > 0, Integer.Parse(args(0)), 100000)
        Dim s As Byte() = New Byte(len - 1) {}
        Dim seed As Long = 42
        For i As Integer = 0 To len - 1
            seed = (seed * IA + IC) Mod IM
            s(i) = If(seed < 42000, CA, If(seed < 70000, CC, If(seed < 98000, CG, CT)))
        Next

        Dim lo As Integer = 0
        Dim hi As Integer = len - 1
        While lo < hi ' two-pointer reverse-and-complement, in place
            Dim a As Byte = Comp(s(lo))
            s(lo) = Comp(s(hi))
            s(hi) = a
            lo += 1
            hi -= 1
        End While
        If lo = hi Then s(lo) = Comp(s(lo)) ' middle char when len is odd

        Dim h As Long = 0
        For k As Integer = 0 To len - 1
            h = (h * 31 + s(k)) Mod P ' s(k) is the ASCII byte value
        Next

        Console.WriteLine(h)
        Console.WriteLine($"reverse-complement({len})")
    End Sub
End Module
