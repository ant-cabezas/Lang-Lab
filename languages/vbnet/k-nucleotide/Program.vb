Imports System
Imports System.Collections.Generic

Module KNucleotide
    Const K As Integer = 8
    Const P As Long = 1000000007L
    Const IM As Integer = 139968
    Const IA As Integer = 3877
    Const IC As Integer = 29573

    Function Gen(n As Integer) As String
        Dim s As Char() = New Char(n - 1) {}
        Dim seed As Long = 42
        For i As Integer = 0 To n - 1
            seed = (seed * IA + IC) Mod IM
            s(i) = If(seed < 42000, "A"c, If(seed < 70000, "C"c, If(seed < 98000, "G"c, "T"c)))
        Next
        Return New String(s)
    End Function

    Function Run(n As Integer) As Long
        Dim s As String = Gen(n)

        ' VB cannot use GetAlternateLookup(Of ReadOnlySpan(Of Char)) (see languages/vbnet/README),
        ' so each probe allocates its key string, like Java/Kotlin/Go.
        Dim map As New Dictionary(Of String, Long)()
        For i As Integer = 0 To n - K
            Dim kmer As String = s.Substring(i, K)
            Dim c As Long = 0
            map.TryGetValue(kmer, c)
            map(kmer) = c + 1
        Next

        Dim acc As Long = 0
        For Each kv As KeyValuePair(Of String, Long) In map
            Dim key As String = kv.Key
            Dim e As Long = 0
            For j As Integer = 0 To K - 1
                Dim ch As Char = key(j)
                Dim code As Integer = If(ch = "A"c, 0, If(ch = "C"c, 1, If(ch = "G"c, 2, 3)))
                e = e * 4 + code
            Next
            acc = (acc + e * kv.Value) Mod P
        Next
        Return acc
    End Function

    Sub Main(args As String())
        Dim n As Integer = If(args.Length > 0, Integer.Parse(args(0)), 100000)
        Console.WriteLine(Run(n))
        Console.WriteLine($"k-nucleotide({n})")
    End Sub
End Module
