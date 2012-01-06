#!/bin/bash
set -e -u -o pipefail

source ../../../build-common.sh

function list_mods {
    find "$HERE/lib" -name "*.ml" -print | mod_names
}

MODULES="$(list_mods | sort -u | my_join)"

cat >$HERE/_oasis <<EOF
#AUTOGENERATED FILE; EDIT oasis.sh INSTEAD

OASISFormat:  0.2
OCamlVersion: >= 3.12
Name:         async_core
Version:      107.01
Synopsis:     Jane Street Capital's asynchronous execution library (core)
Authors:      Jane street capital
Copyrights:   (C) 2008-2011 Jane Street Capital LLC
License:      LGPL-2.1 with OCaml linking exception
LicenseFile:  LICENSE
Plugins:      StdFiles (0.2),
              DevFiles (0.2),
              META (0.2)
BuildTools:   ocamlbuild
Description:  Jane Street Capital's asynchronous execution library
FindlibVersion: >= 1.2.7
XStdFilesAUTHORS: false
XStdFilesINSTALLFilename: INSTALL
XStdFilesREADME: false


Library async_core
  Path:               lib
  FindlibName:        async_core
  Pack:               true
  Modules:            ${MODULES}
  BuildDepends:       sexplib.syntax,
                      sexplib,
                      fieldslib.syntax,
                      fieldslib,
                      bin_prot,
                      bin_prot.syntax,
                      core,
                      threads

EOF

make_tags "$HERE/_tags" <<EOF
# remove this part when oasis supports Pack: true
$(tag_for_pack Async_core $HERE/lib/*.ml)

<lib/*.ml{,i}>: syntax_camlp4o
EOF

cd $HERE
oasis setup
enable_pack_in_setup_ml async_core

./configure "$@"

