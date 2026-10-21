! polymorphism: F2003 type-bound dispatch. abstract base + deferred apply, six extended types,
! array of holder with class(base), allocatable component. No select type (the type switch);
! the construction-time select case only picks which type to allocate.
module poly_mod
  use iso_fortran_env, only: int32, int64
  implicit none
  integer(int64), parameter :: P = 1000000007_int64
  integer(int32), parameter :: N = 10000, KT = 6

  type, abstract :: base
    integer(int64) :: a = 0, b = 0, c = 0
  contains
    procedure(apply_if), deferred :: apply
  end type base

  abstract interface
    function apply_if(self, x) result(r)
      import :: base, int64
      class(base), intent(in) :: self
      integer(int64), value :: x
      integer(int64) :: r
    end function apply_if
  end interface

  type, extends(base) :: t0
  contains
    procedure :: apply => apply0
  end type t0
  type, extends(base) :: t1
  contains
    procedure :: apply => apply1
  end type t1
  type, extends(base) :: t2
  contains
    procedure :: apply => apply2
  end type t2
  type, extends(base) :: t3
  contains
    procedure :: apply => apply3
  end type t3
  type, extends(base) :: t4
  contains
    procedure :: apply => apply4
  end type t4
  type, extends(base) :: t5
  contains
    procedure :: apply => apply5
  end type t5

  type :: holder
    class(base), allocatable :: p
  end type holder
contains
  function apply0(self, x) result(r)
    class(t0), intent(in) :: self
    integer(int64), value :: x
    integer(int64) :: r
    r = mod(x * 1000003_int64 + self%a, P)
  end function apply0
  function apply1(self, x) result(r)
    class(t1), intent(in) :: self
    integer(int64), value :: x
    integer(int64) :: r
    r = mod(x * 998273_int64 + self%b, P)
  end function apply1
  function apply2(self, x) result(r)
    class(t2), intent(in) :: self
    integer(int64), value :: x
    integer(int64) :: r
    r = mod(x * 999983_int64 + self%c, P)
  end function apply2
  function apply3(self, x) result(r)
    class(t3), intent(in) :: self
    integer(int64), value :: x
    integer(int64) :: r
    r = mod(x * 997879_int64 + self%a + self%b, P)
  end function apply3
  function apply4(self, x) result(r)
    class(t4), intent(in) :: self
    integer(int64), value :: x
    integer(int64) :: r
    r = mod(x * 996323_int64 + self%b * self%c, P)
  end function apply4
  function apply5(self, x) result(r)
    class(t5), intent(in) :: self
    integer(int64), value :: x
    integer(int64) :: r
    r = mod(x * 995369_int64 + self%a + self%c, P)
  end function apply5

  function lcg(s) result(r)
    integer(int64), value :: s
    integer(int64) :: r
    r = iand(s * 1103515245_int64 + 12345_int64, 2147483647_int64)
  end function lcg

  function run(m) result(acc)
    integer(int32), value :: m
    integer(int64) :: acc, s
    type(holder), allocatable :: objs(:)
    integer(int32) :: i, pass, ty

    allocate(objs(0:N-1))
    s = 42
    do i = 0, N - 1
      s = lcg(s)
      ty = int(mod(shiftr(s, 16), int(KT, int64)), int32)
      select case (ty)
      case (0)
        allocate(t0 :: objs(i)%p)
      case (1)
        allocate(t1 :: objs(i)%p)
      case (2)
        allocate(t2 :: objs(i)%p)
      case (3)
        allocate(t3 :: objs(i)%p)
      case (4)
        allocate(t4 :: objs(i)%p)
      case default
        allocate(t5 :: objs(i)%p)
      end select
      s = lcg(s)
      objs(i)%p%a = mod(s, 1000_int64)
      s = lcg(s)
      objs(i)%p%b = mod(s, 1000_int64)
      s = lcg(s)
      objs(i)%p%c = mod(s, 1000_int64)
    end do
    acc = 1
    do pass = 0, m - 1
      do i = 0, N - 1
        acc = objs(i)%p%apply(acc)
      end do
    end do
  end function run
end module poly_mod

program polymorphism
  use iso_fortran_env, only: int32
  use poly_mod
  implicit none
  character(len=32) :: buf
  integer(int32) :: m

  m = 50
  if (command_argument_count() >= 1) then
    call get_command_argument(1, buf)
    read (buf, *) m
  end if
  write (*, '(I0)') run(m)
  write (*, '(A,I0,A)') 'polymorphism(', m, ')'
end program polymorphism
