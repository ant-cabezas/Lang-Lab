' sort-search: generate N integers, sort them with a hand-written median-of-three quicksort
' (Hoare partition), then run N binary searches and fold the found indices into a checksum.
' No stdlib Array.Sort/BinarySearch. All integer.
Imports System

Module SortSearch
    Const P As Long = 1000000007L

    Function LcgNext(s As Long) As Long
        Return (s * 1103515245L + 12345L) And &H7FFFFFFFL
    End Function

    Sub Swap(a As Long(), i As Integer, j As Integer)
        Dim t As Long = a(i)
        a(i) = a(j)
        a(j) = t
    End Sub

    ' median-of-three + Hoare partition, recurse both sides; depth stays ~log N.
    Sub Qsort(a As Long(), lo As Integer, hi As Integer)
        If lo >= hi Then Return
        Dim md As Integer = lo + (hi - lo) \ 2
        If a(md) < a(lo) Then Swap(a, lo, md)
        If a(hi) < a(lo) Then Swap(a, lo, hi)
        If a(hi) < a(md) Then Swap(a, md, hi)
        Dim pivot As Long = a(md)
        Dim i As Integer = lo - 1
        Dim j As Integer = hi + 1
        Do
            Do
                i += 1
            Loop While a(i) < pivot
            Do
                j -= 1
            Loop While a(j) > pivot
            If i >= j Then Exit Do
            Swap(a, i, j)
        Loop
        Qsort(a, lo, j)
        Qsort(a, j + 1, hi)
    End Sub

    Function Bsearch(a As Long(), n As Integer, key As Long) As Integer
        Dim lo As Integer = 0
        Dim hi As Integer = n - 1
        While lo <= hi
            Dim md As Integer = lo + (hi - lo) \ 2
            If a(md) < key Then
                lo = md + 1
            ElseIf a(md) > key Then
                hi = md - 1
            Else
                Return md
            End If
        End While
        Return -1
    End Function

    Sub Main(args As String())
        Dim n As Integer = If(args.Length > 0, Integer.Parse(args(0)), 100000)
        Dim a As Long() = New Long(n - 1) {}
        Dim state As Long = 42
        For i As Integer = 0 To n - 1
            state = LcgNext(state)
            a(i) = state
        Next
        Qsort(a, 0, n - 1)
        Dim h As Long = 0
        For q As Integer = 0 To n - 1
            state = LcgNext(state)
            Dim key As Long = a(CInt(state Mod n)) ' a value present in the sorted array -> a hit
            Dim idx As Integer = Bsearch(a, n, key)
            h = (h * 31 + (idx + 1)) Mod P
        Next
        Console.WriteLine(h)
        Console.WriteLine($"sort-search({n})")
    End Sub
End Module
