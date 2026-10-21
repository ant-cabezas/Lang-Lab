' gemm: quantized integer matrix multiply. Square N x N, loop order i,k,j (pinned) so B is read
' row-sequentially. LCG fills A then B with 0..127. 64-bit accumulator; checksum = poly-hash of C.
' No BLAS / library matmul.
Imports System

Module Gemm
    Const P As Long = 1000000007L

    Function Lcg(s As Long) As Long
        Return (s * 1103515245L + 12345L) And &H7FFFFFFFL
    End Function

    Function Run(n As Integer) As (Long, Long)
        Dim MA As Long() = New Long(n * n - 1) {}
        Dim MB As Long() = New Long(n * n - 1) {}
        Dim MC As Long() = New Long(n * n - 1) {}

        Dim s As Long = 42
        For i As Long = 0 To CLng(n) * n - 1
            s = Lcg(s)
            MA(CInt(i)) = s Mod 128
        Next
        For i As Long = 0 To CLng(n) * n - 1
            s = Lcg(s)
            MB(CInt(i)) = s Mod 128
        Next

        ' Pinned loop order i, k, j - B read row-sequentially.
        For i As Integer = 0 To n - 1
            For k As Integer = 0 To n - 1
                Dim av As Long = MA(i * n + k)
                Dim kn As Integer = k * n
                Dim bse As Integer = i * n
                For j As Integer = 0 To n - 1
                    MC(bse + j) += av * MB(kn + j)
                Next
            Next
        Next

        Dim h As Long = 0
        For i As Long = 0 To CLng(n) * n - 1
            h = (h * 31 + MC(CInt(i)) Mod P) Mod P
        Next
        Dim secondary As Long = MC(n * n - 1) Mod P
        Return (h, secondary)
    End Function

    Sub Main(args As String())
        Dim n As Integer = If(args.Length > 0, Integer.Parse(args(0)), 256)
        Dim r = Run(n)
        Console.WriteLine(r.Item1)
        Console.WriteLine($"gemm({n}) = {r.Item2}")
    End Sub
End Module
