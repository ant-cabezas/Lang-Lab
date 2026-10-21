(* C uses 4-byte int arrays; OCaml int arrays are 8 bytes per element (disclosed). *)
let p = 1000000007
let depth = 8
let nb = 200
let nf = 8
let nodes = 511
let leaf_start = 255

let[@inline] lcg (s : int) : int = (s * 1103515245 + 12345) land 0x7fffffff

let () =
  let n = if Array.length Sys.argv > 1 then int_of_string Sys.argv.(1) else 5000 in
  let feat = Array.make (nb * nodes) 0 and thr = Array.make (nb * nodes) 0 in
  let leafval = Array.make (nb * nodes) 0 and sample = Array.make (n * nf) 0 in
  let s = ref 42 in
  for b = 0 to nb - 1 do
    let base = b * nodes in
    for node = 0 to leaf_start - 1 do
      s := lcg !s; feat.(base + node) <- !s mod nf;
      s := lcg !s; thr.(base + node) <- !s mod 256
    done;
    for node = leaf_start to nodes - 1 do
      s := lcg !s; leafval.(base + node) <- !s mod 10
    done
  done;
  for i = 0 to n * nf - 1 do s := lcg !s; sample.(i) <- !s mod 256 done;
  let h = ref 0 and total = ref 0 in
  for i = 0 to n - 1 do
    let sbase = i * nf in
    let acc = ref 0 in
    for b = 0 to nb - 1 do
      let tbase = b * nodes in
      let node = ref 0 in
      for _ = 0 to depth - 1 do
        if sample.(sbase + feat.(tbase + !node)) <= thr.(tbase + !node)
        then node := 2 * !node + 1
        else node := 2 * !node + 2
      done;
      acc := !acc + leafval.(tbase + !node)
    done;
    h := (!h * 31 + !acc + 1) mod p;
    total := (!total + !acc) mod p
  done;
  Printf.printf "%d\ngbdt(%d) = %d\n" !h n !total
