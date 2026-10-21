! sha256: real FIPS 180-4 SHA-256 iterated N times over a 32-byte digest. No unsigned type in
! Fortran: words are int64 holding [0, 2^32), reduced with iand(x, M32) once per statement;
! ishft(x, -n) is a logical shift. rotr is the explicit two-shift form (no ishftc).
module sha_mod
  use iso_fortran_env, only: int32, int64
  implicit none
  integer(int64), parameter :: P = 1000000007_int64
  integer(int64), parameter :: M32 = 4294967295_int64
  integer(int64), parameter :: K(0:63) = [integer(int64) :: &
      1116352408_int64, 1899447441_int64, 3049323471_int64, 3921009573_int64, &
      961987163_int64, 1508970993_int64, 2453635748_int64, 2870763221_int64, &
      3624381080_int64, 310598401_int64, 607225278_int64, 1426881987_int64, &
      1925078388_int64, 2162078206_int64, 2614888103_int64, 3248222580_int64, &
      3835390401_int64, 4022224774_int64, 264347078_int64, 604807628_int64, &
      770255983_int64, 1249150122_int64, 1555081692_int64, 1996064986_int64, &
      2554220882_int64, 2821834349_int64, 2952996808_int64, 3210313671_int64, &
      3336571891_int64, 3584528711_int64, 113926993_int64, 338241895_int64, &
      666307205_int64, 773529912_int64, 1294757372_int64, 1396182291_int64, &
      1695183700_int64, 1986661051_int64, 2177026350_int64, 2456956037_int64, &
      2730485921_int64, 2820302411_int64, 3259730800_int64, 3345764771_int64, &
      3516065817_int64, 3600352804_int64, 4094571909_int64, 275423344_int64, &
      430227734_int64, 506948616_int64, 659060556_int64, 883997877_int64, &
      958139571_int64, 1322822218_int64, 1537002063_int64, 1747873779_int64, &
      1955562222_int64, 2024104815_int64, 2227730452_int64, 2361852424_int64, &
      2428436474_int64, 2756734187_int64, 3204031479_int64, 3329325298_int64 ]
  integer(int64), parameter :: H0(0:7) = [integer(int64) :: &
      1779033703_int64, 3144134277_int64, 1013904242_int64, 2773480762_int64, &
      1359893119_int64, 2600822924_int64, 528734635_int64, 1541459225_int64 ]
contains
  function rotr(x, n) result(r)
    integer(int64), value :: x
    integer(int32), value :: n
    integer(int64) :: r
    r = iand(ior(ishft(x, -n), ishft(x, 32 - n)), M32)
  end function rotr

  subroutine sha256_block(b, h)
    integer(int32), intent(in) :: b(0:63)
    integer(int64), intent(inout) :: h(0:7)
    integer(int64) :: w(0:63)
    integer(int64) :: a, bb, c, d, e, f, g, hh, s0, s1, ch, t1, t2, maj, bs0, bs1
    integer(int32) :: i

    do i = 0, 15
      w(i) = ior(ior(ishft(int(b(i*4), int64), 24), ishft(int(b(i*4+1), int64), 16)), &
                 ior(ishft(int(b(i*4+2), int64), 8), int(b(i*4+3), int64)))
    end do
    do i = 16, 63
      s0 = ieor(ieor(rotr(w(i-15), 7), rotr(w(i-15), 18)), ishft(w(i-15), -3))
      s1 = ieor(ieor(rotr(w(i-2), 17), rotr(w(i-2), 19)), ishft(w(i-2), -10))
      w(i) = iand(w(i-16) + s0 + w(i-7) + s1, M32)
    end do
    a = h(0)
    bb = h(1)
    c = h(2)
    d = h(3)
    e = h(4)
    f = h(5)
    g = h(6)
    hh = h(7)
    do i = 0, 63
      bs1 = ieor(ieor(rotr(e, 6), rotr(e, 11)), rotr(e, 25))
      ch = ieor(iand(e, f), iand(not(e), g))
      t1 = hh + bs1 + ch + K(i) + w(i)
      bs0 = ieor(ieor(rotr(a, 2), rotr(a, 13)), rotr(a, 22))
      maj = ieor(ieor(iand(a, bb), iand(a, c)), iand(bb, c))
      t2 = bs0 + maj
      hh = g
      g = f
      f = e
      e = iand(d + t1, M32)
      d = c
      c = bb
      bb = a
      a = iand(t1 + t2, M32)
    end do
    h(0) = iand(h(0) + a, M32)
    h(1) = iand(h(1) + bb, M32)
    h(2) = iand(h(2) + c, M32)
    h(3) = iand(h(3) + d, M32)
    h(4) = iand(h(4) + e, M32)
    h(5) = iand(h(5) + f, M32)
    h(6) = iand(h(6) + g, M32)
    h(7) = iand(h(7) + hh, M32)
  end subroutine sha256_block

  subroutine sha256_32(digest)
    integer(int32), intent(inout) :: digest(0:31)
    integer(int32) :: b(0:63)
    integer(int64) :: h(0:7)
    integer(int32) :: i

    do i = 0, 31
      b(i) = digest(i)
    end do
    b(32) = 128
    do i = 33, 63
      b(i) = 0
    end do
    b(62) = 1
    do i = 0, 7
      h(i) = H0(i)
    end do
    call sha256_block(b, h)
    do i = 0, 7
      digest(i*4)   = int(iand(ishft(h(i), -24), 255_int64), int32)
      digest(i*4+1) = int(iand(ishft(h(i), -16), 255_int64), int32)
      digest(i*4+2) = int(iand(ishft(h(i), -8), 255_int64), int32)
      digest(i*4+3) = int(iand(h(i), 255_int64), int32)
    end do
  end subroutine sha256_32

  function run(n) result(h)
    integer(int32), value :: n
    integer(int64) :: h, s
    integer(int32) :: d(0:31)
    integer(int32) :: i

    s = 42
    do i = 0, 31
      s = iand(s * 1103515245_int64 + 12345_int64, 2147483647_int64)
      d(i) = int(mod(s, 256_int64), int32)
    end do
    do i = 0, n - 1
      call sha256_32(d)
    end do
    h = 0
    do i = 0, 31
      h = mod(h * 31 + d(i), P)
    end do
  end function run
end module sha_mod

program sha256
  use iso_fortran_env, only: int32
  use sha_mod
  implicit none
  character(len=32) :: buf
  integer(int32) :: n

  n = 10000
  if (command_argument_count() >= 1) then
    call get_command_argument(1, buf)
    read (buf, *) n
  end if
  write (*, '(I0)') run(n)
  write (*, '(A,I0,A)') 'sha256(', n, ')'
end program sha256
