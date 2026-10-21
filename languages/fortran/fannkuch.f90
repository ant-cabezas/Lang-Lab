! fannkuch (n=7 -> checksum 228 / Pfannkuchen(7) = 16). Mirrors languages/c/fannkuch.c:
! flat 0-based int32 arrays, explicit flip and rotation loops.
module fannkuch_mod
  use iso_fortran_env, only: int32, int64
  implicit none
contains
  subroutine fannkuch(n, max_flips_out, checksum_out)
    integer(int32), value :: n
    integer(int32), intent(out) :: max_flips_out, checksum_out
    integer(int32), allocatable :: perm1(:), perm(:), count(:)
    integer(int32) :: max_flips, checksum, r, flips, k, i, j, t, first
    integer(int64) :: perm_idx

    allocate(perm1(0:n-1), perm(0:n-1), count(0:n-1))
    do i = 0, n - 1
      perm1(i) = i
    end do
    max_flips = 0
    checksum = 0
    r = n
    perm_idx = 0
    do
      do while (r /= 1)
        count(r - 1) = r
        r = r - 1
      end do

      perm(0:n-1) = perm1(0:n-1)
      flips = 0
      do
        k = perm(0)
        if (k == 0) exit
        i = 0
        j = k
        do while (i < j)
          t = perm(i)
          perm(i) = perm(j)
          perm(j) = t
          i = i + 1
          j = j - 1
        end do
        flips = flips + 1
      end do

      if (flips > max_flips) max_flips = flips
      if (mod(perm_idx, 2_int64) == 0) then
        checksum = checksum + flips
      else
        checksum = checksum - flips
      end if

      do
        if (r == n) then
          max_flips_out = max_flips
          checksum_out = checksum
          deallocate(perm1, perm, count)
          return
        end if
        first = perm1(0)
        do i = 0, r - 1
          perm1(i) = perm1(i + 1)
        end do
        perm1(r) = first
        count(r) = count(r) - 1
        if (count(r) > 0) exit
        r = r + 1
      end do
      perm_idx = perm_idx + 1
    end do
  end subroutine fannkuch
end module fannkuch_mod

program fannkuch_prog
  use iso_fortran_env, only: int32
  use fannkuch_mod
  implicit none
  character(len=32) :: buf
  integer(int32) :: n, max_flips, checksum

  n = 7
  if (command_argument_count() >= 1) then
    call get_command_argument(1, buf)
    read (buf, *) n
  end if
  call fannkuch(n, max_flips, checksum)
  write (*, '(I0)') checksum
  write (*, '(A,I0,A,I0)') 'Pfannkuchen(', n, ') = ', max_flips
end program fannkuch_prog
