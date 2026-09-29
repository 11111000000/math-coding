(* Self-contained SHA-256 implementation. RFC 6234. *)

let k =
  [|
    0x428a2f98;
    0x71374491;
    0xb5c0fbcf;
    0xe9b5dba5;
    0x3956c25b;
    0x59f111f1;
    0x923f82a4;
    0xab1c5ed5;
    0xd807aa98;
    0x12835b01;
    0x243185be;
    0x550c7dc3;
    0x72be5d74;
    0x80deb1fe;
    0x9bdc06a7;
    0xc19bf174;
    0xe49b69c1;
    0xefbe4786;
    0x0fc19dc6;
    0x240ca1cc;
    0x2de92c6f;
    0x4a7484aa;
    0x5cb0a9dc;
    0x76f988da;
    0x983e5152;
    0xa831c66d;
    0xb00327c8;
    0xbf597fc7;
    0xc6e00bf3;
    0xd5a79147;
    0x06ca6351;
    0x14292967;
    0x27b70a85;
    0x2e1b2138;
    0x4d2c6dfc;
    0x53380d13;
    0x650a7354;
    0x766a0abb;
    0x81c2c92e;
    0x92722c85;
    0xa2bfe8a1;
    0xa81a664b;
    0xc24b8b70;
    0xc76c51a3;
    0xd192e819;
    0xd6990624;
    0xf40e3585;
    0x106aa070;
    0x19a4c116;
    0x1e376c08;
    0x2748774c;
    0x34b0bcb5;
    0x391c0cb3;
    0x4ed8aa4a;
    0x5b9cca4f;
    0x682e6ff3;
    0x748f82ee;
    0x78a5636f;
    0x84c87814;
    0x8cc70208;
    0x90befffa;
    0xa4506ceb;
    0xbef9a3f7;
    0xc67178f2;
  |]

let rotr x n = (x lsr n) lor (x lsl (32 - n)) land 0xffffffff
let ch x y z = x land y lor (lnot x land z)
let maj x y z = x land y lor (x land z) lor (y land z)
let bsig0 x = rotr x 2 lxor rotr x 13 lxor rotr x 22
let bsig1 x = rotr x 6 lxor rotr x 11 lxor rotr x 25
let ssig0 x = rotr x 7 lxor rotr x 18 lxor (x lsr 3)
let ssig1 x = rotr x 17 lxor rotr x 19 lxor (x lsr 10)

let pad s =
  let len = String.length s in
  let bit_len = Int64.mul (Int64.of_int len) 8L in
  let buf = Buffer.create (len + 128) in
  Buffer.add_string buf s;
  Buffer.add_char buf (Char.chr 0x80);
  let target = (len + 9 + 63) / 64 * 64 in
  let pad_len = target - len - 9 in
  for _ = 1 to pad_len do
    Buffer.add_char buf (Char.chr 0)
  done;
  let[@warning "-32"] byte_at_shift n =
    let shifted = Int64.shift_right_logical bit_len n in
    let masked = Int64.logand shifted 0xffL in
    Int64.to_int masked
  in
  for i = 0 to 7 do
    let shift = (7 - i) * 8 in
    let byte = byte_at_shift shift in
    Buffer.add_char buf (Char.chr byte)
  done;
  Buffer.contents buf

let[@warning "-32"] words_of s =
  let[@warning "-32"] rec loop i acc =
    if i + 4 > String.length s then List.rev acc
    else
      let b0 = Char.code (String.unsafe_get s i) in
      let b1 = Char.code (String.unsafe_get s (i + 1)) in
      let b2 = Char.code (String.unsafe_get s (i + 2)) in
      let b3 = Char.code (String.unsafe_get s (i + 3)) in
      loop (i + 4) (((b0 lsl 24) lor (b1 lsl 16) lor (b2 lsl 8) lor b3) :: acc)
  in
  loop 0 []

let[@warning "-32"] words_to_ints ws =
  let[@warning "-32"] rec loop i acc = function
    | [] -> List.rev acc
    | w :: rest ->
        if i >= 64 then List.rev acc else loop (i + 1) (w :: acc) rest
  in
  loop 0 [] ws

let digest_string s =
  let padded = pad s in
  let h = Array.make 8 0 in
  h.(0) <- 0x6a09e667;
  h.(1) <- 0xbb67ae85;
  h.(2) <- 0x3c6ef372;
  h.(3) <- 0xa54ff53a;
  h.(4) <- 0x510e527f;
  h.(5) <- 0x9b05688c;
  h.(6) <- 0x1f83d9ab;
  h.(7) <- 0x5be0cd19;
  let blocks = String.length padded / 64 in
  let[@warning "-32"] block_words block =
    let ws = words_of block in
    let arr = Array.make 64 0 in
    List.iteri (fun i w -> if i < 64 then arr.(i) <- w) ws;
    for i = 16 to 63 do
      arr.(i) <-
        (ssig1 arr.(i - 2) + ssig0 arr.(i - 15) + arr.(i - 7) + arr.(i - 16))
        land 0xffffffff
    done;
    arr
  in
  for bi = 0 to blocks - 1 do
    let block = String.sub padded (bi * 64) 64 in
    let w = block_words block in
    let[@warning "-32"] step_round i a b c d e f g h =
      let t1 = (h + bsig1 e + ch e f g + k.(i) + w.(i)) land 0xffffffff in
      let t2 = (bsig0 a + maj a b c) land 0xffffffff in
      ((t1 + t2) land 0xffffffff, (d + t1) land 0xffffffff)
    in
    let[@warning "-32"] rec loop i a b c d e f g h =
      if i > 63 then (a, b, c, d, e, f, g, h)
      else
        let a', e' = step_round i a b c d e f g h in
        loop (i + 1) a' a b c e' e f g
    in
    let a', b', c', d', e', f', g', h' =
      loop 0 h.(0) h.(1) h.(2) h.(3) h.(4) h.(5) h.(6) h.(7)
    in
    h.(0) <- (h.(0) + a') land 0xffffffff;
    h.(1) <- (h.(1) + b') land 0xffffffff;
    h.(2) <- (h.(2) + c') land 0xffffffff;
    h.(3) <- (h.(3) + d') land 0xffffffff;
    h.(4) <- (h.(4) + e') land 0xffffffff;
    h.(5) <- (h.(5) + f') land 0xffffffff;
    h.(6) <- (h.(6) + g') land 0xffffffff;
    h.(7) <- (h.(7) + h') land 0xffffffff
  done;
  let hex n = Printf.sprintf "%08x" n in
  String.concat "" (List.map hex (Array.to_list h))

let sha256_hex = digest_string
let sha256_text s = digest_string s
