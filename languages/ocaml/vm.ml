let p = 1000000007
let mask = 0xFFFFFFFF

let prog = [| 0;0;2;0;0;0;2;1;1;0;1;2;6;7;37;1;1;0;31;4;1;0;1;0;4;3;2;1;1;0;0;1;3;2;0;8;8;1;1;9 |]

let () =
  let n = if Array.length Sys.argv > 1 then int_of_string Sys.argv.(1) else 800000 in
  let stack = Array.make 64 0 in
  let sp = ref 0 in
  let locals = [| 0; 0; n |] in
  let pc = ref 0 and result = ref 0 and running = ref true in
  while !running do
    let op = prog.(!pc) in
    incr pc;
    if op = 0 then begin stack.(!sp) <- prog.(!pc); incr pc; incr sp end
    else if op = 1 then begin stack.(!sp) <- locals.(prog.(!pc)); incr pc; incr sp end
    else if op = 2 then begin decr sp; locals.(prog.(!pc)) <- stack.(!sp); incr pc end
    else if op = 3 then begin
      decr sp; let b = stack.(!sp) in decr sp; let a = stack.(!sp) in
      stack.(!sp) <- (a + b) land mask; incr sp end
    else if op = 4 then begin
      decr sp; let b = stack.(!sp) in decr sp; let a = stack.(!sp) in
      stack.(!sp) <- (a * b) land mask; incr sp end
    else if op = 5 then begin
      decr sp; let b = stack.(!sp) in decr sp; let a = stack.(!sp) in
      stack.(!sp) <- (a - b) land mask; incr sp end
    else if op = 6 then begin
      decr sp; let b = stack.(!sp) in decr sp; let a = stack.(!sp) in
      stack.(!sp) <- (if a < b then 1 else 0); incr sp end
    else if op = 7 then begin
      decr sp; let c = stack.(!sp) in
      if c = 0 then pc := prog.(!pc) else incr pc end
    else if op = 8 then pc := prog.(!pc)
    else if op = 9 then begin result := stack.(!sp - 1); running := false end
  done;
  Printf.printf "%d\nvm(%d)\n" (!result mod p) n
