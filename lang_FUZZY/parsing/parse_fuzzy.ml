(* Yoann Padioleau
 *
 * Copyright (C) 2019 r2c
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License
 * version 2.1 as published by the Free Software Foundation, with the
 * special exception on linking described in file license.txt.
 * 
 * This library is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the file
 * license.txt for more details.
 *)
open Common

(*****************************************************************************)
(* Prelude *)
(*****************************************************************************)
(* Wrappers around many languages to transform them in a fuzzy AST
 * (see ast_fuzzy.ml)
 *)

(*****************************************************************************)
(* Entry point *)
(*****************************************************************************)

(* This is similar to what I did for OPA. This is also similar
 * to what I do for parsing hacks for C++, but this fuzzy AST can be useful
 * on its own, e.g. for a not too bad sgrep/spatch.
 *)

let parse_with_lang lang file =
  match lang with
  | Lang_fuzzy.PHP ->
     let toks = Parse_php.tokens file in
     Lib_ast_fuzzy.mk_trees { Lib_ast_fuzzy.
       tokf = Token_helpers_php.info_of_tok;
       kind = Token_helpers_php.token_kind_of_tok;
     } toks 
  | Lang_fuzzy.ML ->
    let toks = Parse_ml.tokens file in
    Lib_ast_fuzzy.mk_trees { Lib_ast_fuzzy.
     tokf = Token_helpers_ml.info_of_tok;
     kind = Token_helpers_ml.token_kind_of_tok;
    } toks 
  | Lang_fuzzy.Skip ->
    let toks = Parse_skip.tokens file in
    Lib_ast_fuzzy.mk_trees { Lib_ast_fuzzy.
     tokf = Token_helpers_skip.info_of_tok;
     kind = Token_helpers_skip.token_kind_of_tok;
    } toks 
  | Lang_fuzzy.Java ->
    let toks = Parse_java.tokens file in
    Lib_ast_fuzzy.mk_trees { Lib_ast_fuzzy.
     tokf = Token_helpers_java.info_of_tok;
     kind = Token_helpers_java.token_kind_of_tok;
    } toks
  | Lang_fuzzy.Javascript ->
    let toks = Parse_js.tokens file in
    Lib_ast_fuzzy.mk_trees { Lib_ast_fuzzy.
     tokf = Token_helpers_js.info_of_tok;
     kind = Token_helpers_js.token_kind_of_tok;
    } toks 
  | Lang_fuzzy.Cpp ->
    Common.save_excursion Flag_parsing.verbose_lexing false (fun () ->
      Parse_cpp.parse_fuzzy file |> fst
    )

let parse file =
  match Lang_fuzzy.lang_of_filename_opt file with
  | Some lang -> parse_with_lang lang file
  | None -> failwith (spf "unsupported file for fuzzy AST: %s" file)
