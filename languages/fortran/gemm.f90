! gemm: quantized matrix multiply, flat int64 A/B/C, loop order i, k, j pinned. No matmul.
module gemm_mod
  use iso_fortran_env, only: int32, int64
  implicit none
  integer(int64), parameter :: P = 1000000007_int64
contains
  function lcg(s) result(r)
    integer(int64), value :: s
    integer(int64) :: r
    r = iand(s * 1103515245_int64 + 12345_int64, 2147483647_int64)
  end function lcg

  subroutine multiply(a, b, c, n)
    integer(int64), intent(in) :: a(0:*), b(0:*)
    integer(int64), intent(inout) :: c(0:*)
    integer(int32), value :: n
    integer(int32) :: i, k, j
    integer(int64) :: av
    do i = 0, n - 1
      do k = 0, n - 1
        av = a(i * n + k)
        do j = 0, n - 1
          c(i * n + j) = c(i * n + j) + av * b(k * n + j)
        end do
      end do
    end do
  end subroutine multiply

  subroutine run(n, h, secondary)
    integer(int32), value :: n
    integer(int64), intent(out) :: h, secondary
    integer(int64), allocatable :: a(:), b(:), c(:)
    integer(int64) :: s
    integer(int32) :: i

    allocate(a(0:n*n-1), b(0:n*n-1), c(0:n*n-1))
    c = 0
    s = 42
    do i = 0, n * n - 1
      s = lcg(s)
      a(i) = mod(s, 128_int64)
    end do
    do i = 0, n * n - 1
      s = lcg(s)
      b(i) = mod(s, 128_int64)
    end do
    call multiply(a, b, c, n)
    h = 0
    do i = 0, n * n - 1
      h = mod(h * 31 + mod(c(i), P), P)
    end do
    secondary = mod(c(n * n - 1), P)
    deallocate(a, b, c)
  end subroutine run
end module gemm_mod

program gemm
  use iso_fortran_env, only: int32, int64
  use gemm_mod
  implicit none
  character(len=32) :: buf
  integer(int32) :: n
  integer(int64) :: h, secondary

  n = 256
  if (command_argument_count() >= 1) then
    call get_command_argument(1, buf)
    read (buf, *) n
  end if
  call run(n, h, secondary)
  write (*, '(I0)') h
  write (*, '(A,I0,A,I0)') 'gemm(', n, ') = ', secondary
end program gemm
