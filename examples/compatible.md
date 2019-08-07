# make docopts.sh compatible with docopts

## `docopts` ==> `docopt.sh`

How to convert an example for `docopts` to work with `docopt.sh`

* convert Usage (`$HELP`) to `DOC=` assignment [parser
  here](https://github.com/andsens/docopt.sh/blob/master/docopt_sh/script.py#L134)
* convert vaviable name mangled variables to `docopt.sh` [mangled
  names](https://github.com/andsens/docopt.sh/blob/master/docopt_sh/bash.py#L47) - OK `--docopt_sh`
  * use `DOCOPT_PREFIX=ARGS_` for same prefix
* convert bash4 assoc to globals?
* convert `docopts` call to `docopt()`
  * `docopts -G ARGS -h "$HELP" : "$@"` ==> `docopt "$@"`
* add `main_code()` bash function wrapper + `$0 == $BASH_SOURCE` detection wrapper


## `docopt.sh` ==> `docopts`

* examples are in `docopt.sh/tests/scripts/`
* convert `docopt` call
  * `docopt "$@"` ==> `docopts --docopt_sh -h "$DOC" : "$@"`
* convert variable mangled `--docopt_sh` with switch - OK
```
ship=true
new=true
<name>=('pipo')

# to

declare -a _name_=([0]="pipo")
declare -- ship="true"
declare -- new="true"
```
* add `main_code()` bash function wrapper + `$0 == $BASH_SOURCE` detection wrapper
