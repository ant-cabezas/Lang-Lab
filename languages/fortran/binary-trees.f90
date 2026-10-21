! binary-trees: real heap node per tree node (allocate/deallocate, no arena), pointer
! components (not allocatable components) so destroy is explicit, mirroring malloc/free.
module bt_mod
  use iso_fortran_env, only: int32, int64
  implicit none
  type node
    type(node), pointer :: left => null()
    type(node), pointer :: right => null()
  end type node
contains
  recursive function make(depth) result(p)
    integer(int32), value :: depth
    type(node), pointer :: p
    allocate(p)
    if (depth /= 0) then
      p%left => make(depth - 1)
      p%right => make(depth - 1)
    end if
  end function make

  recursive function check(n) result(r)
    type(node), pointer :: n
    integer(int64) :: r
    if (.not. associated(n%left)) then
      r = 1
    else
      r = 1 + check(n%left) + check(n%right)
    end if
  end function check

  recursive subroutine destroy(n)
    type(node), pointer :: n
    if (associated(n%left)) then
      call destroy(n%left)
      call destroy(n%right)
    end if
    deallocate(n)
  end subroutine destroy

  function run(n) result(total)
    integer(int32), value :: n
    integer(int64) :: total, s
    integer(int32) :: min_depth, max_depth, stretch_depth, depth, iterations, i
    type(node), pointer :: stretch, long_lived, t

    min_depth = 4
    max_depth = max(min_depth + 2, n)
    stretch_depth = max_depth + 1

    stretch => make(stretch_depth)
    total = check(stretch)
    call destroy(stretch)

    long_lived => make(max_depth)

    depth = min_depth
    do while (depth <= max_depth)
      iterations = shiftl(1_int32, max_depth - depth + min_depth)
      s = 0
      do i = 0, iterations - 1
        t => make(depth)
        s = s + check(t)
        call destroy(t)
      end do
      total = total + s
      depth = depth + 2
    end do

    total = total + check(long_lived)
    call destroy(long_lived)
  end function run
end module bt_mod

program binary_trees
  use iso_fortran_env, only: int32
  use bt_mod
  implicit none
  character(len=32) :: buf
  integer(int32) :: n

  n = 10
  if (command_argument_count() >= 1) then
    call get_command_argument(1, buf)
    read (buf, *) n
  end if
  write (*, '(I0)') run(n)
  write (*, '(A,I0,A)') 'binary-trees(', n, ')'
end program binary_trees
