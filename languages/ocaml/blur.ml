let p = 1000000007
let passes = 4

let[@inline] lcg (s : int) : int = (s * 1103515245 + 12345) land 0x7fffffff
let[@inline] clampi (x : int) (n : int) : int = if x < 0 then 0 else if x >= n then n - 1 else x

let kern = [| 1; 2; 1; 2; 4; 2; 1; 2; 1 |]

let () =
  let n = if Array.length Sys.argv > 1 then int_of_string Sys.argv.(1) else 256 in
  let src = ref (Array.make (n * n) 0) in
  let dst = ref (Array.make (n * n) 0) in
  let s = ref 42 in
  for k = 0 to n * n - 1 do
    s := lcg !s;
    !src.(k) <- !s mod 256
  done;
  for _ = 0 to passes - 1 do
    let a = !src and b = !dst in
    for i = 0 to n - 1 do
      for j = 0 to n - 1 do
        let acc = ref 0 in
        for di = -1 to 1 do
          let ni = clampi (i + di) n in
          for dj = -1 to 1 do
            let nj = clampi (j + dj) n in
            acc := !acc + kern.((di + 1) * 3 + (dj + 1)) * a.(ni * n + nj)
          done
        done;
        b.(i * n + j) <- !acc / 16
      done
    done;
    src := b;
    dst := a
  done;
  let h = ref 0 in
  let f = !src in
  for k = 0 to n * n - 1 do
    h := (!h * 31 + f.(k)) mod p
  done;
  Printf.printf "%d\nblur(%d)\n" !h n
