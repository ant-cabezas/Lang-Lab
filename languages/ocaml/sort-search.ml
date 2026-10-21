let p = 1000000007

let[@inline] lcg_next (s : int) : int = (s * 1103515245 + 12345) land 0x7fffffff

let[@inline] swap (a : int array) (i : int) (j : int) : unit =
  let t = a.(i) in
  a.(i) <- a.(j);
  a.(j) <- t

(* median-of-three + Hoare partition, recurse both sides *)
let rec qsort_h (a : int array) (lo : int) (hi : int) : unit =
  if lo < hi then begin
    let mid = lo + (hi - lo) / 2 in
    if a.(mid) < a.(lo) then swap a lo mid;
    if a.(hi) < a.(lo) then swap a lo hi;
    if a.(hi) < a.(mid) then swap a mid hi;
    let pivot = a.(mid) in
    let i = ref (lo - 1) and j = ref (hi + 1) in
    let go = ref true in
    while !go do
      incr i;
      while a.(!i) < pivot do incr i done;
      decr j;
      while a.(!j) > pivot do decr j done;
      if !i >= !j then go := false else swap a !i !j
    done;
    qsort_h a lo !j;
    qsort_h a (!j + 1) hi
  end

let rec bsearch_i (a : int array) (key : int) (lo : int) (hi : int) : int =
  if lo > hi then -1
  else
    let mid = lo + (hi - lo) / 2 in
    if a.(mid) < key then bsearch_i a key (mid + 1) hi
    else if a.(mid) > key then bsearch_i a key lo (mid - 1)
    else mid

let () =
  let n = if Array.length Sys.argv > 1 then int_of_string Sys.argv.(1) else 100000 in
  let a = Array.make n 0 in
  let state = ref 42 in
  for i = 0 to n - 1 do
    state := lcg_next !state;
    a.(i) <- !state
  done;
  qsort_h a 0 (n - 1);
  let h = ref 0 in
  for _ = 0 to n - 1 do
    state := lcg_next !state;
    let key = a.(!state mod n) in
    let idx = bsearch_i a key 0 (n - 1) in
    h := (!h * 31 + (idx + 1)) mod p
  done;
  Printf.printf "%d\nsort-search(%d)\n" !h n
