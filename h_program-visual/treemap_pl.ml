(* Yoann Padioleau
 *
 * Copyright (C) 2010 Facebook
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

open File_type
module PL = File_type
module Color = Simple_color

(*****************************************************************************)
(* Prelude *)
(*****************************************************************************)
(*
 * Treemap for code understanding. This is especially useful on badly
 * organized projects. For instance if one directory has hundreds of
 * subdirectories, it's hard to see what is important. With a treemap
 * you will automatically see the biggest subdirectories and see
 * visually how things should have been organized in the first place.
 * 
 *
 * Should we put some of this code in in archi_code.ml?
 * Hmmm no because we dont want h_program-lang/ to be dependent of
 * visualisation. Hence this h_program-visual/ directory!
 * 
 * TODO factorize code of info_of_file_default and other hooks ?
 *)

(*****************************************************************************)
(* Helpers *)
(*****************************************************************************)

(* Note that the treemap is supposed to contain absolute paths
 * so when we recompute the treemap of a subdir we should have
 * similar full pathnames and so we should hit the cache.
 *)

let _hmemo_file_archi = Hashtbl.create 101
let source_archi_of_filename ~root file = 
  Common.profile_code "Treemap_pl.file_archi" (fun () ->
    Common.memoized _hmemo_file_archi file (fun () ->
      Archi_code_parse.source_archi_of_filename ~root file
  ))

let _hmemo_file_type = Hashtbl.create 101
let file_type_of_file file =
  Common.profile_code "Treemap_pl.file_type" (fun () ->
    Common.memoized _hmemo_file_type file (fun () ->
      File_type.file_type_of_file file
  ))


(*****************************************************************************)
(* Colors *)
(*****************************************************************************)

let color_of_source_archi kind = 
  match kind with
  | Archi_code.Init -> "IndianRed"

  | Archi_code.Test -> "yellow"

  | Archi_code.Doc -> "orchid"

  | Archi_code.Interface -> "tan"

  | Archi_code.Core  
  | Archi_code.Utils
      -> "SpringGreen"

  | Archi_code.Constants ->
      "green"
  | Archi_code.GetSet ->
      "green"

  | Archi_code.Logging ->
      "gold"


  | Archi_code.Storage ->
      "SteelBlue"

  | Archi_code.Ui
    -> "RosyBrown"

  | Archi_code.Unittester
  | Archi_code.Profiler
    -> "LightSalmon"

  | Archi_code.Intern
      -> "chartreuse"


  (* not very good light color, but dont care about thirdparty or legacy *)
  | Archi_code.ThirdParty ->
      "SlateBlue" 
  | Archi_code.Legacy ->
      "DarkOrchid"

  | Archi_code.Data ->
      "DarkOrchid"


  | Archi_code.AutoGenerated ->
      "DarkOrchid"
  | Archi_code.BoilerPlate ->
      "DarkOrchid"

  | Archi_code.I18n ->
      "DarkOrchid"

  | Archi_code.Script  ->
      "chartreuse" 
  | Archi_code.Ffi ->
      "DarkOrchid"

  | Archi_code.Configuration ->
      "chartreuse"
  | Archi_code.Main 
      -> "IndianRed"

  | Archi_code.Building  ->
      "LightGoldenrod"

  | Archi_code.Security
      -> "turquoise"

  | Archi_code.Architecture
      -> "CadetBlue"
  | Archi_code.OS
      -> "PaleTurquoise"
  | Archi_code.Network
      -> "OliveDrab"

  | Archi_code.Parsing
      -> "LightSkyBlue"

  | Archi_code.MiniLite
      -> "orange"

  | Archi_code.Regular 
      -> "wheat"

let color_of_webpl_type kind = 
  match kind with
  | PL.Php _ -> "IndianRed"


  | PL.Css -> "yellow"
  | PL.Js | PL.Coffee | PL.TypeScript -> "SpringGreen"
  | PL.Html | PL.Xml | PL.Json -> "sienna"

(*  | PL.Pic _ -> "RosyBrown" *)
  | PL.Sql -> "SteelBlue"



(*****************************************************************************)
(* Anamorphic rectangles *)
(*****************************************************************************)

let anamorphic_diviser_of_file ~root file =

  (* both should be memoized *)
  let ftype = file_type_of_file file in
  let archi = source_archi_of_filename ~root file in

  match ftype with
  | Doc _ -> 100.
  | Obj _ -> 500.

  | PL (Web Html) -> 85.

  | PL (Web Json) -> 40.

  | PL (Web Xml) -> 70.

  | PL (Web Sql) -> 200.

  | PL (MiscPL "m4") -> 10.

  | Archive _ -> 200.

  | Text "doc" -> 40.
  | Text "nw" when archi <> Archi_code.Data -> 3.
  | Binary _ -> 1000.
   
  (* C code is at lease 3x times more verbose than ml :) 
  | PL (C | Cplusplus | Java) -> 5.
  *)

  | Media (Picture _) -> 200.
  | Media (Sound _) -> 100.

  | Other _ -> 10.

  | _ -> 
      (match archi with
      | Archi_code.ThirdParty -> 5. 
      | Archi_code.Legacy -> 8. 

      | Archi_code.AutoGenerated -> 15.
      | Archi_code.BoilerPlate -> 15.
      | Archi_code.I18n -> 8.

      | Archi_code.Data -> 30.

      (* augment size of main 
       * TODO: should be adaptative
       *)
      | Archi_code.Main | Archi_code.Init -> 0.5

      | _ -> 1.
      )

