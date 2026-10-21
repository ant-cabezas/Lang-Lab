Imports System

NotInheritable Class Node
    Public Left As Node
    Public Right As Node

    Public Sub New(l As Node, r As Node)
        Left = l
        Right = r
    End Sub
End Class

Module BinaryTrees
    Function Make(depth As Integer) As Node
        If depth = 0 Then Return New Node(Nothing, Nothing)
        Return New Node(Make(depth - 1), Make(depth - 1))
    End Function

    Function Check(nd As Node) As Long
        If nd.Left Is Nothing Then Return 1
        Return 1 + Check(nd.Left) + Check(nd.Right)
    End Function

    Function Run(n As Integer) As Long
        Dim minDepth As Integer = 4
        Dim maxDepth As Integer = Math.Max(minDepth + 2, n)
        Dim stretchDepth As Integer = maxDepth + 1

        Dim total As Long = Check(Make(stretchDepth))
        Dim longLived As Node = Make(maxDepth)

        Dim depth As Integer = minDepth
        While depth <= maxDepth
            Dim iterations As Integer = 1 << (maxDepth - depth + minDepth)
            Dim s As Long = 0
            For i As Integer = 0 To iterations - 1
                s += Check(Make(depth))
            Next
            total += s
            depth += 2
        End While

        total += Check(longLived)
        Return total
    End Function

    Sub Main(args As String())
        Dim n As Integer = If(args.Length > 0, Integer.Parse(args(0)), 10)
        Console.WriteLine(Run(n))
        Console.WriteLine($"binary-trees({n})")
    End Sub
End Module
