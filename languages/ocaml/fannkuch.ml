let fannkuch (n : int) : int * int =
  let perm1 = Array.make n 0 in
  let perm = Array.make n 0 in
  let count = Array.make n 0 in
  for i = 0 to n - 1 do perm1.(i) <- i done;
  let max_flips = ref 0 and checksum = ref 0 and r = ref n in
  let perm_idx = ref 0 in
  let finished = ref false in
  while not !finished do
    while !r <> 1 do count.(!r - 1) <- !r; decr r done;
    Array.blit perm1 0 perm 0 n;
    let flips = ref 0 in
    while perm.(0) <> 0 do
      let k = perm.(0) in
      let i = ref 0 and j = ref k in
      while !i < !j do
        let t = perm.(!i) in
        perm.(!i) <- perm.(!j);
        perm.(!j) <- t;
        incr i; decr j
      done;
      incr flips
    done;
    if !flips > !max_flips then max_flips := !flips;
    if !perm_idx mod 2 = 0 then checksum := !checksum + !flips
    else checksum := !checksum - !flips;
    let continue_ = ref true in
    while !continue_ do
      if !r = n then begin
        finished := true;
        continue_ := false
      end else begin
        let first = perm1.(0) in
        for i = 0 to !r - 1 do perm1.(i) <- perm1.(i + 1) done;
        perm1.(!r) <- first;
        count.(!r) <- count.(!r) - 1;
        if count.(!r) > 0 then continue_ := false
        else incr r
      end
    done;
    if not !finished then incr perm_idx
  done;
  (!checksum, !max_flips)

let () =
  let n = if Array.length Sys.argv > 1 then int_of_string Sys.argv.(1) else 7 in
  let (checksum, max_flips) = fannkuch n in
  Printf.printf "%d\nPfannkuchen(%d) = %d\n" checksum n max_flips
