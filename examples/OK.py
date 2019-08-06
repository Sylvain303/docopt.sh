#!/usr/bin/python2.7

"""
Usage:
  bug.py -e ARGUMENT

Print ARGUMENT
"""

from docopt import docopt

arguments = docopt(__doc__, version='0.1')
print(arguments)

if arguments.has_key('ARGUMENT'):
    print "cool ARGUMENT is defined"
else:
    print "oh, oh, no more ARGUMENT key!!"

if not arguments['ARGUMENT']:
    raise RuntimeError("ARGUMENT was empty")
else:
    print arguments['ARGUMENT']
