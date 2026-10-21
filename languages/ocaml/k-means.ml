let p = 1000000007
let kk = 16
let dd = 4
let iters = 10
let range = 256

let[@inline] lcg (s : int) : int = (s * 1103515245 + 12345) land 0x7fffffff

(* nearest centroid by integer squared distance, strict < (lowest index wins ties) *)
let assign_all (n : int) (pt : int array) (cen : int array) (assign : int array) : unit =
  for i = 0 to n - 1 do
    let best = ref 0 and bd = ref (-1) in
    for k = 0 to kk - 1 do
      let dist = ref 0 in
      for d = 0 to dd - 1 do
        let df = pt.(i * dd + d) - cen.(k * dd + d) in
        dist := !dist + df * df
      done;
      if !bd < 0 || !dist < !bd then begin bd := !dist; best := k end
    done;
    assign.(i) <- !best
  done

let () =
  let n = if Array.length Sys.argv > 1 then int_of_string Sys.argv.(1) else 8000 in
  let pt = Array.make (n * dd) 0 in
  let s = ref 42 in
  for i = 0 to n * dd - 1 do
    s := lcg !s;
    pt.(i) <- !s mod range
  done;
  let cen = Array.make (kk * dd) 0 in
  for i = 0 to kk * dd - 1 do cen.(i) <- pt.(i) done;
  let assign = Array.make n 0 in
  let ssum = Array.make (kk * dd) 0 and cnt = Array.make kk 0 in
  for _ = 0 to iters - 1 do
    assign_all n pt cen assign;
    for i = 0 to kk * dd - 1 do ssum.(i) <- 0 done;
    for k = 0 to kk - 1 do cnt.(k) <- 0 done;
    for i = 0 to n - 1 do
      let k = assign.(i) in
      cnt.(k) <- cnt.(k) + 1;
      for d = 0 to dd - 1 do
        ssum.(k * dd + d) <- ssum.(k * dd + d) + pt.(i * dd + d)
      done
    done;
    for k = 0 to kk - 1 do
      if cnt.(k) > 0 then
        for d = 0 to dd - 1 do
          cen.(k * dd + d) <- ssum.(k * dd + d) / cnt.(k)
        done
    done
  done;
  assign_all n pt cen assign;
  let h = ref 0 in
  for i = 0 to kk * dd - 1 do h := (!h * 31 + cen.(i)) mod p done;
  for i = 0 to n - 1 do h := (!h * 31 + assign.(i)) mod p done;
  Printf.printf "%d\nk-means(%d)\n" !h n
