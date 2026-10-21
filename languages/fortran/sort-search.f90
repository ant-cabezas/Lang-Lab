! sort-search: hand-written median-of-three Hoare quicksort + binary search.
module ss_mod
  use iso_fortran_env, only: int32, int64
  implicit none
  integer(int64), parameter :: P = 1000000007_int64
contains
  function lcg_next(s) result(r)
    integer(int64), value :: s
    integer(int64) :: r
    r = iand(s * 1103515245_int64 + 12345_int64, 2147483647_int64)
  end function lcg_next

  subroutine swap(a, i, j)
    integer(int64), intent(inout) :: a(0:*)
    integer(int32), value :: i, j
    integer(int64) :: t
    t = a(i)
    a(i) = a(j)
    a(j) = t
  end subroutine swap

  recursive subroutine qsort_h(a, lo, hi)
    integer(int64), intent(inout) :: a(0:*)
    integer(int32), value :: lo, hi
    integer(int32) :: mid, i, j
    integer(int64) :: pivot

    if (lo >= hi) return
    mid = lo + (hi - lo) / 2
    if (a(mid) < a(lo)) call swap(a, lo, mid)
    if (a(hi) < a(lo)) call swap(a, lo, hi)
    if (a(hi) < a(mid)) call swap(a, mid, hi)
    pivot = a(mid)
    i = lo - 1
    j = hi + 1
    do
      do
        i = i + 1
        if (a(i) >= pivot) exit
      end do
      do
        j = j - 1
        if (a(j) <= pivot) exit
      end do
      if (i >= j) exit
      call swap(a, i, j)
    end do
    call qsort_h(a, lo, j)
    call qsort_h(a, j + 1, hi)
  end subroutine qsort_h

  function bsearch_i(a, n, key) result(r)
    integer(int64), intent(in) :: a(0:*)
    integer(int32), value :: n
    integer(int64), value :: key
    integer(int32) :: r, lo, hi, mid
    lo = 0
    hi = n - 1
    r = -1
    do while (lo <= hi)
      mid = lo + (hi - lo) / 2
      if (a(mid) < key) then
        lo = mid + 1
      else if (a(mid) > key) then
        hi = mid - 1
      else
        r = mid
        return
      end if
    end do
  end function bsearch_i

  function run(n) result(h)
    integer(int32), value :: n
    integer(int64) :: h, state, key
    integer(int64), allocatable :: a(:)
    integer(int32) :: i, q, idx

    allocate(a(0:n-1))
    state = 42
    do i = 0, n - 1
      state = lcg_next(state)
      a(i) = state
    end do
    call qsort_h(a, 0, n - 1)
    h = 0
    do q = 0, n - 1
      state = lcg_next(state)
      key = a(mod(state, int(n, int64)))
      idx = bsearch_i(a, n, key)
      h = mod(h * 31 + (idx + 1), P)
    end do
    deallocate(a)
  end function run
end module ss_mod

program sort_search
  use iso_fortran_env, only: int32
  use ss_mod
  implicit none
  character(len=32) :: buf
  integer(int32) :: n

  n = 100000
  if (command_argument_count() >= 1) then
    call get_command_argument(1, buf)
    read (buf, *) n
  end if
  write (*, '(I0)') run(n)
  write (*, '(A,I0,A)') 'sort-search(', n, ')'
end program sort_search
