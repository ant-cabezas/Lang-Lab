(* Native OCaml objects: a call whose target is resolved at runtime from the object's class.
   Every object carries all three fields, as in C and C#. *)
let p = 1000000007
let nobj = 10000

class virtual base (a0 : int) (b0 : int) (c0 : int) =
  object
    val a : int = a0
    val b : int = b0
    val c : int = c0
    method virtual apply : int -> int
  end

class t0 a b c = object inherit base a b c method apply (x : int) = (x * 1000003 + a) mod p end
class t1 a b c = object inherit base a b c method apply (x : int) = (x * 998273 + b) mod p end
class t2 a b c = object inherit base a b c method apply (x : int) = (x * 999983 + c) mod p end
class t3 a b c = object inherit base a b c method apply (x : int) = (x * 997879 + a + b) mod p end
class t4 a b c = object inherit base a b c method apply (x : int) = (x * 996323 + b * c) mod p end
class t5 a b c = object inherit base a b c method apply (x : int) = (x * 995369 + a + c) mod p end

let[@inline] lcg (s : int) : int = (s * 1103515245 + 12345) land 0x7fffffff

(* construction-time only *)
let make_obj (t : int) (a : int) (b : int) (c : int) : base =
  match t with
  | 0 -> (new t0 a b c :> base)
  | 1 -> (new t1 a b c :> base)
  | 2 -> (new t2 a b c :> base)
  | 3 -> (new t3 a b c :> base)
  | 4 -> (new t4 a b c :> base)
  | _ -> (new t5 a b c :> base)

let () =
  let m = if Array.length Sys.argv > 1 then int_of_string Sys.argv.(1) else 50 in
  let objs : base array = Array.make nobj (make_obj 0 0 0 0) in
  let s = ref 42 in
  for i = 0 to nobj - 1 do
    s := lcg !s; let t = (!s lsr 16) mod 6 in
    s := lcg !s; let a = !s mod 1000 in
    s := lcg !s; let b = !s mod 1000 in
    s := lcg !s; let c = !s mod 1000 in
    objs.(i) <- make_obj t a b c
  done;
  let acc = ref 1 in
  for _ = 0 to m - 1 do
    for i = 0 to nobj - 1 do
      acc := objs.(i)#apply !acc
    done
  done;
  Printf.printf "%d\npolymorphism(%d)\n" !acc m
