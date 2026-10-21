(* 32 worker fibers (Effect.Deep, one domain) driven by a hand-rolled single-threaded scheduler.
   Each worker is created once; per lap it does: receive (one perform, suspends the fiber and hands
   its continuation to the scheduler), transform. One hop = one perform + one continue. *)
open Effect
open Effect.Deep

let ring_width = 32
let seed = 12345
let md = 1000000007

type _ Effect.t += Recv : unit Effect.t

let token = ref 0

let conts : (unit, unit) continuation option array = Array.make ring_width None

let worker (id : int) (laps : int) () : unit =
  for _ = 1 to laps do
    perform Recv;
    token := (!token * 1103515245 + (id + 1)) land 0xFFFFFFFF
  done

let handler (id : int) : (unit, unit) Effect.Deep.handler =
  { retc = (fun () -> ());
    exnc = (fun e -> raise e);
    effc = (fun (type a) (eff : a Effect.t) ->
      match eff with
      | Recv -> Some (fun (k : (a, unit) continuation) -> conts.(id) <- Some k)
      | _ -> None) }

let () =
  let n = if Array.length Sys.argv > 1 then int_of_string Sys.argv.(1) else 500 in
  (* spawn once: run each worker to its first receive *)
  for id = 0 to ring_width - 1 do
    match_with (worker id n) () (handler id)
  done;
  token := seed;
  for _ = 1 to n do
    for id = 0 to ring_width - 1 do
      match conts.(id) with
      | Some k -> continue k ()
      | None -> ()
    done
  done;
  Printf.printf "%d\n%d\n" (!token mod md) (n * ring_width)
