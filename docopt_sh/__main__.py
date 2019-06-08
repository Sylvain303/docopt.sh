#!/usr/bin/env python3
import sys
import re
import os
from docopt import docopt, DocoptExit
from . import __doc__ as pkg_doc
from .script import Script, DocoptScriptValidationError
from .parser import Parser, Library
import logging

log = logging.getLogger(__name__)

__doc__ = pkg_doc + """
Usage:
  docopt.sh generate-library
  docopt.sh [options] [SCRIPT]

Options:
  --prefix PREFIX    Parameter variable name prefix [default: ]
  --line-length N    Max line length when minifying (0 to disable) [default: 80]
  --parser           Output parser instead of inserting it in the script
  --library -l PATH  Generates only the dynamic part of the parser and includes
                     the static parts from a file located at PATH,
                     use `generate-library` to create that file.
  -h --help          This help message
  --version          Version of this program

Notes:
  You can pass the script on stdin as well,
  docopt.sh will then output the modified script to stdout.

  If the script has a $version defined anywhere before the invocation of docopt
  --version will automatically output the value of that variable.
"""


def docopt_sh(params):
  if params['generate-library']:
    parser = Parser(params)
    sys.stdout.write('#!/usr/bin/env bash\n\n' + str(parser.generate_library()))
  else:
    try:
      if params['SCRIPT'] is None:
        if sys.stdin.isatty():
          raise DocoptExit('Not reading from stdin when it is a tty')
        script = Script(sys.stdin.read())
      else:
        with open(params['SCRIPT'], 'r') as h:
          script = Script(h.read(), params['SCRIPT'])
      script.validate_script_locations()
      parser = Parser(params)
      if params['--parser']:
        sys.stdout.write(parser.generate(script))
      else:
        patched_script = script.patch(parser)
        if params['SCRIPT'] is None:
          sys.stdout.write(str(patched_script))
        else:
          with open(params['SCRIPT'], 'w') as h:
            h.write(str(patched_script))
    except DocoptScriptValidationError as e:
      print(str(e))
      # Exit code 74: input/output error (sysexits.h)
      sys.exit(74)


def main():
  params = docopt(__doc__)
  docopt_sh(params)

if __name__ == '__main__':
  main()
