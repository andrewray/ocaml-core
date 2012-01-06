#!/bin/bash
set -e -u -o pipefail

source ../../build-common.sh
check_linux_enabled "$@"
check_posix_timers_enabled "$@"

use_librt=
if ld -lrt -shared -o /dev/null 2>/dev/null; then
    use_librt=-lrt
fi

function list_mods {
    for mod in $(find "$HERE/lib" -name "*.ml" -print | mod_names); do
        case "$mod" in
            Linux_ext|Bigstring_marshal)
                if [[ "$enable_linux" == "true" ]]; then echo "$mod"; fi;;
            *) echo "$mod";;
        esac
    done
}

function list_stubs {
    for stub in $(find "$HERE/lib" -name "*.[ch]" -exec basename \{\} \;); do
        case "${stub%%.[ch]}" in
            linux_ext_stubs|bigstring_marshal_stubs)
                if [[ "$enable_linux" == "true" ]]; then echo "$stub"; fi;;
            *) echo "$stub";;
        esac
    done
}

MODULES="$(list_mods | sort -u | my_join)"
CSOURCES="config.h,$(list_stubs | sort -u | my_join)"
CCLIB="$use_librt"

cat >$HERE/_oasis<<EOF
#AUTOGENERATED FILE; EDIT oasis.sh INSTEAD

OASISFormat:  0.2
OCamlVersion: >= 3.12
Name:         core
Version:      107.01
Synopsis:     Jane Street Capital's standard library overlay
Authors:      Jane street capital
Copyrights:   (C) 2008-2010 Jane Street Capital LLC
License:      LGPL-2.1 with OCaml linking exception
LicenseFile:  LICENSE
Plugins:      StdFiles (0.2),
              DevFiles (0.2),
              META (0.2)
BuildTools:   ocamlbuild
Description:  Jane Street Capital's standard library overlay
FindlibVersion: >= 1.2.7
XStdFilesAUTHORS: false
XStdFilesINSTALLFilename: INSTALL
XStdFilesREADME: false


Flag linux
  Description: Enable linux specific extensions
  Default\$:   $enable_linux

Flag "posix-timers"
  Description: Enable POSIX timers
  Default\$:   $enable_timers

PostConfCommand: lib/discover.sh lib/config.mlh lib/config.h $(
  if [[ "$enable_linux"  == "true" ]]; then echo -n " -DLINUX_EXT"; fi
  if [[ "$enable_timers" == "true" ]]; then echo -n " -DPOSIX_TIMERS"; fi
  echo
)

PreBuildCommand:     mkdir -p _build/; cp lib/*.mlh _build/
PreDistCleanCommand: \$rm "lib/config.mlh" "lib/config.h"

Library core
  Path:               lib
  FindlibName:        core
  #Pack:               true
  Modules:${MODULES}
  CCOpt:              $(getconf LFS64_CFLAGS)
  CSources:           ${CSOURCES}
  CCLib:              ${CCLIB}
  BuildDepends:       variantslib,
                      variantslib.syntax,
                      sexplib.syntax,
                      sexplib,
                      fieldslib.syntax,
                      fieldslib,
                      bin_prot,
                      bin_prot.syntax,
                      bigarray,
                      pa_ounit,
                      pa_pipebang,
                      res,
                      unix,
                      threads

Flag tests
  Description:        Build and run tests
  Default:            false

Executable test_runner
  Path:               lib_test
  MainIs:             test_runner.ml
  Build$:             flag(tests)
  Custom:             true
#  CompiledObject:     best
  Install:            false
  BuildDepends:       core,oUnit (>= 1.0.2)

Test test_runner
  Run\$:               flag(tests)
  Command:            \$test_runner
  WorkingDirectory:   lib_test

Document "core"
  Title:                Jane street's core library
  Type:                 ocamlbuild (0.2)
  BuildTools+:          ocamldoc
  XOCamlbuildPath:      lib
  XOCamlbuildLibraries: core

EOF

make_tags "$HERE/_tags" <<EOF
# remove this part when oasis supports Pack: true
$(tag_for_pack Core $HERE/lib/*.ml)

<lib{,_test}/*.ml{,i}>: syntax_camlp4o
<lib/{std,core_int63,bigstring,core_mutex,core_unix,bigstring_marshal,linux_ext}.ml{,i}>:pkg_camlp4.macro
EOF

cd $HERE
oasis setup
enable_pack_in_setup_ml core

./configure "$enable_linux_default" "$enable_timers_default" "$@"
