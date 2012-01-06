#!/bin/bash
set -e -u -o pipefail

source ../../../build-common.sh
check_linux_enabled "$@"
check_posix_timers_enabled "$@"

function list_mods {
    for mod in $(find "$HERE/lib" -name "*.ml" -print | mod_names); do
        case "$mod" in
            Malloc|Extended_linux)
                if [[ "$enable_linux" == "true" ]]; then echo "$mod"; fi;;
            Bench|Posix_clock)
                if [[ "$enable_timers" == "true" ]]; then echo "$mod"; fi;;
            *) echo "$mod";;
        esac
    done
}

function list_stubs {
    for stub in $(find "$HERE/lib" -name "*.[ch]" -exec basename \{\} \;); do
        case "${stub%%.[ch]}" in
            malloc_stubs|extended_linux_stubs)
                if [[ "$enable_linux" == "true" ]]; then echo "$stub"; fi;;
            posix_clock_stubs)
                if [[ "$enable_timers" == "true" ]]; then echo "$stub"; fi;;
            *) echo "$stub";;
        esac
    done
}

MODULES="$(list_mods | sort -u | my_join)"
CSOURCES="fork_exec.h,$(list_stubs | sort -u | my_join)"

cat >$HERE/_oasis <<EOF
#AUTOGENERATED FILE; EDIT oasis.sh INSTEAD

OASISFormat:  0.2
OCamlVersion: >= 3.12
Name:         core_extended
Version:      107.01
Synopsis:     Jane Street Capital's standard library overlay
Authors:      Jane street capital
Copyrights:   (C) 2008-2011 Jane Street Capital LLC
License:      LGPL-2.1 with OCaml linking exception
LicenseFile:  LICENSE
Plugins:      StdFiles (0.2),
              DevFiles (0.2),
              META (0.2)
BuildTools:   ocamlbuild
Description:  Jane Street Capital's standard library overlay
FindlibVersion : >= 1.2.7
XStdFilesAUTHORS: false
XStdFilesINSTALLFilename: INSTALL
XStdFilesREADME: false

Flag linux
  Description: Enable linux specific extensions
  Default\$:   $enable_linux

Flag "posix-timers"
  Description: Enable POSIX timers
  Default\$:   $enable_timers

PreBuildCommand: mkdir -p _build/lib; cp lib/*.mlh _build/; cp ../lib/*.h _build/lib/
PreDistCleanCommand: \$rm lib/version_defaults.mlh lib/config.mlh

Library core_extended
  Path:               lib
  FindlibName:        core_extended
  #Pack:               true
  Modules:            ${MODULES}
  CSources:           ${CSOURCES}
  CCOpt+:             -Ilib

  BuildDepends:       sexplib.syntax,
                      sexplib,
                      fieldslib.syntax,
                      fieldslib,
                      bin_prot,
                      bin_prot.syntax,
                      pa_ounit,
                      pa_pipebang,
                      core,
                      bigarray,
                      pcre,
                      res,
                      unix,
                      threads

Flag tests
  Description:        Build and run tests
  Default:            false

Executable core_extended_hello
  Path:               lib_test
  MainIs:             core_extended_hello.ml
  Build\$:            flag(tests)
  Custom:             true
  CompiledObject:     best
  Install:            false
  BuildDepends:       core_extended

Executable core_hello
  Path:               lib_test
  MainIs:             core_hello.ml
  Build\$:            flag(tests)
  Custom:             true
  CompiledObject:     best
  Install:            false
  BuildDepends:       core,threads

Executable test_runner
  Path:               lib_test
  MainIs:             test_runner.ml
  Build\$:            flag(tests)
  Custom:             true
  CompiledObject:     best
  Install:            false
  BuildDepends:       core_extended,oUnit (>= 1.1.0),threads

Test test_runner
  Run\$:              flag(tests)
  Command:            \$test_runner --core-hello \$core_hello --core-extended-hello \$core_extended_hello
  WorkingDirectory:   lib_test
  TestTools:          core_hello,core_extended_hello

Document "core-extended"
  Title:                Jane street's core extended library
  Type:                 ocamlbuild (0.2)
  BuildTools+:          ocamldoc
  XOCamlbuildPath:      lib
  XOCamlbuildLibraries: core_extended

EOF

make_tags "$HERE/_tags" <<EOF
# remove this part when oasis supports Pack: true
$(tag_for_pack Core_extended $HERE/lib/*.ml)

<lib/*.ml{,i}>: syntax_camlp4o
"lib/std.ml": pkg_camlp4.macro
"lib/command.ml": pkg_camlp4.macro
"lib/console.ml": pkg_camlp4.macro
"lib/core_command.ml": pkg_camlp4.macro
EOF

if [[ ! -e $HERE/lib/version_defaults.mlh ]]; then
    cat >$HERE/lib/version_defaults.mlh <<EOF
DEFINE DEFAULT_VERSION = "No version info."
DEFINE DEFAULT_BUILDINFO = "No build info."
EOF
fi

cat >$HERE/lib/config.mlh <<EOF
$(if [[ "$enable_linux"  == "true" ]]; then echo "DEFINE LINUX_EXT"; fi)
$(if [[ "$enable_timers" == "true" ]]; then echo "DEFINE POSIX_TIMERS"; fi)
EOF

cd $HERE
oasis setup
enable_pack_in_setup_ml core_extended

./configure "$enable_timers_default" "$enable_linux_default" "$@"