(*****************************************************************************)
(* Treemap *)
(*****************************************************************************)

let treemap_file_size_hook2 ~root file =

  (* todo: should be passed to the hook!! *)
  let filesize = 
    try (Common2.unix_stat_eff file).Unix.st_size
    with Unix.Unix_error _ ->
      pr2 (spf "PB stating %s" file);
      0
  in

  (* anamorphic map :) *)
  let diviser_file = 
    (* todo: use h_e and h_base *)
    anamorphic_diviser_of_file ~root file
  in

  let diviser_dir = 
    (* todo: use dir_regexps_and_score *)
    1.0
  in
  
  let diviser_final = diviser_file *. diviser_dir in

  (* zero file size produce weird results *)
  let size = 
    max (float_of_int filesize /. diviser_final) 1.0
  in
  int_of_float size

(* not sure this is needed anymore *)
let _hmemo_file_size = Hashtbl.create 101
let treemap_file_size_hook ~root file = 
  Common.profile_code "Treemap_pl.file_size_hook" (fun () ->
    Common.memoized _hmemo_file_size file (fun () ->
      treemap_file_size_hook2 ~root file
  ))

    

let code_treemap2 ~filter_file paths =
  let root = Common2.common_prefix_of_files_or_dirs paths in
  let tree = 
    paths +> Treemap.tree_of_dirs_or_files
      ~filter_dir:Lib_vcs.filter_vcs_dir
      ~filter_file:filter_file
      ~file_hook:(fun file -> treemap_file_size_hook ~root file)
  in

  let tree = Treemap.remove_singleton_subdirs tree in

  tree +> Treemap.treemap_of_tree
    ~size_of_leaf:(fun (_f, intleaf) -> intleaf) 
    ~color_of_leaf:(fun (f, _intleaf) -> 
      let kind = source_archi_of_filename ~root f in
      let color = color_of_source_archi kind in

      (* I prefer dark background so start at 3 
       * old: let i = Random.int 4 + 1 in
       *)
      let i = Random.int 2 + 3 in
      let d = (Color.mk_degrade i) in
      (* assert(List.mem d [Color.Degrade1; Color.Degrade2]); *)
      Color.degrade color d
    )
    ~label_of_dir:(fun d -> d)
    ~label_of_file:(fun (f, _intleaf (*, aref *)) -> f)

let code_treemap ~filter_file a = 
  Common.profile_code "Treemap_pl.code_treemap" (fun () ->
    code_treemap2 ~filter_file a)
