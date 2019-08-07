#!/usr/bin/env bash

DOC="Usage: echo_ship_name.sh ship new <name>...
"
#"DOCOPT PARAMS"
#eval "$(docopt "$@")"
PATH=/home/sylvain/code/go/src/github.com/docopt/docopts/:$PATH
eval "$(docopts --docopt_sh -h "$DOC" : "$@")"

if $ship && $new; then
  echo $_name_
fi
