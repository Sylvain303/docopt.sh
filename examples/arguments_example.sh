#!/usr/bin/env bash

DOC="Argument parser
Usage: arguments_example.sh [-vqrh] [FILE] ...
       arguments_example.sh (--left | --right) CORRECTION FILE

Process FILE and optionally apply correction to either left-hand side or
right-hand side.

Arguments:
  FILE        optional input file
  CORRECTION  correction angle, needs FILE, --left or --right to be present

Options:
  -h --help
  -v       verbose mode
  -q       quiet mode
  -r       make report
  --left   use left-hand side
  --right  use right-hand side"
# docopt parser below, refresh this parser with `docopt.sh arguments_example.sh`
# shellcheck disable=2016
docopt() {
  parse() {
    if ${DOCOPT_DOC_CHECK:-true}; then
      local doc_hash
      doc_hash=$(printf "%s" "$DOC" | shasum -a 256)
      if [[ ${doc_hash:0:5} != "$digest" ]]; then
        stderr "The current usage doc (${doc_hash:0:5}) does not match \
  what the parser was generated with (${digest})
  Run \`docopt.sh\` to refresh the parser."
        _return 70
      fi
    fi

    local root_idx=$1
    shift
    argv=("$@")
    parsed_params=()
    parsed_values=()
    left=()
    # testing depth counter, when >0 nodes only check for potential matches
    # when ==0 leafs will set the actual variable when a match is found
    testdepth=0

    local arg
    while [[ ${#argv[@]} -gt 0 ]]; do
      if [[ ${argv[0]} = "--" ]]; then
        for arg in "${argv[@]}"; do
          parsed_params+=('a')
          parsed_values+=("$arg")
        done
        break
      elif [[ ${argv[0]} = --* ]]; then
        parse_long
      elif [[ ${argv[0]} = -* && ${argv[0]} != "-" ]]; then
        parse_shorts
      elif ${DOCOPT_OPTIONS_FIRST:-false}; then
        for arg in "${argv[@]}"; do
          parsed_params+=('a')
          parsed_values+=("$arg")
        done
        break
      else
        parsed_params+=('a')
        parsed_values+=("${argv[0]}")
        argv=("${argv[@]:1}")
      fi
    done
    local idx
    if ${DOCOPT_ADD_HELP:-true}; then
      for idx in "${parsed_params[@]}"; do
        [[ $idx = 'a' ]] && continue
        if [[ ${shorts[$idx]} = "-h" || ${longs[$idx]} = "--help" ]]; then
          stdout "$trimmed_doc"
          _return 0
        fi
      done
    fi
    if [[ ${DOCOPT_PROGRAM_VERSION:-false} != 'false' ]]; then
      for idx in "${parsed_params[@]}"; do
        [[ $idx = 'a' ]] && continue
        if [[ ${longs[$idx]} = "--version" ]]; then
          stdout "$DOCOPT_PROGRAM_VERSION"
          _return 0
        fi
      done
    fi

    local i=0
    while [[ $i -lt ${#parsed_params[@]} ]]; do
      left+=("$i")
      ((i++)) || true
    done

    if ! required "$root_idx" || [ ${#left[@]} -gt 0 ]; then
      error
    fi
    return 0
  }

  parse_shorts() {
    local token=${argv[0]}
    local value
    argv=("${argv[@]:1}")
    [[ $token = -* && $token != --* ]] || _return 88
    local remaining=${token#-}
    while [[ -n $remaining ]]; do
      local short="-${remaining:0:1}"
      remaining="${remaining:1}"
      local i=0
      local similar=()
      local match=false
      for o in "${shorts[@]}"; do
        if [[ $o = "$short" ]]; then
          similar+=("$short")
          [[ $match = false ]] && match=$i
        fi
        ((i++)) || true
      done
      if [[ ${#similar[@]} -gt 1 ]]; then
        error "${short} is specified ambiguously ${#similar[@]} times"
      elif [[ ${#similar[@]} -lt 1 ]]; then
        match=${#shorts[@]}
        value=true
        shorts+=("$short")
        longs+=('')
        argcounts+=(0)
      else
        value=false
        if [[ ${argcounts[$match]} -ne 0 ]]; then
          if [[ $remaining = '' ]]; then
            if [[ ${#argv[@]} -eq 0 || ${argv[0]} = '--' ]]; then
              error "${short} requires argument"
            fi
            value=${argv[0]}
            argv=("${argv[@]:1}")
          else
            value=$remaining
            remaining=''
          fi
        fi
        if [[ $value = false ]]; then
          value=true
        fi
      fi
      parsed_params+=("$match")
      parsed_values+=("$value")
    done
  }

  parse_long() {
    local token=${argv[0]}
    local long=${token%%=*}
    local value=${token#*=}
    local argcount
    argv=("${argv[@]:1}")
    [[ $token = --* ]] || _return 88
    if [[ $token = *=* ]]; then
      eq='='
    else
      eq=''
      value=false
    fi
    local i=0
    local similar=()
    local match=false
    for o in "${longs[@]}"; do
      if [[ $o = "$long" ]]; then
        similar+=("$long")
        [[ $match = false ]] && match=$i
      fi
      ((i++)) || true
    done
    if [[ $match = false ]]; then
      i=0
      for o in "${longs[@]}"; do
        if [[ $o = $long* ]]; then
          similar+=("$long")
          [[ $match = false ]] && match=$i
        fi
        ((i++)) || true
      done
    fi
    if [[ ${#similar[@]} -gt 1 ]]; then
      error "${long} is not a unique prefix: ${similar[*]}?"
    elif [[ ${#similar[@]} -lt 1 ]]; then
      [[ $eq = '=' ]] && argcount=1 || argcount=0
      match=${#shorts[@]}
      [[ $argcount -eq 0 ]] && value=true
      shorts+=('')
      longs+=("$long")
      argcounts+=("$argcount")
    else
      if [[ ${argcounts[$match]} -eq 0 ]]; then
        if [[ $value != false ]]; then
          error "${longs[$match]} must not have an argument"
        fi
      elif [[ $value = false ]]; then
        if [[ ${#argv[@]} -eq 0 || ${argv[0]} = '--' ]]; then
          error "${long} requires argument"
        fi
        value=${argv[0]}
        argv=("${argv[@]:1}")
      fi
      if [[ $value = false ]]; then
        value=true
      fi
    fi
    parsed_params+=("$match")
    parsed_values+=("$value")
  }

  required() {
    local initial_left=("${left[@]}")
    local node_idx
    ((testdepth++)) || true
    for node_idx in "$@"; do
      if ! "node_$node_idx"; then
        left=("${initial_left[@]}")
        ((testdepth--)) || true
        return 1
      fi
    done
    if [[ $((--testdepth)) -eq 0 ]]; then
      left=("${initial_left[@]}")
      for node_idx in "$@"; do
        "node_$node_idx"
      done
    fi
    return 0
  }

  either() {
    local initial_left=("${left[@]}")
    local best_match_idx
    local match_count
    local node_idx
    ((testdepth++)) || true
    for node_idx in "$@"; do
      if "node_$node_idx"; then
        if [[ -z $match_count || ${#left[@]} -lt $match_count ]]; then
          best_match_idx=$node_idx
          match_count=${#left[@]}
        fi
      fi
      left=("${initial_left[@]}")
    done
    ((testdepth--)) || true
    if [[ -n $best_match_idx ]]; then
      "node_$best_match_idx"
      return 0
    fi
    left=("${initial_left[@]}")
    return 1
  }

  optional() {
    local node_idx
    for node_idx in "$@"; do
      "node_$node_idx"
    done
    return 0
  }

  oneormore() {
    local i=0
    local prev=${#left[@]}
    while "node_$1"; do
      ((i++)) || true
      [[ $prev -eq ${#left[@]} ]] && break
      prev=${#left[@]}
    done
    if [[ $i -ge 1 ]]; then
      return 0
    fi
    return 1
  }

  switch() {
    local i
    for i in "${!left[@]}"; do
      local l=${left[$i]}
      if [[ ${parsed_params[$l]} = "$2" ]]; then
        left=("${left[@]:0:$i}" "${left[@]:((i+1))}")
        [[ $testdepth -gt 0 ]] && return 0
        if [[ $3 = true ]]; then
          eval "((var_$1++))" || true
        else
          eval "var_$1=true"
        fi
        return 0
      fi
    done
    return 1
  }

  value() {
    local i
    for i in "${!left[@]}"; do
      local l=${left[$i]}
      if [[ ${parsed_params[$l]} = "$2" ]]; then
        left=("${left[@]:0:$i}" "${left[@]:((i+1))}")
        [[ $testdepth -gt 0 ]] && return 0
        local value
        value=$(printf -- "%q" "${parsed_values[$l]}")
        if [[ $3 = true ]]; then
          eval "var_$1+=($value)"
        else
          eval "var_$1=$value"
        fi
        return 0
      fi
    done
    return 1
  }

  stdout() {
    printf -- "cat <<'EOM'\n%s\nEOM\n" "$1"
  }

  stderr() {
    printf -- "cat <<'EOM' >&2\n%s\nEOM\n" "$1"
  }

  error() {
    [[ -n $1 ]] && stderr "$1"
    stderr "$usage"
    _return 1
  }

  _return() {
    printf -- "exit %d\n" "$1"
    exit "$1"
  }

  set -e
  # substring of doc where leading & trailing newlines have been trimmed
  trimmed_doc=${DOC:0:490}
  # substring of doc containing the Usage: part (i.e. no Options: or other notes)
  usage=${DOC:16:109}
  # shortened shasum of doc from which the parser was generated
  digest=223a8
  # 3 lists representing option metadata
  # names for short options
  shorts=(-v -q -r -h '' '')
  # names for long options
  longs=('' '' '' --help --left --right)
  # argument counts for options, 0 or 1
  argcounts=(0 0 0 0 0 0)

  # Nodes. This is the AST representing the parsed doc.
  node_0(){
    switch _v 0
  }

  node_1(){
    switch _q 1
  }

  node_2(){
    switch _r 2
  }

  node_3(){
    switch __help 3
  }

  node_4(){
    switch __left 4
  }

  node_5(){
    switch __right 5
  }

  node_6(){
    value FILE a true
  }

  node_7(){
    value CORRECTION a
  }

  node_12(){
    optional 0 1 2 3
  }

  node_14(){
    optional 6
  }

  node_15(){
    oneormore 14
  }

  node_16(){
    required 12 15
  }

  node_19(){
    either 4 5
  }

  node_20(){
    required 19
  }

  node_23(){
    required 20 7 6
  }

  node_24(){
    either 16 23
  }

  node_25(){
    required 24
  }


  # shellcheck disable=2016
  cat <<<' docopt_exit() {
  [[ -n $1 ]] && printf "%s\n" "$1" >&2
  printf "%s\n" "${DOC:16:109}" >&2
  exit 1
}'
  # unset the "var_" prefixed variables that will be used for internal assignment
  unset var__v \
    var__q \
    var__r \
    var___help \
    var___left \
    var___right \
    var_FILE \
    var_CORRECTION
  # invoke main parsing function
  parse 25 "$@"
  # if there are no variables to be set docopt() will exit here
  # shellcheck disable=2157,2140
  # shellcheck disable=2034
  local prefix=${DOCOPT_PREFIX:-''}

  # Workaround for bash-4.3 bug
  # The following script will not work in bash 4.3.0 (and only that version)
  # #!tests/bash-versions/bash-4.3/bash
  # fn() {
  #   decl=$(X=(A B); declare -p X)
  #   eval "$decl"
  #   declare -p X
  # }
  # fn
  local docopt_decl=1
  [[ $BASH_VERSION =~ ^4.3 ]] && docopt_decl=2
  # Adding "declare X" before "eval" fixes the issue, but we don't know the
  # variable names, so instead we just output the `declare`s twice
  # in bash-4.3.

  # Unset exported variables from parent shell,
  # that may clash with names derived from the doc
  unset "${prefix}_v" \
    "${prefix}_q" \
    "${prefix}_r" \
    "${prefix}__help" \
    "${prefix}__left" \
    "${prefix}__right" \
    "${prefix}FILE" \
    "${prefix}CORRECTION"
  # Assign internal varnames to output varnames and set defaults
  eval "${prefix}"'_v=${var__v:-false}'
  eval "${prefix}"'_q=${var__q:-false}'
  eval "${prefix}"'_r=${var__r:-false}'
  eval "${prefix}"'__help=${var___help:-false}'
  eval "${prefix}"'__left=${var___left:-false}'
  eval "${prefix}"'__right=${var___right:-false}'
  if declare -p var_FILE >/dev/null 2>&1; then
    eval "${prefix}"'FILE=("${var_FILE[@]}")'
  else
    eval "${prefix}"'FILE=()'
  fi
  eval "${prefix}"'CORRECTION=${var_CORRECTION:-}'
  local docopt_i=0
  for ((docopt_i=0;docopt_i<docopt_decl;docopt_i++)); do
  declare -p "${prefix}_v" \
    "${prefix}_q" \
    "${prefix}_r" \
    "${prefix}__help" \
    "${prefix}__left" \
    "${prefix}__right" \
    "${prefix}FILE" \
    "${prefix}CORRECTION"
  done
}
# docopt parser above, complete command for generating this parser is `docopt.sh --line-length=0 arguments_example.sh`


main_arguments()
{
  DOCOPT_PREFIX=MINE
  docopt "$@"

  set | grep MINE

  return 0
}

main_arguments "$@"
