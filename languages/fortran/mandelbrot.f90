! mandelbrot: real(real64) throughout; zi = t + t + ci with t = zr*zi (FMA-proof, same as C).
module mandel_mod
  use iso_fortran_env, only: int32, int64, real64
  implicit none
contains
  function mandel(n) result(count)
    integer(int32), value :: n
    integer(int64) :: count
    integer(int32) :: x, y, i
    real(real64) :: ci, cr, zr, zi, tr, ti, t

    count = 0
    do y = 0, n - 1
      ci = 2.0_real64 * real(y, real64) / real(n, real64) - 1.0_real64
      do x = 0, n - 1
        cr = 2.0_real64 * real(x, real64) / real(n, real64) - 1.5_real64
        zr = 0.0_real64
        zi = 0.0_real64
        tr = 0.0_real64
        ti = 0.0_real64
        i = 0
        do while (i < 50 .and. tr + ti <= 4.0_real64)
          t = zr * zi
          zi = t + t + ci
          zr = tr - ti + cr
          tr = zr * zr
          ti = zi * zi
          i = i + 1
        end do
        if (tr + ti <= 4.0_real64) count = count + 1
      end do
    end do
  end function mandel
end module mandel_mod

program mandelbrot
  use iso_fortran_env, only: int32
  use mandel_mod
  implicit none
  character(len=32) :: buf
  integer(int32) :: n

  n = 128
  if (command_argument_count() >= 1) then
    call get_command_argument(1, buf)
    read (buf, *) n
  end if
  write (*, '(I0)') mandel(n)
  write (*, '(A,I0,A)') 'mandelbrot(', n, ')'
end program mandelbrot
