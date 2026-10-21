let p = 1000000007
(* INF is max_int: 1 lsl 62 is min_int in OCaml. INF is only compared, never added to. *)
let inf = max_int
let deg = 8
let maxw = 100
let base = 2097152

let[@inline] lcg (s : int) : int = (s * 1103515245 + 12345) land 0x7fffffff

(* binary min-heap of packed int keys (all keys distinct) *)
let hpush (heap : int array) (hsize : int ref) (k : int) : unit =
  let i = ref !hsize in
  incr hsize;
  heap.(!i) <- k;
  let go = ref true in
  while !go && !i > 0 do
    let par = (!i - 1) / 2 in
    if heap.(par) <= heap.(!i) then go := false
    else begin
      let t = heap.(par) in
      heap.(par) <- heap.(!i);
      heap.(!i) <- t;
      i := par
    end
  done

let hpop (heap : int array) (hsize : int ref) : int =
  let top = heap.(0) in
  decr hsize;
  heap.(0) <- heap.(!hsize);
  let i = ref 0 in
  let go = ref true in
  while !go do
    let l = 2 * !i + 1 and r = 2 * !i + 2 in
    let m = ref !i in
    if l < !hsize && heap.(l) < heap.(!m) then m := l;
    if r < !hsize && heap.(r) < heap.(!m) then m := r;
    if !m = !i then go := false
    else begin
      let t = heap.(!m) in
      heap.(!m) <- heap.(!i);
      heap.(!i) <- t;
      i := !m
    end
  done;
  top

let () =
  let n = if Array.length Sys.argv > 1 then int_of_string Sys.argv.(1) else 10000 in
  let m = deg * n in
  let eu = Array.make m 0 and ev = Array.make m 0 and ew = Array.make m 0 in
  let s = ref 42 in
  for e = 0 to m - 1 do
    s := lcg !s; eu.(e) <- !s mod n;
    s := lcg !s; ev.(e) <- !s mod n;
    s := lcg !s; ew.(e) <- !s mod maxw + 1
  done;
  let start = Array.make (n + 1) 0 in
  for e = 0 to m - 1 do start.(eu.(e) + 1) <- start.(eu.(e) + 1) + 1 done;
  for i = 0 to n - 1 do start.(i + 1) <- start.(i + 1) + start.(i) done;
  let cnt = Array.make n 0 in
  let adj_v = Array.make m 0 and adj_w = Array.make m 0 in
  for e = 0 to m - 1 do
    let u = eu.(e) in
    let pos = start.(u) + cnt.(u) in
    cnt.(u) <- cnt.(u) + 1;
    adj_v.(pos) <- ev.(e);
    adj_w.(pos) <- ew.(e)
  done;
  let dist = Array.make n inf in
  dist.(0) <- 0;
  let heap = Array.make (m + 1) 0 in
  let hsize = ref 0 in
  hpush heap hsize 0;
  while !hsize > 0 do
    let key = hpop heap hsize in
    let d = key / base and u = key mod base in
    if d <= dist.(u) then
      for e = start.(u) to start.(u + 1) - 1 do
        let v = adj_v.(e) in
        let nd = d + adj_w.(e) in
        if nd < dist.(v) then begin
          dist.(v) <- nd;
          hpush heap hsize (nd * base + v)
        end
      done
  done;
  let h = ref 0 in
  for i = 0 to n - 1 do
    let di = if dist.(i) < inf then dist.(i) else 0 in
    h := (!h * 31 + di mod p) mod p
  done;
  Printf.printf "%d\ndijkstra(%d)\n" !h n
