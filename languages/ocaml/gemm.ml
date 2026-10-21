let p = 1000000007

let[@inline] lcg (s : int) : int = (s * 1103515245 + 12345) land 0x7fffffff

let () =
  let n = if Array.length Sys.argv > 1 then int_of_string Sys.argv.(1) else 256 in
  let a = Array.make (n * n) 0 and b = Array.make (n * n) 0 and c = Array.make (n * n) 0 in
  let s = ref 42 in
  for i = 0 to n * n - 1 do s := lcg !s; a.(i) <- !s mod 128 done;
  for i = 0 to n * n - 1 do s := lcg !s; b.(i) <- !s mod 128 done;
  for i = 0 to n - 1 do
    for k = 0 to n - 1 do
      let aik = a.(i * n + k) in
      for j = 0 to n - 1 do
        c.(i * n + j) <- c.(i * n + j) + aik * b.(k * n + j)
      done
    done
  done;
  let h = ref 0 in
  for i = 0 to n * n - 1 do h := (!h * 31 + c.(i) mod p) mod p done;
  let secondary = c.(n * n - 1) mod p in
  Printf.printf "%d\ngemm(%d) = %d\n" !h n secondary
