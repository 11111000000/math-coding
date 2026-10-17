(* lib/render/render_lang.ml — page language and template substitution.

   Split from lib/render/render.ml during the render-module-split
   refactor. Defines the `lang` variant, the `templates` record
   (indexed by lang), and the fixed-string `substitute` primitive
   used by `render_index`. *)

(* Language of a rendered page. A variant, not a string, per
   OCAML_BEST_PRACTICES.md §2.1. Declared before the navigation and
   page renderers that match on it. *)
type lang = En | Ru | Zh

(* Page templates read from files by the dispatcher. *)
type templates = {
  index : (lang * string) list;
  dashboard : string;
  graph : string;
}

(* Replace every `{{key}}` occurrence with its value. Fixed-string
   substitution, NOT a template engine. *)
let[@warning "-32"] substitute (vars : (string * string) list) s =
  List.fold_left
    (fun acc (key, value) ->
      Str.global_replace (Str.regexp_string ("{{" ^ key ^ "}}")) value acc)
    s vars

(* Canonical two-letter code for a language (`en` / `ru` / `zh`). *)
let[@warning "-32"] lang_code = function En -> "en" | Ru -> "ru" | Zh -> "zh"

(* Parse a CLI `--lang` code back into the variant. `None` on an
   unknown code; the dispatcher falls back to English. *)
let[@warning "-32"] lang_of_code = function
  | "en" -> Some En
  | "ru" -> Some Ru
  | "zh" -> Some Zh
  | _ -> None

(* File-name suffix for a language: `""` for En, `.ru`/`.zh` else. *)
let[@warning "-32"] lang_suffix = function En -> "" | Ru -> ".ru" | Zh -> ".zh"
