(* Hand-written FIPS 180-4 SHA-256. Words are ints in [0, 2^32); one mask per assignment. *)
let p = 1000000007
let m32 = 0xFFFFFFFF

let kt = [|
  0x428a2f98;0x71374491;0xb5c0fbcf;0xe9b5dba5;0x3956c25b;0x59f111f1;0x923f82a4;0xab1c5ed5;
  0xd807aa98;0x12835b01;0x243185be;0x550c7dc3;0x72be5d74;0x80deb1fe;0x9bdc06a7;0xc19bf174;
  0xe49b69c1;0xefbe4786;0x0fc19dc6;0x240ca1cc;0x2de92c6f;0x4a7484aa;0x5cb0a9dc;0x76f988da;
  0x983e5152;0xa831c66d;0xb00327c8;0xbf597fc7;0xc6e00bf3;0xd5a79147;0x06ca6351;0x14292967;
  0x27b70a85;0x2e1b2138;0x4d2c6dfc;0x53380d13;0x650a7354;0x766a0abb;0x81c2c92e;0x92722c85;
  0xa2bfe8a1;0xa81a664b;0xc24b8b70;0xc76c51a3;0xd192e819;0xd6990624;0xf40e3585;0x106aa070;
  0x19a4c116;0x1e376c08;0x2748774c;0x34b0bcb5;0x391c0cb3;0x4ed8aa4a;0x5b9cca4f;0x682e6ff3;
  0x748f82ee;0x78a5636f;0x84c87814;0x8cc70208;0x90befffa;0xa4506ceb;0xbef9a3f7;0xc67178f2 |]

let h0 = [| 0x6a09e667;0xbb67ae85;0x3c6ef372;0xa54ff53a;0x510e527f;0x9b05688c;0x1f83d9ab;0x5be0cd19 |]

let[@inline] rotr (x : int) (n : int) : int = ((x lsr n) lor (x lsl (32 - n))) land m32

let w = Array.make 64 0
let b = Array.make 64 0
let h = Array.make 8 0

let sha256_block () : unit =
  for i = 0 to 15 do
    w.(i) <- (b.(i*4) lsl 24) lor (b.(i*4+1) lsl 16) lor (b.(i*4+2) lsl 8) lor b.(i*4+3)
  done;
  for i = 16 to 63 do
    let s0 = rotr w.(i-15) 7 lxor rotr w.(i-15) 18 lxor (w.(i-15) lsr 3) in
    let s1 = rotr w.(i-2) 17 lxor rotr w.(i-2) 19 lxor (w.(i-2) lsr 10) in
    w.(i) <- (w.(i-16) + s0 + w.(i-7) + s1) land m32
  done;
  let a = ref h.(0) and bb = ref h.(1) and c = ref h.(2) and d = ref h.(3) in
  let e = ref h.(4) and f = ref h.(5) and g = ref h.(6) and hh = ref h.(7) in
  for i = 0 to 63 do
    let s1 = rotr !e 6 lxor rotr !e 11 lxor rotr !e 25 in
    let ch = (!e land !f) lxor ((lnot !e) land !g) in
    let t1 = (!hh + s1 + ch + kt.(i) + w.(i)) land m32 in
    let s0 = rotr !a 2 lxor rotr !a 13 lxor rotr !a 22 in
    let maj = (!a land !bb) lxor (!a land !c) lxor (!bb land !c) in
    let t2 = (s0 + maj) land m32 in
    hh := !g; g := !f; f := !e;
    e := (!d + t1) land m32;
    d := !c; c := !bb; bb := !a;
    a := (t1 + t2) land m32
  done;
  h.(0) <- (h.(0) + !a) land m32; h.(1) <- (h.(1) + !bb) land m32;
  h.(2) <- (h.(2) + !c) land m32; h.(3) <- (h.(3) + !d) land m32;
  h.(4) <- (h.(4) + !e) land m32; h.(5) <- (h.(5) + !f) land m32;
  h.(6) <- (h.(6) + !g) land m32; h.(7) <- (h.(7) + !hh) land m32

let sha256_32 (digest : int array) : unit =
  for i = 0 to 31 do b.(i) <- digest.(i) done;
  b.(32) <- 0x80;
  for i = 33 to 63 do b.(i) <- 0 done;
  b.(62) <- 1;
  for i = 0 to 7 do h.(i) <- h0.(i) done;
  sha256_block ();
  for i = 0 to 7 do
    digest.(i*4)   <- (h.(i) lsr 24) land 0xFF;
    digest.(i*4+1) <- (h.(i) lsr 16) land 0xFF;
    digest.(i*4+2) <- (h.(i) lsr 8) land 0xFF;
    digest.(i*4+3) <- h.(i) land 0xFF
  done

let () =
  let n = if Array.length Sys.argv > 1 then int_of_string Sys.argv.(1) else 10000 in
  let d = Array.make 32 0 in
  let s = ref 42 in
  for i = 0 to 31 do
    s := (!s * 1103515245 + 12345) land 0x7fffffff;
    d.(i) <- !s mod 256
  done;
  for _ = 0 to n - 1 do sha256_32 d done;
  let hs = ref 0 in
  for i = 0 to 31 do hs := (!hs * 31 + d.(i)) mod p done;
  Printf.printf "%d\nsha256(%d)\n" !hs n
