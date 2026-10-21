let calls = ref 0

let rec tak (x : int) (y : int) (z : int) : int =
  incr calls;
  if y < x then tak (tak (x - 1) y z) (tak (y - 1) z x) (tak (z - 1) x y)
  else z

let () =
  let n = if Array.length Sys.argv > 1 then int_of_string Sys.argv.(1) else 6 in
  let r = tak (3 * n) (2 * n) n in
  Printf.printf "%d\ntak(%d) = %d\n" !calls n r
