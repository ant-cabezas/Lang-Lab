(* Native float, +. -. *. /. only (no Float.fma). The whole pixel loop lives in one function with
   local float refs so ocamlopt keeps them unboxed in registers. *)
let mandel (n : int) : int =
  let count = ref 0 in
  for y = 0 to n - 1 do
    let ci : float = 2.0 *. float_of_int y /. float_of_int n -. 1.0 in
    for x = 0 to n - 1 do
      let cr : float = 2.0 *. float_of_int x /. float_of_int n -. 1.5 in
      let zr = ref 0.0 and zi = ref 0.0 and tr = ref 0.0 and ti = ref 0.0 in
      let i = ref 0 in
      while !i < 50 && !tr +. !ti <= 4.0 do
        let t = !zr *. !zi in
        zi := t +. t +. ci;
        zr := !tr -. !ti +. cr;
        tr := !zr *. !zr;
        ti := !zi *. !zi;
        incr i
      done;
      if !tr +. !ti <= 4.0 then incr count
    done
  done;
  !count

let () =
  let n = if Array.length Sys.argv > 1 then int_of_string Sys.argv.(1) else 128 in
  Printf.printf "%d\nmandelbrot(%d)\n" (mandel n) n
