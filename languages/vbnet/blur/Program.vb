' blur: 3x3 Gaussian blur [1 2 1; 2 4 2; 1 2 1]/16 over an LCG-generated N x N grayscale image,
' PASSES double-buffered passes, clamp (edge-replication) borders, poly-hash of the result.
' All integer arithmetic.
Imports System

Module Blur
    Const P As Long = 1000000007L
    Const PASSES As Integer = 4

    Function Clampi(x As Integer, n As Integer) As Integer
        Return If(x < 0, 0, If(x >= n, n - 1, x))
    End Function

    Function Run(sz As Integer) As Long
        Dim kern As Integer() = New Integer() {1, 2, 1, 2, 4, 2, 1, 2, 1} ' 3x3, sum 16
        Dim src As Integer() = New Integer(sz * sz - 1) {}
        Dim dst As Integer() = New Integer(sz * sz - 1) {}

        Dim s As Long = 42
        For k As Long = 0 To CLng(sz) * sz - 1
            s = (s * 1103515245L + 12345L) And &H7FFFFFFFL
            src(CInt(k)) = CInt(s Mod 256)
        Next

        For pass As Integer = 0 To PASSES - 1
            For i As Integer = 0 To sz - 1
                For j As Integer = 0 To sz - 1
                    Dim acc As Integer = 0
                    For di As Integer = -1 To 1
                        Dim ni As Integer = Clampi(i + di, sz)
                        For dj As Integer = -1 To 1
                            Dim nj As Integer = Clampi(j + dj, sz)
                            acc += kern((di + 1) * 3 + (dj + 1)) * src(ni * sz + nj)
                        Next
                    Next
                    dst(i * sz + j) = acc \ 16 ' integer division
                Next
            Next
            Dim t As Integer() = src
            src = dst
            dst = t ' double-buffer swap
        Next

        Dim h As Long = 0
        For k As Long = 0 To CLng(sz) * sz - 1
            h = (h * 31 + src(CInt(k))) Mod P
        Next
        Return h
    End Function

    Sub Main(args As String())
        Dim n As Integer = If(args.Length > 0, Integer.Parse(args(0)), 256)
        Console.WriteLine(Run(n))
        Console.WriteLine($"blur({n})")
    End Sub
End Module
