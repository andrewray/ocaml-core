#!/usr/bin/env bash
set -e -u -o pipefail

source ../../build-common.sh

cat >$HERE/_oasis <<EOF
#AUTOGENERATED FILE; EDIT oasis.sh INSTEAD
OASISFormat:  0.3
OCamlVersion: >= 3.12
Name:         bin_prot
Version:      $core_version
Synopsis:     binary protocol generator
Authors:      Markus Mottl,
              Jane Street Holding LLC
Copyrights:   (C) 2008-2011 Jane Street Holding LLC
License:      LGPL-2.1 with OCaml linking exception
LicenseFile:  LICENSE
Plugins:      StdFiles (0.3), DevFiles (0.3), META (0.3)
BuildTools:   ocamlbuild, camlp4o
Description:  binary protocol generator
XStdFilesAUTHORS: false
XStdFilesINSTALLFilename: INSTALL
XStdFilesREADME: false

PreBuildCommand: mkdir -p _build; cp lib/*.mlh lib/*.h _build/

Library bin_prot
  Path:               lib
  Pack:               true
  Modules:            Binable,
                      Nat0,
                      Common,
                      Unsafe_common,
                      Unsafe_write_c,
                      Unsafe_read_c,
                      Size,
                      Write_ml,
                      Read_ml,
                      Write_c,
                      Read_c,
                      Std,
                      Type_class,
                      Map_to_safe,
                      Utils
  CSources:           common_stubs.c,
                      common_stubs.h,
                      int64_native.h,
                      int64_emul.h,
                      write_stubs.c,
                      read_stubs.c
  BuildDepends:       unix,bigarray

Library pa_bin_prot
  Path:               syntax
  FindlibName:        syntax
  FindlibParent:      bin_prot
  Modules:            Pa_bin_prot
  BuildDepends:       camlp4.quotations,camlp4.extend,type_conv (>= 3.0.5)
  CompiledObject:     byte
  XMETAType:          syntax
  XMETARequires:      type_conv,bin_prot
  XMETADescription:   Syntax extension for binary protocol generator

Executable test_runner
  Path:               lib_test
  MainIs:             test_runner.ml
  Build\$:            flag(tests)
  Install:            false
  CompiledObject:     best
  Custom:             true
  BuildDepends:       bin_prot,bin_prot.syntax,oUnit (>= 1.0.2)

Test test_runner
  Run\$:              flag(tests)
  Command:           \$test_runner
  WorkingDirectory:   lib_test

Executable mac_test
  Path:               lib_test
  MainIs:             mac_test.ml
  Build\$:            flag(tests)
  Install:            false
  Custom:             true
  CompiledObject:     best
  BuildDepends:       bin_prot,bin_prot.syntax

Test mac_test
  Run\$:              flag(tests)
  Command:           \$mac_test
  WorkingDirectory:   lib_test

Executable example
  Path:               lib_test
  MainIs:             example.ml
  Build\$:            flag(tests)
  Install:            false
  CompiledObject:     best
  BuildDepends:       bin_prot,bin_prot.syntax

Document "bin_prot"
  Title:                API reference for bin_prot
  Type:                 ocamlbuild (0.3)
  BuildTools+:          ocamldoc
  XOCamlbuildPath:      lib
  XOCamlbuildLibraries: bin_prot
EOF

make_tags $HERE/_tags <<EOF
<lib/{size,write_ml,read_ml,unsafe_read_c,type_class}.ml{i,}>: pp(cpp -undef -traditional -I.)
<lib/{write,read}_ml.ml{,i}>:mlh
<lib_test/*.ml{,i}>: syntax_camlp4o,pkg_type_conv.syntax
<syntax/pa_bin_prot.ml>: syntax_camlp4o
EOF

make_myocamlbuild "$HERE/myocamlbuild.ml" <<EOF
(* We probably will want to set this up in the \`configure\` script at some
   point. *)
let is_darwin =
  Ocamlbuild_pack.My_unix.run_and_open "uname -s" input_line = "Darwin"

let cpp =
  let base_cpp = "cpp -traditional -undef -w" in
  match Sys.word_size with
  | 64 -> S [A "-pp"; P (base_cpp ^ " -DARCH_SIXTYFOUR")]
  | 32 -> S [A "-pp"; P base_cpp]
  | _ -> assert false
;;

Ocamlbuild_plugin.dispatch
  begin
    function
      | After_rules as e ->
          setup_standard_build_flags ();

          dep ["ocaml"; "ocamldep"; "mlh"] ["lib/int_codes.mlh"];

          flag ["ocamldep"; "ocaml"; "use_pa_bin_prot"]
            (S [A "-ppopt"; P "syntax/pa_bin_prot.cma"]);

          flag ["compile"; "ocaml"; "use_pa_bin_prot"]
            (S [A "-ppopt"; P "syntax/pa_bin_prot.cma"]);

          flag ["ocamldep"; "ocaml"; "cpp"] cpp;

          flag ["compile"; "ocaml"; "cpp"] cpp;

          flag ["compile"; "ocaml"] (S [A "-w"; A "@Ae" ]);

          if is_darwin then
            flag ["compile"; "c"] (S [A "-ccopt"; A "-DOS_DARWIN"]);

          dispatch_default e
      | e -> dispatch_default e
  end
;;
EOF

cd $HERE
rm -f setup.ml
oasis setup
