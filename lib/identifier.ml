open Stdlib

let parse_timestamp s =
  let len = String.length s in
  if len <> 20 then None
  else
    let is_digit c = c >= '0' && c <= '9' in
    let ok_digit i = is_digit (String.unsafe_get s i) in
    let check cond = if cond then Some s else None in
    check
      (ok_digit 0 && ok_digit 1 && ok_digit 2 && ok_digit 3
       && String.unsafe_get s 4 = '-'
       && ok_digit 5 && ok_digit 6
       && String.unsafe_get s 7 = '-'
       && ok_digit 8 && ok_digit 9
       && String.unsafe_get s 10 = 'T'
       && ok_digit 11 && ok_digit 12
       && String.unsafe_get s 13 = ':'
       && ok_digit 14 && ok_digit 15
       && String.unsafe_get s 16 = ':'
       && ok_digit 17 && ok_digit 18
       && String.unsafe_get s 19 = 'Z')

let parse_id s =
  let len = String.length s in
  if len = 0 || len > 128 then None
  else
    let first = String.unsafe_get s 0 in
    let good_first c =
      (c >= 'a' && c <= 'z')
      || (c >= '0' && c <= '9')
    in
    let good_rest c =
      good_first c
      || c = '.'
      || c = '_'
      || c = '-'
    in
    let rec loop i ok =
      if i >= len then
        if ok then Some s else None
      else
        let c = String.unsafe_get s i in
        let ok' = if i = 0 then good_first c else good_rest c in
        loop (i + 1) (ok && ok')
    in
    if good_first first then loop 1 true else None

let parse_digest s =
  let prefix = "sha256:" in
  let p_len = String.length prefix in
  let s_len = String.length s in
  if s_len <> p_len + 64 then None
  else
    let rec loop i ok =
      if i = p_len then if ok then Some s else None
      else if String.unsafe_get s i <> String.unsafe_get prefix i then None
      else loop (i + 1) ok
    in
    if String.sub s 0 p_len <> prefix then None
    else
      let hex_ok c =
        (c >= '0' && c <= '9')
        || (c >= 'a' && c <= 'f')
        || (c >= 'A' && c <= 'F')
      in
      let rec scan i ok =
        if i >= s_len then if ok then Some s else None
        else
          let c = String.unsafe_get s i in
          scan (i + 1) (ok && hex_ok c)
      in
      loop 0 true |> function
      | None -> None
      | Some _ -> scan p_len true
