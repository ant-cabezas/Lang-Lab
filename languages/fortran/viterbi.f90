! viterbi: integer max-plus trellis, S=8, ALPHA=4, strict > (lowest index wins), flat back-pointers.
module vit_mod
  use iso_fortran_env, only: int32, int64
  implicit none
  integer(int64), parameter :: P = 1000000007_int64
  integer(int32), parameter :: S = 8, ALPHA = 4
contains
  function lcg(x) result(r)
    integer(int64), value :: x
    integer(int64) :: r
    r = iand(x * 1103515245_int64 + 12345_int64, 2147483647_int64)
  end function lcg

  subroutine run(tt, h, secondary)
    integer(int32), value :: tt
    integer(int64), intent(out) :: h, secondary
    integer(int64) :: trans(0:S*S-1), emit_t(0:S*ALPHA-1), vit(0:2*S-1)
    integer(int32), allocatable :: obs(:), back(:), path(:)
    integer(int64) :: sd, best, sc
    integer(int32) :: x, t, i, j, bi, po, no, tmp, bf

    allocate(obs(0:tt-1), back(0:tt*S-1), path(0:tt-1))
    sd = 42
    do x = 0, S * S - 1
      sd = lcg(sd)
      trans(x) = mod(sd, 100_int64) + 1
    end do
    do x = 0, S * ALPHA - 1
      sd = lcg(sd)
      emit_t(x) = mod(sd, 100_int64) + 1
    end do
    do t = 0, tt - 1
      sd = lcg(sd)
      obs(t) = int(mod(sd, int(ALPHA, int64)), int32)
    end do

    po = 0
    no = S
    do j = 0, S - 1
      vit(po + j) = emit_t(j * ALPHA + obs(0))
    end do
    do t = 1, tt - 1
      do j = 0, S - 1
        best = -1
        bi = 0
        do i = 0, S - 1
          sc = vit(po + i) + trans(i * S + j) + emit_t(j * ALPHA + obs(t))
          if (sc > best) then
            best = sc
            bi = i
          end if
        end do
        vit(no + j) = best
        back(t * S + j) = bi
      end do
      tmp = po
      po = no
      no = tmp
    end do

    bf = 0
    do j = 1, S - 1
      if (vit(po + j) > vit(po + bf)) bf = j
    end do

    path(tt - 1) = bf
    do t = tt - 2, 0, -1
      path(t) = back((t + 1) * S + path(t + 1))
    end do

    h = 0
    do t = 0, tt - 1
      h = mod(h * 31 + path(t) + 1, P)
    end do
    secondary = mod(vit(po + bf), P)
    deallocate(obs, back, path)
  end subroutine run
end module vit_mod

program viterbi
  use iso_fortran_env, only: int32, int64
  use vit_mod
  implicit none
  character(len=32) :: buf
  integer(int32) :: n
  integer(int64) :: h, secondary

  n = 20000
  if (command_argument_count() >= 1) then
    call get_command_argument(1, buf)
    read (buf, *) n
  end if
  call run(n, h, secondary)
  write (*, '(I0)') h
  write (*, '(A,I0,A,I0)') 'viterbi(', n, ') = ', secondary
end program viterbi
