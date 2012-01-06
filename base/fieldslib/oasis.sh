#!/bin/bash
set -e -u -o pipefail

source ../../build-common.sh

cat >$HERE/_oasis <<EOF
#AUTOGENERATED FILE; EDIT oasis.sh INSTEAD
OASISFormat:  0.2
OCamlVersion: >= 3.12
Name:         fieldslib
Version:      107.01
Synopsis:     OCaml record fields as first class values.
Authors:      Jane street capital
Copyrights:   (C) 2009-2011 Jane Street Capital LLC
License:      LGPL-2.1 with OCaml linking exception
LicenseFile:  LICENSE
Plugins:      StdFiles (0.2),
              DevFiles (0.2),
              META (0.2)
XStdFilesREADME: false
XStdFilesAUTHORS: false
XStdFilesINSTALLFilename: INSTALL
BuildTools:   ocamlbuild

Library fieldslib
  Path:               lib
  FindlibName:        fieldslib
  #Pack:               true
  Modules:            Field
  XMETAType:          library

Library pa_fields_conv
  Path:               syntax
  Modules:            Pa_fields_conv
  FindlibParent:      fieldslib
  FindlibName:        syntax
  BuildDepends:       camlp4.lib,
                      camlp4.quotations,
                      type-conv (>= 2.0.1)
  CompiledObject:     byte
  XMETAType:          syntax
  XMETARequires:      camlp4,type-conv,fieldslib
  XMETADescription:   Syntax extension for Fieldslib

Document "fieldslib"
  Title:                API reference for fieldslib
  Type:                 ocamlbuild (0.2)
  BuildTools+:          ocamldoc
  XOCamlbuildPath:      lib
  XOCamlbuildLibraries: fieldslib
EOF

make_tags $HERE/_tags <<EOF
# remove this part when oasis supports Pack: true
$(tag_for_pack Fieldslib $HERE/lib/*.ml)

<syntax/pa_fields_conv.ml>: syntax_camlp4o
EOF

cd $HERE
oasis setup
enable_pack_in_setup_ml fieldslib

./configure "$@"

