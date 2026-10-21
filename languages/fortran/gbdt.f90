! gbdt: gradient-boosted tree ensemble inference. Flat int32 arrays, children 2k+1 / 2k+2, <=.
module gbdt_mod
  use iso_fortran_env, only: int32, int64
  implicit none
  integer(int64), parameter :: P = 1000000007_int64
  integer(int32), parameter :: D = 8, B = 200, F = 8, NODES = 511, LEAF_START = 255
contains
  function lcg(x) result(r)
    integer(int64), value :: x
    integer(int64) :: r
    r = iand(x * 1103515245_int64 + 12345_int64, 2147483647_int64)
  end function lcg

  subroutine run(n, h, total)
    integer(int32), value :: n
    integer(int64), intent(out) :: h, total
    integer(int32), allocatable :: feat(:), thr(:), leafval(:), sample(:)
    integer(int64) :: s, acc
    integer(int32) :: bb, base, node, i, sbase, tbase, dd

    allocate(feat(0:B*NODES-1), thr(0:B*NODES-1), leafval(0:B*NODES-1), sample(0:n*F-1))
    s = 42
    do bb = 0, B - 1
      base = bb * NODES
      do node = 0, LEAF_START - 1
        s = lcg(s)
        feat(base + node) = int(mod(s, int(F, int64)), int32)
        s = lcg(s)
        thr(base + node) = int(mod(s, 256_int64), int32)
      end do
      do node = LEAF_START, NODES - 1
        s = lcg(s)
        leafval(base + node) = int(mod(s, 10_int64), int32)
      end do
    end do
    do i = 0, n * F - 1
      s = lcg(s)
      sample(i) = int(mod(s, 256_int64), int32)
    end do

    h = 0
    total = 0
    do i = 0, n - 1
      sbase = i * F
      acc = 0
      do bb = 0, B - 1
        tbase = bb * NODES
        node = 0
        do dd = 0, D - 1
          if (sample(sbase + feat(tbase + node)) <= thr(tbase + node)) then
            node = 2 * node + 1
          else
            node = 2 * node + 2
          end if
        end do
        acc = acc + leafval(tbase + node)
      end do
      h = mod(h * 31 + acc + 1, P)
      total = mod(total + acc, P)
    end do
    deallocate(feat, thr, leafval, sample)
  end subroutine run
end module gbdt_mod

program gbdt
  use iso_fortran_env, only: int32, int64
  use gbdt_mod
  implicit none
  character(len=32) :: buf
  integer(int32) :: n
  integer(int64) :: h, total

  n = 5000
  if (command_argument_count() >= 1) then
    call get_command_argument(1, buf)
    read (buf, *) n
  end if
  call run(n, h, total)
  write (*, '(I0)') h
  write (*, '(A,I0,A,I0)') 'gbdt(', n, ') = ', total
end program gbdt
