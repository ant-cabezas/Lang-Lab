Imports System

Module Fannkuch
    Function Run(n As Integer) As (Integer, Integer)
        Dim perm1 As Integer() = New Integer(n - 1) {}
        For x As Integer = 0 To n - 1
            perm1(x) = x
        Next
        Dim perm As Integer() = New Integer(n - 1) {}
        Dim count As Integer() = New Integer(n - 1) {}
        Dim maxFlips As Integer = 0
        Dim checksum As Integer = 0
        Dim r As Integer = n
        Dim permIdx As Long = 0 ' counts up to n!-1 -> needs 64-bit for n >= 13

        Do
            While r <> 1
                count(r - 1) = r
                r -= 1
            End While

            Array.Copy(perm1, perm, n)
            Dim flips As Integer = 0
            Dim k As Integer = perm(0)
            While k <> 0
                Dim i As Integer = 0
                Dim j As Integer = k
                While i < j
                    Dim t As Integer = perm(i)
                    perm(i) = perm(j)
                    perm(j) = t
                    i += 1
                    j -= 1
                End While
                flips += 1
                k = perm(0)
            End While

            If flips > maxFlips Then maxFlips = flips
            checksum += If(permIdx Mod 2 = 0, flips, -flips)

            ' Generate the next permutation.
            Do
                If r = n Then Return (maxFlips, checksum)
                Dim first As Integer = perm1(0)
                For i As Integer = 0 To r - 1
                    perm1(i) = perm1(i + 1)
                Next
                perm1(r) = first
                count(r) -= 1
                If count(r) > 0 Then Exit Do
                r += 1
            Loop
            permIdx += 1
        Loop
    End Function

    Sub Main(args As String())
        Dim n As Integer = If(args.Length > 0, Integer.Parse(args(0)), 7)
        Dim res = Run(n)
        Console.WriteLine(res.Item2)
        Console.WriteLine($"Pfannkuchen({n}) = {res.Item1}")
    End Sub
End Module
