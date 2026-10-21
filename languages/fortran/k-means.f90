! k-means: integer Lloyd's clustering, flat int64 arrays, strict < tie-break, bd = -1 sentinel.
module km_mod
  use iso_fortran_env, only: int32, int64
  implicit none
  integer(int64), parameter :: P = 1000000007_int64
  integer(int32), parameter :: K = 16, D = 4, ITERS = 10
  integer(int64), parameter :: RANGE = 256
contains
  function lcg(s) result(r)
    integer(int64), value :: s
    integer(int64) :: r
    r = iand(s * 1103515245_int64 + 12345_int64, 2147483647_int64)
  end function lcg

  subroutine assign_all(pt, cen, assign, n)
    integer(int64), intent(in) :: pt(0:*), cen(0:*)
    integer(int32), intent(out) :: assign(0:*)
    integer(int32), value :: n
    integer(int32) :: i, kk, dd, best
    integer(int64) :: bd, dist, df
    do i = 0, n - 1
      best = 0
      bd = -1
      do kk = 0, K - 1
        dist = 0
        do dd = 0, D - 1
          df = pt(int(i, int64) * D + dd) - cen(kk * D + dd)
          dist = dist + df * df
        end do
        if (bd < 0 .or. dist < bd) then
          bd = dist
          best = kk
        end if
      end do
      assign(i) = best
    end do
  end subroutine assign_all

  function run(n) result(h)
    integer(int32), value :: n
    integer(int64) :: h, s, i
    integer(int64), allocatable :: pt(:)
    integer(int64) :: cen(0:K*D-1), ssum(0:K*D-1), cnt(0:K-1)
    integer(int32), allocatable :: assign(:)
    integer(int32) :: iter, ii, kk, dd

    allocate(pt(0:int(n, int64) * D - 1), assign(0:n-1))
    s = 42
    do i = 0, int(n, int64) * D - 1
      s = lcg(s)
      pt(i) = mod(s, RANGE)
    end do
    do ii = 0, K * D - 1
      cen(ii) = pt(ii)
    end do
    do iter = 0, ITERS - 1
      call assign_all(pt, cen, assign, n)
      ssum = 0
      cnt = 0
      do ii = 0, n - 1
        kk = assign(ii)
        cnt(kk) = cnt(kk) + 1
        do dd = 0, D - 1
          ssum(kk * D + dd) = ssum(kk * D + dd) + pt(int(ii, int64) * D + dd)
        end do
      end do
      do kk = 0, K - 1
        if (cnt(kk) > 0) then
          do dd = 0, D - 1
            cen(kk * D + dd) = ssum(kk * D + dd) / cnt(kk)
          end do
        end if
      end do
    end do
    call assign_all(pt, cen, assign, n)
    h = 0
    do ii = 0, K * D - 1
      h = mod(h * 31 + cen(ii), P)
    end do
    do ii = 0, n - 1
      h = mod(h * 31 + assign(ii), P)
    end do
    deallocate(pt, assign)
  end function run
end module km_mod

program k_means
  use iso_fortran_env, only: int32
  use km_mod
  implicit none
  character(len=32) :: buf
  integer(int32) :: n

  n = 8000
  if (command_argument_count() >= 1) then
    call get_command_argument(1, buf)
    read (buf, *) n
  end if
  write (*, '(I0)') run(n)
  write (*, '(A,I0,A)') 'k-means(', n, ')'
end program k_means
