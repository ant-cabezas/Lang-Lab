! reverse-complement: hand-written two-pointer loop over a character(len=1) array.
module rc_mod
  use iso_fortran_env, only: int32, int64
  implicit none
  integer(int64), parameter :: P = 1000000007_int64
  integer(int64), parameter :: IM = 139968_int64, IA = 3877_int64, IC = 29573_int64
contains
  function comp(c) result(r)
    integer(int32), value :: c
    integer(int32) :: r
    if (c == 65) then
      r = 84
    else if (c == 67) then
      r = 71
    else if (c == 71) then
      r = 67
    else
      r = 65
    end if
  end function comp

  function run(L) result(h)
    integer(int32), value :: L
    integer(int64) :: h, seed
    character(len=1), allocatable :: s(:)
    character(len=1) :: a
    integer(int32) :: i, j, k

    allocate(s(0:L-1))
    seed = 42
    do i = 0, L - 1
      seed = mod(seed * IA + IC, IM)
      if (seed < 42000) then
        s(i) = 'A'
      else if (seed < 70000) then
        s(i) = 'C'
      else if (seed < 98000) then
        s(i) = 'G'
      else
        s(i) = 'T'
      end if
    end do
    i = 0
    j = L - 1
    do while (i < j)
      a = achar(comp(ichar(s(i))))
      s(i) = achar(comp(ichar(s(j))))
      s(j) = a
      i = i + 1
      j = j - 1
    end do
    if (i == j) s(i) = achar(comp(ichar(s(i))))
    h = 0
    do k = 0, L - 1
      h = mod(h * 31 + ichar(s(k)), P)
    end do
    deallocate(s)
  end function run
end module rc_mod

program reverse_complement
  use iso_fortran_env, only: int32
  use rc_mod
  implicit none
  character(len=32) :: buf
  integer(int32) :: n

  n = 100000
  if (command_argument_count() >= 1) then
    call get_command_argument(1, buf)
    read (buf, *) n
  end if
  write (*, '(I0)') run(n)
  write (*, '(A,I0,A)') 'reverse-complement(', n, ')'
end program reverse_complement
