let p = 1000000007
let window = 512
let min_match = 3
let max_match = 255
let alpha = 6

let[@inline] lcg (s : int) : int = (s * 1103515245 + 12345) land 0x7fffffff

let () =
  let n = if Array.length Sys.argv > 1 then int_of_string Sys.argv.(1) else 24000 in
  let inp = Bytes.create n in
  let s = ref 42 in
  for i = 0 to n - 1 do
    s := lcg !s;
    Bytes.set inp i (Char.chr (!s mod alpha))
  done;
  let pos = ref 0 and h = ref 0 in
  while !pos < n do
    let best_len = ref 0 and best_dist = ref 0 in
    let start = if !pos - window < 0 then 0 else !pos - window in
    for cand = !pos - 1 downto start do
      let l = ref 0 in
      while !pos + !l < n && !l < max_match
            && Char.code (Bytes.get inp (cand + !l)) = Char.code (Bytes.get inp (!pos + !l)) do
        incr l
      done;
      if !l > !best_len then begin best_len := !l; best_dist := !pos - cand end
    done;
    if !best_len >= min_match then begin
      h := (!h * 31 + 1) mod p;
      h := (!h * 31 + !best_dist) mod p;
      h := (!h * 31 + !best_len) mod p;
      pos := !pos + !best_len
    end else begin
      h := (!h * 31 + 0) mod p;
      h := (!h * 31 + Char.code (Bytes.get inp !pos)) mod p;
      pos := !pos + 1
    end
  done;
  Printf.printf "%d\nlz77(%d)\n" !h n
