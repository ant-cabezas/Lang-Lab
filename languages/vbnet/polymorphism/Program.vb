' polymorphism: the dynamic-dispatch / virtual-call-overhead axis. N objects of K=6 distinct
' concrete types in LCG order (megamorphic call site), an accumulator threaded through every
' objs(i).Run(acc) over M passes. MustInherit base class + MustOverride, resolved by the CLR's
' virtual dispatch (no type tag, no Interface, no delegates, no late binding).
Imports System

MustInherit Class Apply
    Public a As Long
    Public b As Long
    Public c As Long
    Public MustOverride Function Run(x As Long) As Long
End Class

Class T0 : Inherits Apply
    Public Overrides Function Run(x As Long) As Long
        Return (x * 1000003L + a) Mod Polymorphism.P
    End Function
End Class

Class T1 : Inherits Apply
    Public Overrides Function Run(x As Long) As Long
        Return (x * 998273L + b) Mod Polymorphism.P
    End Function
End Class

Class T2 : Inherits Apply
    Public Overrides Function Run(x As Long) As Long
        Return (x * 999983L + c) Mod Polymorphism.P
    End Function
End Class

Class T3 : Inherits Apply
    Public Overrides Function Run(x As Long) As Long
        Return (x * 997879L + a + b) Mod Polymorphism.P
    End Function
End Class

Class T4 : Inherits Apply
    Public Overrides Function Run(x As Long) As Long
        Return (x * 996323L + b * c) Mod Polymorphism.P
    End Function
End Class

Class T5 : Inherits Apply
    Public Overrides Function Run(x As Long) As Long
        Return (x * 995369L + a + c) Mod Polymorphism.P
    End Function
End Class

Module Polymorphism
    Public Const P As Long = 1000000007L
    Const N As Integer = 10000
    Const K As Integer = 6

    Function Lcg(s As Long) As Long
        Return (s * 1103515245L + 12345L) And &H7FFFFFFFL
    End Function

    Function Make(t As Long, a As Long, b As Long, c As Long) As Apply
        Dim o As Apply
        Select Case t ' construction-time factory, NOT the dispatch path (the fold below is virtual)
            Case 0L
                o = New T0()
            Case 1L
                o = New T1()
            Case 2L
                o = New T2()
            Case 3L
                o = New T3()
            Case 4L
                o = New T4()
            Case Else
                o = New T5()
        End Select
        o.a = a
        o.b = b
        o.c = c
        Return o
    End Function

    Sub Main(args As String())
        Dim m As Integer = If(args.Length > 0, Integer.Parse(args(0)), 50)
        Dim objs As Apply() = New Apply(N - 1) {}
        Dim s As Long = 42
        For i As Integer = 0 To N - 1
            s = Lcg(s)
            Dim t As Long = (s >> 16) Mod K ' type from HIGH bits (LCG low bits correlate)
            s = Lcg(s)
            Dim a As Long = s Mod 1000
            s = Lcg(s)
            Dim b As Long = s Mod 1000
            s = Lcg(s)
            Dim c As Long = s Mod 1000
            objs(i) = Make(t, a, b, c)
        Next
        Dim acc As Long = 1
        For pass As Integer = 0 To m - 1
            For i As Integer = 0 To N - 1
                acc = objs(i).Run(acc) ' DYNAMIC dispatch (virtual call per object)
            Next
        Next
        Console.WriteLine(acc)
        Console.WriteLine($"polymorphism({m})")
    End Sub
End Module
