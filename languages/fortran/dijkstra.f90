! dijkstra: hand-written binary min-heap of packed keys dist*2^21+node, CSR adjacency.
! Module-level allocatable arrays (C uses static globals); heap conditions split into nested if.
module dj_mod
  use iso_fortran_env, only: int32, int64
  implicit none
  integer(int64), parameter :: P = 1000000007_int64
  integer(int64), parameter :: INF = ishft(1_int64, 62)
  integer(int64), parameter :: DEG = 8, MAXW = 100, BASE = 2097152_int64
  integer(int64), allocatable :: heap(:)
  integer(int64) :: hsize
contains
  function lcg(s) result(r)
    integer(int64), value :: s
    integer(int64) :: r
    r = iand(s * 1103515245_int64 + 12345_int64, 2147483647_int64)
  end function lcg

  subroutine hpush(k)
    integer(int64), value :: k
    integer(int64) :: i, pp, t
    i = hsize
    hsize = hsize + 1
    heap(i) = k
    do while (i > 0)
      pp = (i - 1) / 2
      if (heap(pp) <= heap(i)) exit
      t = heap(pp)
      heap(pp) = heap(i)
      heap(i) = t
      i = pp
    end do
  end subroutine hpush

  function hpop() result(top)
    integer(int64) :: top, i, l, r, m, t
    top = heap(0)
    hsize = hsize - 1
    heap(0) = heap(hsize)
    i = 0
    do
      l = 2 * i + 1
      r = 2 * i + 2
      m = i
      if (l < hsize) then
        if (heap(l) < heap(m)) m = l
      end if
      if (r < hsize) then
        if (heap(r) < heap(m)) m = r
      end if
      if (m == i) exit
      t = heap(m)
      heap(m) = heap(i)
      heap(i) = t
      i = m
    end do
  end function hpop

  function run(n) result(h)
    integer(int32), value :: n
    integer(int64) :: h, m, s, e, pos, key, d, u, v, nd, di
    integer(int32) :: i
    integer(int32), allocatable :: eu(:), ev(:), ew(:), adjV(:), adjW(:)
    integer(int64), allocatable :: start(:), cnt(:), dist(:)

    m = DEG * n
    allocate(eu(0:m-1), ev(0:m-1), ew(0:m-1))
    s = 42
    do e = 0, m - 1
      s = lcg(s)
      eu(e) = int(mod(s, int(n, int64)), int32)
      s = lcg(s)
      ev(e) = int(mod(s, int(n, int64)), int32)
      s = lcg(s)
      ew(e) = int(mod(s, MAXW) + 1, int32)
    end do
    allocate(start(0:n), cnt(0:n-1))
    start = 0
    cnt = 0
    do e = 0, m - 1
      start(eu(e) + 1) = start(eu(e) + 1) + 1
    end do
    do i = 0, n - 1
      start(i + 1) = start(i + 1) + start(i)
    end do
    allocate(adjV(0:m-1), adjW(0:m-1))
    do e = 0, m - 1
      pos = start(eu(e)) + cnt(eu(e))
      cnt(eu(e)) = cnt(eu(e)) + 1
      adjV(pos) = ev(e)
      adjW(pos) = ew(e)
    end do
    allocate(dist(0:n-1))
    do i = 0, n - 1
      dist(i) = INF
    end do
    dist(0) = 0
    allocate(heap(0:m))
    hsize = 0
    call hpush(0_int64)
    do while (hsize > 0)
      key = hpop()
      d = key / BASE
      u = mod(key, BASE)
      if (d > dist(u)) cycle
      do e = start(u), start(u + 1) - 1
        v = adjV(e)
        nd = d + adjW(e)
        if (nd < dist(v)) then
          dist(v) = nd
          call hpush(nd * BASE + v)
        end if
      end do
    end do
    h = 0
    do i = 0, n - 1
      if (dist(i) < INF) then
        di = dist(i)
      else
        di = 0
      end if
      h = mod(h * 31 + mod(di, P), P)
    end do
    deallocate(eu, ev, ew, adjV, adjW, start, cnt, dist, heap)
  end function run
end module dj_mod

program dijkstra
  use iso_fortran_env, only: int32
  use dj_mod
  implicit none
  character(len=32) :: buf
  integer(int32) :: n

  n = 10000
  if (command_argument_count() >= 1) then
    call get_command_argument(1, buf)
    read (buf, *) n
  end if
  write (*, '(I0)') run(n)
  write (*, '(A,I0,A)') 'dijkstra(', n, ')'
end program dijkstra
