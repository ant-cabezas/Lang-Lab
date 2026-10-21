! bigint: hand-rolled base-2^32 limb factorial. Limbs are int64 holding 32-bit values
! (C uses uint32_t; 8 vs 4 bytes per limb, disclosed). cur = limb*k + carry, no bignum library.
module big_mod
  use iso_fortran_env, only: int32, int64
  implicit none
  integer(int64), parameter :: P = 1000000007_int64
  integer(int64), parameter :: M32 = 4294967295_int64
contains
  function run(n) result(h)
    integer(int32), value :: n
    integer(int64) :: h, carry, cur, k
    integer(int64), allocatable :: limbs(:)
    integer(int32) :: len, i

    allocate(limbs(0:n+63))
    len = 1
    limbs(0) = 1
    do k = 2, n
      carry = 0
      do i = 0, len - 1
        cur = limbs(i) * k + carry
        limbs(i) = iand(cur, M32)
        carry = shiftr(cur, 32)
      end do
      do while (carry > 0)
        limbs(len) = iand(carry, M32)
        len = len + 1
        carry = shiftr(carry, 32)
      end do
    end do
    h = 0
    do i = 0, len - 1
      h = mod(h * 31 + limbs(i), P)
    end do
    deallocate(limbs)
  end function run
end module big_mod

program bigint
  use iso_fortran_env, only: int32
  use big_mod
  implicit none
  character(len=32) :: buf
  integer(int32) :: n

  n = 6000
  if (command_argument_count() >= 1) then
    call get_command_argument(1, buf)
    read (buf, *) n
  end if
  write (*, '(I0)') run(n)
  write (*, '(A,I0,A)') 'bigint(', n, ')'
end program bigint
