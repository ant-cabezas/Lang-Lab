! lz77: brute-force longest-match scan over WINDOW=512, nearest distance wins ties.
! The match loop uses nested if/exit in C's operand order (no reliance on short-circuit .and.).
module lz_mod
  use iso_fortran_env, only: int8, int32, int64
  implicit none
  integer(int64), parameter :: P = 1000000007_int64
  integer(int32), parameter :: WINDOW = 512, MIN_MATCH = 3, MAX_MATCH = 255, ALPHA = 6
contains
  function run(n) result(h)
    integer(int32), value :: n
    integer(int64) :: h, s
    integer(int8), allocatable :: inp(:)
    integer(int32) :: i, pos, best_len, best_dist, start, cand, l

    allocate(inp(0:n-1))
    s = 42
    do i = 0, n - 1
      s = iand(s * 1103515245_int64 + 12345_int64, 2147483647_int64)
      inp(i) = int(mod(s, int(ALPHA, int64)), int8)
    end do
    pos = 0
    h = 0
    do while (pos < n)
      best_len = 0
      best_dist = 0
      start = pos - WINDOW
      if (start < 0) start = 0
      do cand = pos - 1, start, -1
        l = 0
        do
          if (pos + l >= n) exit
          if (l >= MAX_MATCH) exit
          if (inp(cand + l) /= inp(pos + l)) exit
          l = l + 1
        end do
        if (l > best_len) then
          best_len = l
          best_dist = pos - cand
        end if
      end do
      if (best_len >= MIN_MATCH) then
        h = mod(h * 31 + 1, P)
        h = mod(h * 31 + best_dist, P)
        h = mod(h * 31 + best_len, P)
        pos = pos + best_len
      else
        h = mod(h * 31 + 0, P)
        h = mod(h * 31 + inp(pos), P)
        pos = pos + 1
      end if
    end do
    deallocate(inp)
  end function run
end module lz_mod

program lz77
  use iso_fortran_env, only: int32
  use lz_mod
  implicit none
  character(len=32) :: buf
  integer(int32) :: n

  n = 24000
  if (command_argument_count() >= 1) then
    call get_command_argument(1, buf)
    read (buf, *) n
  end if
  write (*, '(I0)') run(n)
  write (*, '(A,I0,A)') 'lz77(', n, ')'
end program lz77
