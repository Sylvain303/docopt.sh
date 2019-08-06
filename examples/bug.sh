#!/usr/bin/env bash

DOC="
Usage:
  bug.py -e <argument>

Print <argument>

Options:

  -e   <argument>   Now that -e is defined here, ARGS[-e] will hold the value
"
# docopt parser below, refresh this parser with `docopt.sh bug.sh`
# shellcheck disable=2016,1075
docopt() { parse() { if ${DOCOPT_DOC_CHECK:-true}; then local doc_hash
doc_hash=$(printf "%s" "$DOC" | shasum -a 256)
if [[ ${doc_hash:0:5} != "$digest" ]]; then
stderr "The current usage doc (${doc_hash:0:5}) does not match \
what the parser was generated with (${digest})
Run \`docopt.sh\` to refresh the parser."; _return 70; fi; fi; local root_idx=$1
shift; argv=("$@"); parsed_params=(); parsed_values=(); left=(); testdepth=0
local arg; while [[ ${#argv[@]} -gt 0 ]]; do if [[ ${argv[0]} = "--" ]]; then
for arg in "${argv[@]}"; do parsed_params+=('a'); parsed_values+=("$arg"); done
break; elif [[ ${argv[0]} = --* ]]; then parse_long
elif [[ ${argv[0]} = -* && ${argv[0]} != "-" ]]; then parse_shorts
elif ${DOCOPT_OPTIONS_FIRST:-false}; then for arg in "${argv[@]}"; do
parsed_params+=('a'); parsed_values+=("$arg"); done; break; else
parsed_params+=('a'); parsed_values+=("${argv[0]}"); argv=("${argv[@]:1}"); fi
done; local idx; if ${DOCOPT_ADD_HELP:-true}; then
for idx in "${parsed_params[@]}"; do [[ $idx = 'a' ]] && continue
if [[ ${shorts[$idx]} = "-h" || ${longs[$idx]} = "--help" ]]; then
stdout "$trimmed_doc"; _return 0; fi; done; fi
if [[ ${DOCOPT_PROGRAM_VERSION:-false} != 'false' ]]; then
for idx in "${parsed_params[@]}"; do [[ $idx = 'a' ]] && continue
if [[ ${longs[$idx]} = "--version" ]]; then stdout "$DOCOPT_PROGRAM_VERSION"
_return 0; fi; done; fi; local i=0; while [[ $i -lt ${#parsed_params[@]} ]]; do
left+=("$i"); ((i++)) || true; done
if ! required "$root_idx" || [ ${#left[@]} -gt 0 ]; then error; fi; return 0; }
parse_shorts() { local token=${argv[0]}; local value; argv=("${argv[@]:1}")
[[ $token = -* && $token != --* ]] || _return 88; local remaining=${token#-}
while [[ -n $remaining ]]; do local short="-${remaining:0:1}"
remaining="${remaining:1}"; local i=0; local similar=(); local match=false
for o in "${shorts[@]}"; do if [[ $o = "$short" ]]; then similar+=("$short")
[[ $match = false ]] && match=$i; fi; ((i++)) || true; done
if [[ ${#similar[@]} -gt 1 ]]; then
error "${short} is specified ambiguously ${#similar[@]} times"
elif [[ ${#similar[@]} -lt 1 ]]; then match=${#shorts[@]}; value=true
shorts+=("$short"); longs+=(''); argcounts+=(0); else value=false
if [[ ${argcounts[$match]} -ne 0 ]]; then if [[ $remaining = '' ]]; then
if [[ ${#argv[@]} -eq 0 || ${argv[0]} = '--' ]]; then
error "${short} requires argument"; fi; value=${argv[0]}; argv=("${argv[@]:1}")
else value=$remaining; remaining=''; fi; fi; if [[ $value = false ]]; then
value=true; fi; fi; parsed_params+=("$match"); parsed_values+=("$value"); done
}; parse_long() { local token=${argv[0]}; local long=${token%%=*}
local value=${token#*=}; local argcount; argv=("${argv[@]:1}")
[[ $token = --* ]] || _return 88; if [[ $token = *=* ]]; then eq='='; else eq=''
value=false; fi; local i=0; local similar=(); local match=false
for o in "${longs[@]}"; do if [[ $o = "$long" ]]; then similar+=("$long")
[[ $match = false ]] && match=$i; fi; ((i++)) || true; done
if [[ $match = false ]]; then i=0; for o in "${longs[@]}"; do
if [[ $o = $long* ]]; then similar+=("$long"); [[ $match = false ]] && match=$i
fi; ((i++)) || true; done; fi; if [[ ${#similar[@]} -gt 1 ]]; then
error "${long} is not a unique prefix: ${similar[*]}?"
elif [[ ${#similar[@]} -lt 1 ]]; then
[[ $eq = '=' ]] && argcount=1 || argcount=0; match=${#shorts[@]}
[[ $argcount -eq 0 ]] && value=true; shorts+=(''); longs+=("$long")
argcounts+=("$argcount"); else if [[ ${argcounts[$match]} -eq 0 ]]; then
if [[ $value != false ]]; then
error "${longs[$match]} must not have an argument"; fi
elif [[ $value = false ]]; then
if [[ ${#argv[@]} -eq 0 || ${argv[0]} = '--' ]]; then
error "${long} requires argument"; fi; value=${argv[0]}; argv=("${argv[@]:1}")
fi; if [[ $value = false ]]; then value=true; fi; fi; parsed_params+=("$match")
parsed_values+=("$value"); }; required() { local initial_left=("${left[@]}")
local node_idx; ((testdepth++)) || true; for node_idx in "$@"; do
if ! "node_$node_idx"; then left=("${initial_left[@]}"); ((testdepth--)) || true
return 1; fi; done; if [[ $((--testdepth)) -eq 0 ]]; then
left=("${initial_left[@]}"); for node_idx in "$@"; do "node_$node_idx"; done; fi
return 0; }; switch() { local i; for i in "${!left[@]}"; do local l=${left[$i]}
if [[ ${parsed_params[$l]} = "$2" ]]; then
left=("${left[@]:0:$i}" "${left[@]:((i+1))}")
[[ $testdepth -gt 0 ]] && return 0; if [[ $3 = true ]]; then
eval "((var_$1++))" || true; else eval "var_$1=true"; fi; return 0; fi; done
return 1; }; value() { local i; for i in "${!left[@]}"; do local l=${left[$i]}
if [[ ${parsed_params[$l]} = "$2" ]]; then
left=("${left[@]:0:$i}" "${left[@]:((i+1))}")
[[ $testdepth -gt 0 ]] && return 0; local value
value=$(printf -- "%q" "${parsed_values[$l]}"); if [[ $3 = true ]]; then
eval "var_$1+=($value)"; else eval "var_$1=$value"; fi; return 0; fi; done
return 1; }; stdout() { printf -- "cat <<'EOM'\n%s\nEOM\n" "$1"; }; stderr() {
printf -- "cat <<'EOM' >&2\n%s\nEOM\n" "$1"; }; error() {
[[ -n $1 ]] && stderr "$1"; stderr "$usage"; _return 1; }; _return() {
printf -- "exit %d\n" "$1"; exit "$1"; }; set -e; trimmed_doc=${DOC:1:136}
usage=${DOC:1:29}; digest=3211e; shorts=(-e); longs=(''); argcounts=(0)
node_0(){ switch _e 0; }; node_1(){ value _argument_ a; }; node_4(){
required 0 1; }; node_5(){ required 4; }; cat <<<' docopt_exit() {
[[ -n $1 ]] && printf "%s\n" "$1" >&2; printf "%s\n" "${DOC:1:29}" >&2; exit 1
}'; unset var__e var__argument_; parse 5 "$@"; local prefix=${DOCOPT_PREFIX:-''}
local docopt_decl=1; [[ $BASH_VERSION =~ ^4.3 ]] && docopt_decl=2
unset "${prefix}_e" "${prefix}_argument_"; eval "${prefix}"'_e=${var__e:-false}'
eval "${prefix}"'_argument_=${var__argument_:-}'; local docopt_i=0
for ((docopt_i=0;docopt_i<docopt_decl;docopt_i++)); do
declare -p "${prefix}_e" "${prefix}_argument_"; done; }
# docopt parser above, complete command for generating this parser is `docopt.sh bug.sh`

main_arguments()
{
  DOCOPT_PREFIX=MINE
  eval "$(docopt "$@")"

  if [[ -n $MINEARGUMENT ]] ; then
    echo "cool ARGUMENT is defined"
  else
    echo "oh, oh, no more ARGUMENT variable!!"
  fi

  set | grep MINE

  return 0
}

main_arguments "$@"
