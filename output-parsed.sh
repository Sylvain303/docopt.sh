#!/usr/bin/env bash

# Used to evaluate programs generated by the test suite
eval "$(cat)"
docopt "$@"
for var in "${param_names[@]}"; do declare -p "$var"; done