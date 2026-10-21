' dijkstra: single-source shortest paths on a deterministically generated weighted digraph,
' with a HAND-WRITTEN binary min-heap of PACKED keys (dist * 2^21 + node). All integer.
Imports System

Module Dijkstra
    Const P As Long = 1000000007L
    Const INF As Long = 1L << 62
    Const DEG As Integer = 8 ' average out-degree -> M = DEG*N directed edges
    Const MAXW As Integer = 100 ' edge weights 1..MAXW
    Const BASE As Long = 2097152L ' 2^21, larger than N; node packs into the low bits

    ' hand-written binary min-heap of packed long keys (all keys distinct)
    Private heap As Long()
    Private hsize As Integer

    Sub HPush(k As Long)
        Dim i As Integer = hsize
        hsize += 1
        heap(i) = k
        While i > 0
            Dim p As Integer = (i - 1) \ 2
            If heap(p) <= heap(i) Then Exit While
            Dim t As Long = heap(p)
            heap(p) = heap(i)
            heap(i) = t
            i = p
        End While
    End Sub

    Function HPop() As Long
        Dim top As Long = heap(0)
        hsize -= 1
        heap(0) = heap(hsize)
        Dim i As Integer = 0
        Do
            Dim l As Integer = 2 * i + 1
            Dim r As Integer = 2 * i + 2
            Dim m As Integer = i
            If l < hsize AndAlso heap(l) < heap(m) Then m = l
            If r < hsize AndAlso heap(r) < heap(m) Then m = r
            If m = i Then Exit Do
            Dim t As Long = heap(m)
            heap(m) = heap(i)
            heap(i) = t
            i = m
        Loop
        Return top
    End Function

    Function Run(n As Integer) As Long
        Dim m As Long = CLng(DEG) * n
        Dim eu As Integer() = New Integer(CInt(m) - 1) {}
        Dim ev As Integer() = New Integer(CInt(m) - 1) {}
        Dim ew As Integer() = New Integer(CInt(m) - 1) {}
        Dim s As Long = 42
        For e As Long = 0 To m - 1
            s = (s * 1103515245L + 12345L) And &H7FFFFFFFL
            eu(CInt(e)) = CInt(s Mod n)
            s = (s * 1103515245L + 12345L) And &H7FFFFFFFL
            ev(CInt(e)) = CInt(s Mod n)
            s = (s * 1103515245L + 12345L) And &H7FFFFFFFL
            ew(CInt(e)) = CInt(s Mod MAXW + 1)
        Next
        ' CSR adjacency in forward (edge-generation) order
        Dim start As Long() = New Long(n) {}
        For e As Long = 0 To m - 1
            start(eu(CInt(e)) + 1) += 1
        Next
        For i As Integer = 0 To n - 1
            start(i + 1) += start(i)
        Next
        Dim cnt As Long() = New Long(n - 1) {}
        Dim adjV As Integer() = New Integer(CInt(m) - 1) {}
        Dim adjW As Integer() = New Integer(CInt(m) - 1) {}
        For e As Long = 0 To m - 1
            Dim pos As Long = start(eu(CInt(e))) + cnt(eu(CInt(e)))
            cnt(eu(CInt(e))) += 1
            adjV(CInt(pos)) = ev(CInt(e))
            adjW(CInt(pos)) = ew(CInt(e))
        Next
        Dim dist As Long() = New Long(n - 1) {}
        For i As Integer = 0 To n - 1
            dist(i) = INF
        Next
        dist(0) = 0
        heap = New Long(CInt(m)) {}
        hsize = 0
        HPush(0L)
        While hsize > 0
            Dim key As Long = HPop()
            Dim d As Long = key \ BASE
            Dim u As Long = key Mod BASE
            If d > dist(CInt(u)) Then Continue While ' stale heap entry
            For e As Long = start(CInt(u)) To start(CInt(u) + 1) - 1
                Dim v As Long = adjV(CInt(e))
                Dim nd As Long = d + adjW(CInt(e))
                If nd < dist(CInt(v)) Then
                    dist(CInt(v)) = nd
                    HPush(nd * BASE + v)
                End If
            Next
        End While
        Dim h As Long = 0
        For i As Integer = 0 To n - 1
            Dim di As Long = If(dist(i) < INF, dist(i), 0L) ' unreachable -> 0
            h = (h * 31 + di Mod P) Mod P
        Next
        Return h
    End Function

    Sub Main(args As String())
        Dim n As Integer = If(args.Length > 0, Integer.Parse(args(0)), 10000)
        Console.WriteLine(Run(n))
        Console.WriteLine($"dijkstra({n})")
    End Sub
End Module
