! vm: stack bytecode VM running the fixed 40-int PROG verbatim; if-chain dispatch like C.
module vm_mod
  use iso_fortran_env, only: int32, int64
  implicit none
  integer(int64), parameter :: P = 1000000007_int64
  integer(int64), parameter :: MASK = 4294967295_int64
  integer(int64), parameter :: PROG(0:39) = [integer(int64) :: &
    0, 0, 2, 0, 0, 0, 2, 1, 1, 0, 1, 2, 6, 7, 37, 1, 1, 0, 31, 4, &
    1, 0, 1, 0, 4, 3, 2, 1, 1, 0, 0, 1, 3, 2, 0, 8, 8, 1, 1, 9 ]
contains
  function run(n) result(res)
    integer(int32), value :: n
    integer(int64) :: res, op, a, b, c, result_v
    integer(int64) :: stack(0:63), locals(0:2)
    integer(int32) :: sp, pc

    sp = 0
    locals(0) = 0
    locals(1) = 0
    locals(2) = n
    pc = 0
    result_v = 0
    do
      op = PROG(pc)
      pc = pc + 1
      if (op == 0) then
        stack(sp) = PROG(pc)
        sp = sp + 1
        pc = pc + 1
      else if (op == 1) then
        stack(sp) = locals(PROG(pc))
        sp = sp + 1
        pc = pc + 1
      else if (op == 2) then
        sp = sp - 1
        locals(PROG(pc)) = stack(sp)
        pc = pc + 1
      else if (op == 3) then
        sp = sp - 1
        b = stack(sp)
        sp = sp - 1
        a = stack(sp)
        stack(sp) = iand(a + b, MASK)
        sp = sp + 1
      else if (op == 4) then
        sp = sp - 1
        b = stack(sp)
        sp = sp - 1
        a = stack(sp)
        stack(sp) = iand(a * b, MASK)
        sp = sp + 1
      else if (op == 5) then
        sp = sp - 1
        b = stack(sp)
        sp = sp - 1
        a = stack(sp)
        stack(sp) = iand(a - b, MASK)
        sp = sp + 1
      else if (op == 6) then
        sp = sp - 1
        b = stack(sp)
        sp = sp - 1
        a = stack(sp)
        if (a < b) then
          stack(sp) = 1
        else
          stack(sp) = 0
        end if
        sp = sp + 1
      else if (op == 7) then
        sp = sp - 1
        c = stack(sp)
        if (c == 0) then
          pc = int(PROG(pc), int32)
        else
          pc = pc + 1
        end if
      else if (op == 8) then
        pc = int(PROG(pc), int32)
      else if (op == 9) then
        result_v = stack(sp - 1)
        exit
      end if
    end do
    res = mod(result_v, P)
  end function run
end module vm_mod

program vm
  use iso_fortran_env, only: int32
  use vm_mod
  implicit none
  character(len=32) :: buf
  integer(int32) :: n

  n = 800000
  if (command_argument_count() >= 1) then
    call get_command_argument(1, buf)
    read (buf, *) n
  end if
  write (*, '(I0)') run(n)
  write (*, '(A,I0,A)') 'vm(', n, ')'
end program vm
