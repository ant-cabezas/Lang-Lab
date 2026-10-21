' viterbi: integer HMM sequence decoding, the max-plus trellis. NST=8 states, ALPHA=4 symbols,
' T = size. LCG (seed 42) draws trans, emit, obs in that order. Forward pass with STRICT >
' (lowest index wins), then a pointer-chain backtrace. Checksum = poly-hash of (path+1);
' secondary = optimal path score mod P. Pure integer.
Imports System

Module Viterbi
    Const NST As Integer = 8
    Const ALPHA As Integer = 4
    Const P As Long = 1000000007L

    Function Lcg(s As Long) As Long
        Return (s * 1103515245L + 12345L) And &H7FFFFFFFL
    End Function

    Function Run(t As Integer) As (Long, Long)
        ' Draw order: trans(S*S), emit(S*ALPHA), obs(T)
        Dim trans As Long() = New Long(NST * NST - 1) {}
        Dim emit As Long() = New Long(NST * ALPHA - 1) {}
        Dim obs As Integer() = New Integer(t - 1) {}
        Dim s As Long = 42L
        For x As Integer = 0 To NST * NST - 1
            s = Lcg(s)
            trans(x) = s Mod 100 + 1
        Next
        For x As Integer = 0 To NST * ALPHA - 1
            s = Lcg(s)
            emit(x) = s Mod 100 + 1
        Next
        For i As Integer = 0 To t - 1
            s = Lcg(s)
            obs(i) = CInt(s Mod ALPHA)
        Next

        ' Initialise t=0
        Dim vitPrev As Long() = New Long(NST - 1) {}
        Dim vitNext As Long() = New Long(NST - 1) {}
        For j As Integer = 0 To NST - 1
            vitPrev(j) = emit(j * ALPHA + obs(0))
        Next

        Dim back As Integer() = New Integer(t * NST - 1) {}

        ' Forward trellis t=1..T-1
        For ti As Integer = 1 To t - 1
            For j As Integer = 0 To NST - 1
                Dim best As Long = -1L
                Dim bi As Integer = 0
                Dim e As Long = emit(j * ALPHA + obs(ti))
                For i As Integer = 0 To NST - 1
                    Dim sc As Long = vitPrev(i) + trans(i * NST + j) + e
                    If sc > best Then ' STRICT > -> lowest i wins
                        best = sc
                        bi = i
                    End If
                Next
                vitNext(j) = best
                back(ti * NST + j) = bi
            Next
            Dim tmp As Long() = vitPrev
            vitPrev = vitNext
            vitNext = tmp
        Next

        ' Final state: STRICT > -> lowest j wins
        Dim bf As Integer = 0
        For j As Integer = 1 To NST - 1
            If vitPrev(j) > vitPrev(bf) Then bf = j
        Next

        ' Backtrace
        Dim path As Integer() = New Integer(t - 1) {}
        path(t - 1) = bf
        For ti As Integer = t - 2 To 0 Step -1
            path(ti) = back((ti + 1) * NST + path(ti + 1))
        Next

        ' Checksum
        Dim h As Long = 0L
        For ti As Integer = 0 To t - 1
            h = (h * 31L + path(ti) + 1L) Mod P
        Next

        Dim secondary As Long = vitPrev(bf) Mod P
        Return (h, secondary)
    End Function

    Sub Main(args As String())
        Dim t As Integer = If(args.Length > 0, Integer.Parse(args(0)), 20000)
        Dim r = Run(t)
        Console.WriteLine(r.Item1)
        Console.WriteLine($"viterbi({t}) = {r.Item2}")
    End Sub
End Module
