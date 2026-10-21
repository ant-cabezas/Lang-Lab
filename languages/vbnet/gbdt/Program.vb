' gbdt: gradient-boosted decision-tree ensemble inference. NT=200 trees of depth DEPTH=8 over
' NF=8 features, each a flat complete binary tree (NODES=511; children 2k+1 / 2k+2). For each
' sample traverse all trees (DEPTH compare-and-branch steps each) and sum the leaf values.
' Checksum: poly-hash of (acc+1) per sample; secondary = sum of acc mod P. All integer.
Imports System

Module Gbdt
    Const P As Long = 1000000007L
    Const DEPTH As Integer = 8
    Const NT As Integer = 200
    Const NF As Integer = 8
    Const NODES As Integer = 511 ' 2^(D+1) - 1
    Const LEAFSTART As Integer = 255 ' 2^D - 1

    Function Lcg(s As Long) As Long
        Return (s * 1103515245L + 12345L) And &H7FFFFFFFL
    End Function

    Function Run(n As Integer) As (Long, Long)
        Dim feat As Integer() = New Integer(NT * NODES - 1) {}
        Dim thr As Integer() = New Integer(NT * NODES - 1) {}
        Dim leafval As Integer() = New Integer(NT * NODES - 1) {}

        Dim s As Long = 42L
        For b As Integer = 0 To NT - 1
            Dim bbase As Integer = b * NODES
            For node As Integer = 0 To LEAFSTART - 1
                s = Lcg(s)
                feat(bbase + node) = CInt(s Mod NF)
                s = Lcg(s)
                thr(bbase + node) = CInt(s Mod 256)
            Next
            For node As Integer = LEAFSTART To NODES - 1
                s = Lcg(s)
                leafval(bbase + node) = CInt(s Mod 10)
            Next
        Next

        Dim sample As Integer() = New Integer(n * NF - 1) {}
        For i As Integer = 0 To n * NF - 1
            s = Lcg(s)
            sample(i) = CInt(s Mod 256)
        Next

        Dim h As Long = 0L
        Dim total As Long = 0L
        For i As Integer = 0 To n - 1
            Dim sbase As Integer = i * NF
            Dim acc As Long = 0L
            For b As Integer = 0 To NT - 1
                Dim bbase As Integer = b * NODES
                Dim node As Integer = 0
                For d As Integer = 0 To DEPTH - 1
                    node = If(sample(sbase + feat(bbase + node)) <= thr(bbase + node), 2 * node + 1, 2 * node + 2)
                Next
                acc += leafval(bbase + node)
            Next
            h = (h * 31 + acc + 1) Mod P
            total = (total + acc) Mod P
        Next
        Return (h, total)
    End Function

    Sub Main(args As String())
        Dim n As Integer = If(args.Length > 0, Integer.Parse(args(0)), 5000)
        Dim r = Run(n)
        Console.WriteLine(r.Item1)
        Console.WriteLine($"gbdt({n}) = {r.Item2}")
    End Sub
End Module
