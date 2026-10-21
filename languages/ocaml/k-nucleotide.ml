(* Stdlib generic Hashtbl keyed by the 8-mer string, default initial size, find_opt then replace. *)
let k = 8
let p = 1000000007

let gen (len : int) : string =
  let s = Bytes.create len in
  let seed = ref 42 in
  for i = 0 to len - 1 do
    seed := (!seed * 3877 + 29573) mod 139968;
    Bytes.set s i
      (if !seed < 42000 then 'A' else if !seed < 70000 then 'C'
       else if !seed < 98000 then 'G' else 'T')
  done;
  Bytes.to_string s

let () =
  let len = if Array.length Sys.argv > 1 then int_of_string Sys.argv.(1) else 100000 in
  let s = gen len in
  let tbl : (string, int) Hashtbl.t = Hashtbl.create 16 in
  for i = 0 to len - k do
    let key = String.sub s i k in
    match Hashtbl.find_opt tbl key with
    | Some c -> Hashtbl.replace tbl key (c + 1)
    | None -> Hashtbl.add tbl key 1
  done;
  let acc =
    Hashtbl.fold
      (fun (key : string) (cnt : int) (acc : int) ->
        let e = ref 0 in
        for j = 0 to k - 1 do
          let c = String.get key j in
          let code = if c = 'A' then 0 else if c = 'C' then 1 else if c = 'G' then 2 else 3 in
          e := !e * 4 + code
        done;
        (acc + !e * cnt) mod p)
      tbl 0
  in
  Printf.printf "%d\nk-nucleotide(%d)\n" acc len
