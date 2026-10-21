let p = 1000000007
let ns = 8
let alpha = 4

let[@inline] lcg (s : int) : int = (s * 1103515245 + 12345) land 0x7fffffff

let () =
  let tt = if Array.length Sys.argv > 1 then int_of_string Sys.argv.(1) else 20000 in
  let trans = Array.make (ns * ns) 0 and emit_t = Array.make (ns * alpha) 0 in
  let obs = Array.make tt 0 and back = Array.make (tt * ns) 0 and path = Array.make tt 0 in
  let s = ref 42 in
  for x = 0 to ns * ns - 1 do s := lcg !s; trans.(x) <- !s mod 100 + 1 done;
  for x = 0 to ns * alpha - 1 do s := lcg !s; emit_t.(x) <- !s mod 100 + 1 done;
  for t = 0 to tt - 1 do s := lcg !s; obs.(t) <- !s mod alpha done;
  let prev = ref (Array.make ns 0) and next = ref (Array.make ns 0) in
  for j = 0 to ns - 1 do !prev.(j) <- emit_t.(j * alpha + obs.(0)) done;
  for t = 1 to tt - 1 do
    let vp = !prev and vn = !next in
    for j = 0 to ns - 1 do
      let best = ref (-1) and bi = ref 0 in
      for i = 0 to ns - 1 do
        let sc = vp.(i) + trans.(i * ns + j) + emit_t.(j * alpha + obs.(t)) in
        if sc > !best then begin best := sc; bi := i end
      done;
      vn.(j) <- !best;
      back.(t * ns + j) <- !bi
    done;
    prev := vn;
    next := vp
  done;
  let vp = !prev in
  let bf = ref 0 in
  for j = 1 to ns - 1 do
    if vp.(j) > vp.(!bf) then bf := j
  done;
  path.(tt - 1) <- !bf;
  for t = tt - 2 downto 0 do
    path.(t) <- back.((t + 1) * ns + path.(t + 1))
  done;
  let h = ref 0 in
  for t = 0 to tt - 1 do h := (!h * 31 + path.(t) + 1) mod p done;
  let secondary = vp.(!bf) mod p in
  Printf.printf "%d\nviterbi(%d) = %d\n" !h tt secondary
