import re
import shlex
import io
from docopt_sh.bash import bash_variable_name
from . import Usecase, patch_stream


def test_usecase(monkeypatch, capsys, usecase, bash):
  assert convert_to_bash(bash, usecase) == run_usecase(monkeypatch, capsys, usecase, bash)


def run_usecase(monkeypatch, capsys, usecase, bash):
  line, _, doc, prog, argv, expect = usecase
  program_template = '''
DOC="{doc}"
"DOCOPT PARAMS"
docopt "$@"
for var in "${{docopt_param_names[@]}}"; do declare -p "${{DOCOPT_PREFIX}}${{var}}"; done
'''
  program = program_template.format(doc=doc)
  run = patch_stream(
    monkeypatch, capsys,
    io.StringIO(program),
    docopt_params={'DOCOPT_PREFIX': '_', 'DOCOPT_TEARDOWN': False}
  )
  code, out, err = run(bash, *shlex.split(argv))
  if code == 0:
    expr = re.compile('^declare (--|-a) ([^=]+)=')
    out = out.strip('\n')
    if out != '':
      result = {expr.match(line).group(2): line for line in out.split('\n')}
    else:
      result = {}
  else:
    result = 'user-error'
  return Usecase(line, bash[0], doc, prog, argv, result)


def convert_to_bash(bash, usecase):
  line, _, doc, prog, argv, expect = usecase
  if expect == 'user-error':
    declarations = expect
  else:
    declarations = {}
    for key, value in expect.items():
      var = '_' + re.sub(r'^[^a-z_]|[^a-z0-9_]', '_', key, 0, re.IGNORECASE)
      declarations[var] = bash_decl(bash[0], var, value)
  return Usecase(line, bash[0], doc, prog, argv, declarations)


def bash_decl(bash_version, name, value):
  if value is None or type(value) in (bool, int, str):
    return 'declare -- {name}={value}'.format(name=name, value=bash_decl_value(bash_version, value))
  if type(value) is list:
    return 'declare -a {name}={value}'.format(name=name, value=bash_decl_value(bash_version, value))
  raise Exception('Unknown value type %s' % type(value))


def bash_decl_value(bash_version, value):
  if value is None:
    return '""'
  if type(value) is bool:
    return '"true"' if value else '"false"'
  if type(value) is int:
    return '"{value}"'.format(value=value)
  if type(value) is str:
    return '"{value}"'.format(value=shlex.quote(value).strip("'"))
  if type(value) is list:
    list_tpl = '({value})'
    if bash_version is not None and (int(bash_version[0]) < 4 or int(bash_version[2]) < 4):
      list_tpl = "'({value})'"
    return list_tpl.format(value=' '.join('[{i}]={value}'.format(
      i=i, value=bash_decl_value(bash_version, v)) for i, v in enumerate(value))
    )

# def repr_failure(self, excinfo):
#   """Called when self.runtest() raises an exception."""
#   if isinstance(excinfo.value, DocoptUsecaseTestException):
#     return "\n".join((
#       "usecase execution failed:",
#       self.doc.rstrip(),
#       "$ %s %s" % (self.prog, self.argv),
#       "result> %s" % json.dumps(excinfo.value.args[1]),
#       "expect> %s" % json.dumps(self.expect),
#     ))
#   else:
#     super().repr_failure(excinfo)