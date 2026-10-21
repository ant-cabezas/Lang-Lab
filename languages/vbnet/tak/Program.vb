' tak: the Takeuchi function, the function-call / recursion-overhead axis. Naive triple
' recursion, no memoization, no arrays, no allocation. Checksum = total number of calls;
' secondary = the returned value.
Imports System

Module Tak
    Private calls As Long = 0 ' total entries to Tk

    Function Tk(x As Integer, y As Integer, z As Integer) As Integer
        calls += 1
        If y < x Then Return Tk(Tk(x - 1, y, z), Tk(y - 1, z, x), Tk(z - 1, x, y))
        Return z
    End Function

    Sub Main(args As String())
        Dim n As Integer = If(args.Length > 0, Integer.Parse(args(0)), 6)
        Dim r As Integer = Tk(3 * n, 2 * n, n)
        Console.WriteLine(calls)
        Console.WriteLine($"tak({n}) = {r}")
    End Sub
End Module
