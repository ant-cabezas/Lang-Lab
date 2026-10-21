let p = 1000000007

let comp (c : char) : char =
  match c with 'A' -> 'T' | 'C' -> 'G' | 'G' -> 'C' | _ -> 'A'

let () =
  let len = if Array.length Sys.argv > 1 then int_of_string Sys.argv.(1) else 100000 in
  let s = Bytes.create len in
  let seed = ref 42 in
  for i = 0 to len - 1 do
    seed := (!seed * 3877 + 29573) mod 139968;
    Bytes.set s i
      (if !seed < 42000 then 'A' else if !seed < 70000 then 'C'
       else if !seed < 98000 then 'G' else 'T')
  done;
  let i = ref 0 and j = ref (len - 1) in
  while !i < !j do
    let a = comp (Bytes.get s !i) in
    Bytes.set s !i (comp (Bytes.get s !j));
    Bytes.set s !j a;
    incr i; decr j
  done;
  if !i = !j then Bytes.set s !i (comp (Bytes.get s !i));
  let h = ref 0 in
  for k = 0 to len - 1 do
    h := (!h * 31 + Char.code (Bytes.get s k)) mod p
  done;
  Printf.printf "%d\nreverse-complement(%d)\n" !h len
