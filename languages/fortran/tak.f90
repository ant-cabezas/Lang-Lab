! tak: naive triple-recursive Takeuchi. value arguments, int64 call counter as a module variable
! (a static global like C's).
module tak_mod
  use iso_fortran_env, only: int32, int64
  implicit none
  integer(int64) :: calls = 0
contains
  recursive function tak(x, y, z) result(r)
    integer(int32), value :: x, y, z
    integer(int32) :: r
    calls = calls + 1
    if (y < x) then
      r = tak(tak(x - 1, y, z), tak(y - 1, z, x), tak(z - 1, x, y))
    else
      r = z
    end if
  end function tak
end module tak_mod

program tak_prog
  use iso_fortran_env, only: int32
  use tak_mod
  implicit none
  character(len=32) :: buf
  integer(int32) :: n, r

  n = 6
  if (command_argument_count() >= 1) then
    call get_command_argument(1, buf)
    read (buf, *) n
  end if
  r = tak(3 * n, 2 * n, n)
  write (*, '(I0)') calls
  write (*, '(A,I0,A,I0)') 'tak(', n, ') = ', r
end program tak_prog
