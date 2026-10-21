' sha256: iterated SHA-256 (real FIPS 180-4, hand-written, no crypto library). Start from a 32-byte
' LCG-generated digest and apply SHA-256 to it N times; checksum = poly-hash of the final digest.
' VB arithmetic is overflow-checked and UInteger arithmetic is checked too, so every 32-bit
' unsigned quantity lives in a Long in [0, 2^32) and is reduced with And MASK.
Imports System

Module Sha256
    Const P As Long = 1000000007L
    Const MASK As Long = &HFFFFFFFFL

    ReadOnly KT As Long() = New Long() {
        &H428A2F98L, &H71374491L, &HB5C0FBCFL, &HE9B5DBA5L, &H3956C25BL, &H59F111F1L, &H923F82A4L, &HAB1C5ED5L,
        &HD807AA98L, &H12835B01L, &H243185BEL, &H550C7DC3L, &H72BE5D74L, &H80DEB1FEL, &H9BDC06A7L, &HC19BF174L,
        &HE49B69C1L, &HEFBE4786L, &HFC19DC6L, &H240CA1CCL, &H2DE92C6FL, &H4A7484AAL, &H5CB0A9DCL, &H76F988DAL,
        &H983E5152L, &HA831C66DL, &HB00327C8L, &HBF597FC7L, &HC6E00BF3L, &HD5A79147L, &H6CA6351L, &H14292967L,
        &H27B70A85L, &H2E1B2138L, &H4D2C6DFCL, &H53380D13L, &H650A7354L, &H766A0ABBL, &H81C2C92EL, &H92722C85L,
        &HA2BFE8A1L, &HA81A664BL, &HC24B8B70L, &HC76C51A3L, &HD192E819L, &HD6990624L, &HF40E3585L, &H106AA070L,
        &H19A4C116L, &H1E376C08L, &H2748774CL, &H34B0BCB5L, &H391C0CB3L, &H4ED8AA4AL, &H5B9CCA4FL, &H682E6FF3L,
        &H748F82EEL, &H78A5636FL, &H84C87814L, &H8CC70208L, &H90BEFFFAL, &HA4506CEBL, &HBEF9A3F7L, &HC67178F2L}

    ReadOnly H0 As Long() = New Long() {
        &H6A09E667L, &HBB67AE85L, &H3C6EF372L, &HA54FF53AL, &H510E527FL, &H9B05688CL, &H1F83D9ABL, &H5BE0CD19L}

    Function Rotr(x As Long, n As Integer) As Long
        Return ((x >> n) Or (x << (32 - n))) And MASK
    End Function

    Sub Sha256Block(b As Byte(), h As Long())
        Dim w As Long() = New Long(63) {}
        For i As Integer = 0 To 15
            w(i) = (CLng(b(i * 4)) << 24) Or (CLng(b(i * 4 + 1)) << 16) Or (CLng(b(i * 4 + 2)) << 8) Or CLng(b(i * 4 + 3))
        Next
        For i As Integer = 16 To 63
            Dim sg0 As Long = Rotr(w(i - 15), 7) Xor Rotr(w(i - 15), 18) Xor (w(i - 15) >> 3)
            Dim sg1 As Long = Rotr(w(i - 2), 17) Xor Rotr(w(i - 2), 19) Xor (w(i - 2) >> 10)
            w(i) = (w(i - 16) + sg0 + w(i - 7) + sg1) And MASK
        Next
        Dim a As Long = h(0)
        Dim bb As Long = h(1)
        Dim c As Long = h(2)
        Dim d As Long = h(3)
        Dim e As Long = h(4)
        Dim f As Long = h(5)
        Dim g As Long = h(6)
        Dim hh As Long = h(7)
        For i As Integer = 0 To 63
            Dim bs1 As Long = Rotr(e, 6) Xor Rotr(e, 11) Xor Rotr(e, 25)
            Dim ch As Long = (e And f) Xor ((Not e) And g)
            Dim t1 As Long = (hh + bs1 + ch + KT(i) + w(i)) And MASK
            Dim bs0 As Long = Rotr(a, 2) Xor Rotr(a, 13) Xor Rotr(a, 22)
            Dim maj As Long = (a And bb) Xor (a And c) Xor (bb And c)
            Dim t2 As Long = (bs0 + maj) And MASK
            hh = g
            g = f
            f = e
            e = (d + t1) And MASK
            d = c
            c = bb
            bb = a
            a = (t1 + t2) And MASK
        Next
        h(0) = (h(0) + a) And MASK
        h(1) = (h(1) + bb) And MASK
        h(2) = (h(2) + c) And MASK
        h(3) = (h(3) + d) And MASK
        h(4) = (h(4) + e) And MASK
        h(5) = (h(5) + f) And MASK
        h(6) = (h(6) + g) And MASK
        h(7) = (h(7) + hh) And MASK
    End Sub

    ' hash the 32-byte digest in place (one padded 64-byte block; message length = 256 bits)
    Sub Sha256_32(digest As Byte())
        Dim b As Byte() = New Byte(63) {}
        For i As Integer = 0 To 31
            b(i) = digest(i)
        Next
        b(32) = &H80
        For i As Integer = 33 To 63
            b(i) = 0
        Next
        b(62) = 1 ' length 256 = 0x0100
        Dim h As Long() = New Long(7) {}
        For i As Integer = 0 To 7
            h(i) = H0(i)
        Next
        Sha256Block(b, h)
        For i As Integer = 0 To 7
            digest(i * 4) = CByte((h(i) >> 24) And &HFFL)
            digest(i * 4 + 1) = CByte((h(i) >> 16) And &HFFL)
            digest(i * 4 + 2) = CByte((h(i) >> 8) And &HFFL)
            digest(i * 4 + 3) = CByte(h(i) And &HFFL)
        Next
    End Sub

    Sub Main(args As String())
        Dim n As Integer = If(args.Length > 0, Integer.Parse(args(0)), 10000)
        Dim d As Byte() = New Byte(31) {}
        Dim s As Long = 42
        For i As Integer = 0 To 31
            s = (s * 1103515245L + 12345L) And &H7FFFFFFFL
            d(i) = CByte(s Mod 256)
        Next
        For i As Integer = 0 To n - 1
            Sha256_32(d)
        Next
        Dim h As Long = 0
        For i As Integer = 0 To 31
            h = (h * 31 + d(i)) Mod P
        Next
        Console.WriteLine(h)
        Console.WriteLine($"sha256({n})")
    End Sub
End Module
