! blur: 3x3 Gaussian stencil, flat 0-based int32 buffers, clamp borders, double buffer
! (the roles of src and dst alternate between two arrays, like C's pointer swap).
module blur_mod
  use iso_fortran_env, only: int32, int64
  implicit none
  integer(int64), parameter :: P = 1000000007_int64
  integer(int32), parameter :: PASSES = 4
  integer(int32), parameter :: KER(0:8) = [1, 2, 1, 2, 4, 2, 1, 2, 1]
contains
  function lcg(s) result(r)
    integer(int64), value :: s
    integer(int64) :: r
    r = iand(s * 1103515245_int64 + 12345_int64, 2147483647_int64)
  end function lcg

  function clampi(x, n) result(r)
    integer(int32), value :: x, n
    integer(int32) :: r
    if (x < 0) then
      r = 0
    else if (x >= n) then
      r = n - 1
    else
      r = x
    end if
  end function clampi

  subroutine blurpass(src, dst, n)
    integer(int32), intent(in) :: src(0:*)
    integer(int32), intent(out) :: dst(0:*)
    integer(int32), value :: n
    integer(int32) :: i, j, di, dj, ni, nj, acc
    do i = 0, n - 1
      do j = 0, n - 1
        acc = 0
        do di = -1, 1
          ni = clampi(i + di, n)
          do dj = -1, 1
            nj = clampi(j + dj, n)
            acc = acc + KER((di + 1) * 3 + (dj + 1)) * src(int(ni, int64) * n + nj)
          end do
        end do
        dst(int(i, int64) * n + j) = acc / 16
      end do
    end do
  end subroutine blurpass

  function run(n) result(h)
    integer(int32), value :: n
    integer(int64) :: h, s, k, nn
    integer(int32), allocatable :: a(:), b(:)
    integer(int32) :: pass

    nn = int(n, int64) * n
    allocate(a(0:nn-1), b(0:nn-1))
    s = 42
    do k = 0, nn - 1
      s = lcg(s)
      a(k) = int(mod(s, 256_int64), int32)
    end do
    do pass = 0, PASSES - 1
      if (mod(pass, 2) == 0) then
        call blurpass(a, b, n)
      else
        call blurpass(b, a, n)
      end if
    end do
    h = 0
    do k = 0, nn - 1
      h = mod(h * 31 + a(k), P)
    end do
    deallocate(a, b)
  end function run
end module blur_mod

program blur
  use iso_fortran_env, only: int32
  use blur_mod
  implicit none
  character(len=32) :: buf
  integer(int32) :: n

  n = 256
  if (command_argument_count() >= 1) then
    call get_command_argument(1, buf)
    read (buf, *) n
  end if
  write (*, '(I0)') run(n)
  write (*, '(A,I0,A)') 'blur(', n, ')'
end program blur
