(* Every tree node, leaves included, is one heap block, as in C where leaves are malloc'd.
   [Nil] is immediate and allocates nothing. No explicit free: the GC reclaims garbage. *)
type node = Nil | Node of node * node

let rec make (depth : int) : node =
  if depth = 0 then Node (Nil, Nil)
  else
    let l = make (depth - 1) in
    let r = make (depth - 1) in
    Node (l, r)

let rec check (n : node) : int =
  match n with
  | Node (Nil, _) -> 1
  | Node (l, r) -> 1 + check l + check r
  | Nil -> 0

let run (n : int) : int =
  let min_depth = 4 in
  let max_depth = if min_depth + 2 > n then min_depth + 2 else n in
  let stretch_depth = max_depth + 1 in
  let stretch = make stretch_depth in
  let total = ref (check stretch) in
  let long_lived = make max_depth in
  let depth = ref min_depth in
  while !depth <= max_depth do
    let iterations = 1 lsl (max_depth - !depth + min_depth) in
    let s = ref 0 in
    for _ = 0 to iterations - 1 do
      let t = make !depth in
      s := !s + check t
    done;
    total := !total + !s;
    depth := !depth + 2
  done;
  total := !total + check long_lived;
  !total

let () =
  let n = if Array.length Sys.argv > 1 then int_of_string Sys.argv.(1) else 10 in
  Printf.printf "%d\nbinary-trees(%d)\n" (run n) n
