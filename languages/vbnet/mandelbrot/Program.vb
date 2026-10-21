' Mandelbrot set over an N x N grid of the complex plane [-1.5, 0.5] x [-1.0, 1.0].
' A pixel is "in the set" if |z| stays <= 2 (zr^2+zi^2 <= 4) through 50 iterations of
' z := z^2 + c starting from z = 0. The checksum is the count of in-set pixels.
' IEEE-754 Double throughout; 2*zr*zi is written t+t (t = zr*zi) so there is no multiply-add
' pattern to FMA-contract, exactly as in the C# program.
Imports System

Module Mandelbrot
    Function Run(n As Integer) As Long
        Dim count As Long = 0
        For y As Integer = 0 To n - 1
            Dim ci As Double = 2.0 * y / n - 1.0
            For x As Integer = 0 To n - 1
                Dim cr As Double = 2.0 * x / n - 1.5
                Dim zr As Double = 0.0
                Dim zi As Double = 0.0
                Dim tr As Double = 0.0
                Dim ti As Double = 0.0
                Dim i As Integer = 0
                While i < 50 AndAlso tr + ti <= 4.0
                    Dim t As Double = zr * zi
                    zi = t + t + ci ' == 2*zr*zi + ci, FMA-proof
                    zr = tr - ti + cr
                    tr = zr * zr
                    ti = zi * zi
                    i += 1
                End While
                If tr + ti <= 4.0 Then count += 1 ' never escaped -> in set
            Next
        Next
        Return count
    End Function

    Sub Main(args As String())
        Dim n As Integer = If(args.Length > 0, Integer.Parse(args(0)), 128)
        Console.WriteLine(Run(n))
        Console.WriteLine($"mandelbrot({n})")
    End Sub
End Module
