' lz77: hand-written LZ77 compressor (sliding window, brute-force longest match, closest wins
' ties, greedy parse); the token stream is reduced to a polynomial hash. All integer.
Imports System

Module Lz77
    Const P As Long = 1000000007L
    Const WINDOW As Integer = 512
    Const MIN_MATCH As Integer = 3
    Const MAX_MATCH As Integer = 255
    Const ALPHA As Integer = 6

    Function Run(n As Integer) As Long
        Dim inp As Byte() = New Byte(n - 1) {}
        Dim s As Long = 42
        For i As Integer = 0 To n - 1
            s = (s * 1103515245L + 12345L) And &H7FFFFFFFL
            inp(i) = CByte(s Mod ALPHA)
        Next

        Dim pos As Integer = 0
        Dim h As Long = 0
        While pos < n
            Dim bestLen As Integer = 0
            Dim bestDist As Integer = 0
            Dim start As Integer = pos - WINDOW
            If start < 0 Then start = 0
            For cand As Integer = pos - 1 To start Step -1 ' closest distance first
                Dim l As Integer = 0
                While pos + l < n AndAlso l < MAX_MATCH AndAlso inp(cand + l) = inp(pos + l)
                    l += 1
                End While
                If l > bestLen Then ' strict > : closest wins ties
                    bestLen = l
                    bestDist = pos - cand
                End If
            Next
            If bestLen >= MIN_MATCH Then
                h = (h * 31 + 1) Mod P
                h = (h * 31 + bestDist) Mod P
                h = (h * 31 + bestLen) Mod P
                pos += bestLen
            Else
                h = (h * 31 + 0) Mod P
                h = (h * 31 + inp(pos)) Mod P
                pos += 1
            End If
        End While
        Return h
    End Function

    Sub Main(args As String())
        Dim n As Integer = If(args.Length > 0, Integer.Parse(args(0)), 24000)
        Console.WriteLine(Run(n))
        Console.WriteLine($"lz77({n})")
    End Sub
End Module
