(* Hand-rolled base-2^32 limbs; no Int64, no Zarith/Num. *)
let p = 1000000007

let () =
  let n = if Array.length Sys.argv > 1 then int_of_string Sys.argv.(1) else 6000 in
  let limbs = Array.make (n + 64) 0 in
  let len = ref 1 in
  limbs.(0) <- 1;
  for k = 2 to n do
    let carry = ref 0 in
    for i = 0 to !len - 1 do
      let cur = limbs.(i) * k + !carry in
      limbs.(i) <- cur land 0xFFFFFFFF;
      carry := cur lsr 32
    done;
    while !carry > 0 do
      limbs.(!len) <- !carry land 0xFFFFFFFF;
      incr len;
      carry := !carry lsr 32
    done
  done;
  let h = ref 0 in
  for i = 0 to !len - 1 do h := (!h * 31 + limbs.(i)) mod p done;
  Printf.printf "%d\nbigint(%d)\n" !h n
