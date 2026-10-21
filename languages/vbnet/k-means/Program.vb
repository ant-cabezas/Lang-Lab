' k-means: Lloyd's clustering over integer D-dimensional points, ITERS fixed iterations,
' integer squared distance, floor-mean centroid update. Lowest-index tie-break (strict <),
' empty cluster keeps its centroid. Checksum hashes final centroids and assignments.
Imports System

Module KMeans
    Const P As Long = 1000000007L
    Const NK As Integer = 16
    Const ND As Integer = 4
    Const ITERS As Integer = 10
    Const RANGE As Integer = 256

    Function Lcg(s As Long) As Long
        Return (s * 1103515245L + 12345L) And &H7FFFFFFFL
    End Function

    Function Run(n As Integer) As Long
        Dim pt As Long() = New Long(n * ND - 1) {}
        Dim s As Long = 42
        For i As Long = 0 To CLng(n) * ND - 1
            s = Lcg(s)
            pt(CInt(i)) = s Mod RANGE
        Next
        Dim cen As Long() = New Long(NK * ND - 1) {}
        For i As Integer = 0 To NK * ND - 1
            cen(i) = pt(i) ' initial centroids = first K points
        Next
        Dim assign As Integer() = New Integer(n - 1) {}

        For iter As Integer = 0 To ITERS - 1
            For i As Integer = 0 To n - 1 ' assignment
                Dim best As Integer = 0
                Dim bd As Long = -1
                For k As Integer = 0 To NK - 1
                    Dim dist As Long = 0
                    For d As Integer = 0 To ND - 1
                        Dim df As Long = pt(i * ND + d) - cen(k * ND + d)
                        dist += df * df
                    Next
                    If bd < 0 OrElse dist < bd Then ' STRICT < : ties to lowest k
                        bd = dist
                        best = k
                    End If
                Next
                assign(i) = best
            Next
            Dim ssum As Long() = New Long(NK * ND - 1) {} ' update: floor-mean, empty unchanged
            Dim cnt As Long() = New Long(NK - 1) {}
            For i As Integer = 0 To n - 1
                Dim k As Integer = assign(i)
                cnt(k) += 1
                For d As Integer = 0 To ND - 1
                    ssum(k * ND + d) += pt(i * ND + d)
                Next
            Next
            For k As Integer = 0 To NK - 1
                If cnt(k) > 0 Then
                    For d As Integer = 0 To ND - 1
                        cen(k * ND + d) = ssum(k * ND + d) \ cnt(k) ' integer (floor) division
                    Next
                End If
            Next
        Next

        For i As Integer = 0 To n - 1 ' final assignment with final centroids
            Dim best As Integer = 0
            Dim bd As Long = -1
            For k As Integer = 0 To NK - 1
                Dim dist As Long = 0
                For d As Integer = 0 To ND - 1
                    Dim df As Long = pt(i * ND + d) - cen(k * ND + d)
                    dist += df * df
                Next
                If bd < 0 OrElse dist < bd Then
                    bd = dist
                    best = k
                End If
            Next
            assign(i) = best
        Next

        Dim h As Long = 0
        For i As Integer = 0 To NK * ND - 1
            h = (h * 31 + cen(i)) Mod P
        Next
        For i As Integer = 0 To n - 1
            h = (h * 31 + assign(i)) Mod P
        Next
        Return h
    End Function

    Sub Main(args As String())
        Dim n As Integer = If(args.Length > 0, Integer.Parse(args(0)), 8000)
        Console.WriteLine(Run(n))
        Console.WriteLine($"k-means({n})")
    End Sub
End Module
