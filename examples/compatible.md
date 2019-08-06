# make docopts.sh compatible with docopts

## `docopts` ==> `docopt.sh`

How to convert a example for `docopts` to work with `docopt.sh`

* convert Usage (`$HELP`) to `DOC=` assignment [parser
  here](https://github.com/andsens/docopt.sh/blob/master/docopt_sh/script.py#L134)
* convert vaviable name mangled variables to `docopt.sh` [mangled
  names](https://github.com/andsens/docopt.sh/blob/master/docopt_sh/bash.py#L47)
  * use `DOCOPT_PREFIX=ARGS_` for same prefix
  * sed + --no-mangle parsing ?
* convert bash4 assoc to globals
* convert `docopts` call to `docopt()` 
* add `main_code()` bash function wrapper + `$0 == $BASH_SOURCE` detection wrapper


## `docopt.sh` ==> `docopts`

* example is `docopt.sh/tests/scripts/`
* convert `docopt` call
  * `docopt "$@"` ==> `docopts --no-mangle -h "$DOC" : "$@"`
* convert variable mangled
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
