let index_of_sub_from needle text from =
  let limit = String.length text - String.length needle in
  let rec scan index =
    if index > limit then None
    else if String.sub text index (String.length needle) = needle then Some index
    else scan (index + 1)
  in
  if from > limit then None else scan from

let hrefs page =
  let marker = "href=\"" in
  let length = String.length page in
  let rec scan acc index =
    if index >= length then List.rev acc
    else
      match index_of_sub_from marker page index with
      | None -> List.rev acc
      | Some at ->
          let start = at + String.length marker in
          (match String.index_from_opt page start '"' with
          | None -> List.rev acc
          | Some stop ->
              scan (String.sub page start (stop - start) :: acc) (stop + 1))
  in
  scan [] 0

let local_target href =
  let href =
    match String.index_opt href '#' with
    | None -> href
    | Some at -> String.sub href 0 at
  in
  let href =
    match String.index_opt href '?' with
    | None -> href
    | Some at -> String.sub href 0 at
  in
  if href = "" then None
  else if String.length href > 7 && String.sub href 0 7 = "http://" then None
  else if String.length href > 8 && String.sub href 0 8 = "https://" then None
  else if String.length href > 7 && String.sub href 0 7 = "mailto:" then None
  else Some href
