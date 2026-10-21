! k-nucleotide: hand-rolled open-addressing table, linear probing, 8-char keys.
! Documented deviation (docs/fairness-audit.md): FNV-1a 32-bit computed in int64, because
! C's 64-bit FNV relies on unsigned wrap that Fortran cannot express portably.
module kn_mod
  use iso_fortran_env, only: int32, int64
  implicit none
  integer(int32), parameter :: K = 8
  integer(int64), parameter :: P = 1000000007_int64
  integer(int64), parameter :: IM = 139968_int64, IA = 3877_int64, IC = 29573_int64
  integer(int32), parameter :: HBITS = 18
  integer(int32), parameter :: HSIZE = 262144
  integer(int32), parameter :: HMASK = HSIZE - 1
  character(len=8) :: htkey(0:HSIZE-1)
  integer(int64) :: htcnt(0:HSIZE-1)
  integer(int32) :: htused(0:HSIZE-1)
contains
  subroutine gen(L, s)
    integer(int32), value :: L
    character(len=*), intent(inout) :: s
    integer(int64) :: seed
    integer(int32) :: i
    seed = 42
    do i = 1, L
      seed = mod(seed * IA + IC, IM)
      if (seed < 42000) then
        s(i:i) = 'A'
      else if (seed < 70000) then
        s(i:i) = 'C'
      else if (seed < 98000) then
        s(i:i) = 'G'
      else
        s(i:i) = 'T'
      end if
    end do
  end subroutine gen

  function fnv(p) result(h)
    character(len=8), intent(in) :: p
    integer(int64) :: h
    integer(int32) :: i
    h = 2166136261_int64
    do i = 1, K
      h = iand(ieor(h, int(ichar(p(i:i)), int64)) * 16777619_int64, 4294967295_int64)
    end do
  end function fnv

  subroutine add(kmer)
    character(len=8), intent(in) :: kmer
    integer(int32) :: h
    h = int(iand(fnv(kmer), int(HMASK, int64)), int32)
    do while (htused(h) /= 0)
      if (htkey(h) == kmer) then
        htcnt(h) = htcnt(h) + 1
        return
      end if
      h = iand(h + 1, HMASK)
    end do
    htused(h) = 1
    htkey(h) = kmer
    htcnt(h) = 1
  end subroutine add

  function run(L) result(acc)
    integer(int32), value :: L
    integer(int64) :: acc, e
    character(len=:), allocatable :: s
    integer(int32) :: i, b, j, code
    character(len=1) :: c

    allocate(character(len=L) :: s)
    call gen(L, s)
    htused = 0
    htcnt = 0
    do i = 1, L - K + 1
      call add(s(i:i+K-1))
    end do
    acc = 0
    do b = 0, HSIZE - 1
      if (htused(b) == 0) cycle
      e = 0
      do j = 1, K
        c = htkey(b)(j:j)
        if (c == 'A') then
          code = 0
        else if (c == 'C') then
          code = 1
        else if (c == 'G') then
          code = 2
        else
          code = 3
        end if
        e = e * 4 + code
      end do
      acc = mod(acc + e * htcnt(b), P)
    end do
    deallocate(s)
  end function run
end module kn_mod

program k_nucleotide
  use iso_fortran_env, only: int32
  use kn_mod
  implicit none
  character(len=32) :: buf
  integer(int32) :: n

  n = 100000
  if (command_argument_count() >= 1) then
    call get_command_argument(1, buf)
    read (buf, *) n
  end if
  write (*, '(I0)') run(n)
  write (*, '(A,I0,A)') 'k-nucleotide(', n, ')'
end program k_nucleotide
