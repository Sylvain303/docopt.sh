import re
import os
from io import StringIO
from . import bash_eval_script, patch_file, invoke_docopt, temp_file, generated_library
from docopt_sh.script import Script


def test_arg(monkeypatch, capsys, bash):
  run = patch_file(monkeypatch, capsys, 'echo_ship_name.sh')
  code, out, err = run(bash, 'ship', 'new', 'Britannica')
  assert code == 0
  assert out == 'Britannica\n'


def test_wrong_usage(monkeypatch, capsys, bash):
  run = patch_file(monkeypatch, capsys, 'echo_ship_name.sh')
  code, out, err = run(bash, '--bad-opt')
  assert code != 0


def test_help(monkeypatch, capsys, bash):
  run = patch_file(monkeypatch, capsys, 'echo_ship_name.sh')
  code, out, err = run(bash, '--help')
  assert code == 0
  assert out == 'Usage: echo_ship_name.sh ship new <name>...\n'
  assert err == ''


def test_no_help(monkeypatch, capsys, bash):
  run = patch_file(
    monkeypatch, capsys, 'echo_ship_name.sh',
    docopt_params={'DOCOPT_ADD_HELP': False}
  )
  code, out, err = run(bash, '--help')
  assert code == 1
  assert out == ''
  assert err == 'Usage: echo_ship_name.sh ship new <name>...\n'


def test_version(monkeypatch, capsys, bash):
  run = patch_file(
    monkeypatch, capsys, 'echo_ship_name.sh',
    docopt_params={'DOCOPT_PROGRAM_VERSION': '0.1.5'}
  )
  code, out, err = run(bash, '--version')
  assert code == 0
  assert out == '0.1.5\n'


def test_no_version(monkeypatch, capsys, bash):
  run = patch_file(
    monkeypatch, capsys, 'echo_ship_name.sh',
    docopt_params={'DOCOPT_PROGRAM_VERSION': False}
  )
  code, out, err = run(bash, '--version')
  assert code == 1
  assert out == ''
  assert err == 'Usage: echo_ship_name.sh ship new <name>...\n'


def test_options_anywhere(monkeypatch, capsys, bash):
  run = patch_file(monkeypatch, capsys, 'naval_fate.sh')
  code, out, err = run(bash, 'ship', 'Titanic', 'move', '1', '--speed', '6', '4')
  assert out == 'The Titanic is now moving to 1,4 at 6 knots.\n'


def test_options_first(monkeypatch, capsys, bash):
  run = patch_file(
    monkeypatch, capsys, 'naval_fate.sh',
    docopt_params={'DOCOPT_OPTIONS_FIRST': True}
  )
  code, out, err = run(bash, '--speed', '6', 'ship', 'Titanic', 'move', '1', '4')
  assert code == 0
  assert out == 'The Titanic is now moving to 1,4 at 6 knots.\n'


def test_options_first_fail(monkeypatch, capsys, bash):
  run = patch_file(
    monkeypatch, capsys, 'naval_fate.sh',
    docopt_params={'DOCOPT_OPTIONS_FIRST': True}
  )
  code, out, err = run(bash, 'ship', 'Titanic', 'move', '1', '--speed', '6', '4')
  assert code == 1
  assert out == ''
  assert err[:6] == 'Usage:'


def test_prefix(monkeypatch, capsys, bash):
  run = patch_file(
    monkeypatch, capsys, 'prefixed_echo.sh',
    docopt_params={'DOCOPT_PREFIX': 'prefix_'}
  )
  code, out, err = run(bash, 'ship', 'new', 'Titanic')
  assert code == 0
  assert out == 'Titanic\n'


def test_patch_file(monkeypatch, bash):
  with temp_file('echo_ship_name.sh') as (script, run):
    invoke_docopt(monkeypatch, program_params=[script.name])
    code, out, err = run(bash, 'ship', 'new', 'Olympia')
    assert out == 'Olympia\n'


def test_doc_check(monkeypatch, bash):
  with temp_file('echo_ship_name.sh') as (script, run):
    invoke_docopt(monkeypatch, program_params=[script.name])
    with open(script.name, 'r') as h:
      contents = h.read()
    contents = contents.replace('ship new <name>', 'ship delete <name>')
    with open(script.name, 'w') as h:
      h.write(contents)
    code, out, err = run(bash, 'ship', 'new', 'Olympia')
    regex = (
      r'^The current usage doc \([^)]+\) does not match what the parser was '
      r'generated with \([^)]+\)\nRun `docopt.sh` to refresh the parser.\n$'
    )
    assert re.match(regex, err) is not None


def test_no_doc_check(monkeypatch, bash):
  with temp_file('echo_ship_name.sh', docopt_params={'DOCOPT_DOC_CHECK': False}) as (script, run):
    invoke_docopt(monkeypatch, program_params=[script.name])
    with open(script.name, 'r') as h:
      contents = h.read()
    contents = contents.replace('ship new <name>', 'ship delete <name>')
    with open(script.name, 'w') as h:
      h.write(contents)
    code, out, err = run(bash, 'ship', 'new', 'Olympia')
    assert out == 'Olympia\n'


def test_parser_only(monkeypatch, capsys, bash):
  with open('tests/scripts/naval_fate.sh') as h:
    script = h.read()
  doc = Script(script).doc.raw_value
  parser = invoke_docopt(monkeypatch, capsys=capsys, program_params=['--parser', '-'], stdin=StringIO(script)).out
  program = '''
DOC="{doc}"
{parser}
eval "$(docopt "$@")"
echo $((_x_ + _y_))
'''.format(doc=doc, parser=parser)
  captured = invoke_docopt(monkeypatch, capsys, program_params=['-'], stdin=StringIO(program))
  code, out, err = bash_eval_script(bash, captured.out, ['ship', 'shoot', '3', '1'])
  assert code == 0
  assert out == '4\n'


def test_teardown(monkeypatch, capsys, bash):
  run = patch_file(monkeypatch, capsys, 'all_vars.sh')
  code, out, err = run(bash, 'ship', 'new', 'Britannica')
  assert code == 0
  allowed_vars = []
  allowed_fns = ['docopt', 'docopt_exit']
  for line in out.strip().split('\n'):
    if '=' in line:
      name, val = line.split('=', 1)
      assert not name.lower().startswith('docopt') or name in allowed_vars
    elif '()' in line:
      name, rest = line.split(' ', 1)
      assert not name.lower().startswith('docopt') or name in allowed_fns


def test_library(monkeypatch, capsys, bash):
  with generated_library(monkeypatch, capsys) as library:
    run = patch_file(
      monkeypatch, capsys, 'echo_ship_name.sh',
      program_params=['--library', library.name]
    )
    code, out, err = run(bash, 'ship', 'new', 'Britannica')
    assert code == 0
    assert err == ''
    assert out == 'Britannica\n'


def test_library_missing(monkeypatch, capsys, bash):
  run = patch_file(
    monkeypatch, capsys, 'echo_ship_name.sh',
    program_params=['--library', 'bogus-path']
  )
  code, out, err = run(bash, 'ship', 'new', 'Britannica')
  assert code == 1
  assert re.match(r'^environment: line \d+: bogus-path: No such file or directory\n$', err) is not None
  assert out == ''


def test_library_teardown(monkeypatch, capsys, bash):
  with generated_library(monkeypatch, capsys) as library:
    run = patch_file(
      monkeypatch, capsys, 'all_vars.sh',
      program_params=['--library', library.name]
    )
    code, out, err = run(bash, 'ship', 'new', 'Britannica')
    allowed_vars = []
    allowed_fns = ['docopt', 'docopt_exit']
    for line in out.strip().split('\n'):
      if '=' in line:
        name, val = line.split('=', 1)
        assert not name.lower().startswith('docopt') or name in allowed_vars
      elif '()' in line:
        name, rest = line.split(' ', 1)
        assert not name.lower().startswith('docopt') or name in allowed_fns


def test_library_version(monkeypatch, capsys, bash):
  with generated_library(monkeypatch, capsys) as library:
    with temp_file('echo_ship_name.sh') as (script, run):
      invoke_docopt(monkeypatch, program_params=['--library', library.name, script.name])
      with open(script.name, 'r') as h:
        contents = h.read()
      contents = re.sub(r"source (\S+) '([^']+)'", r"source \1 '0.0.0'", contents)
      with open(script.name, 'w') as h:
        h.write(contents)
      code, out, err = run(bash, 'ship', 'new', 'Olympia')
      regex = (
        r'^The version of the included docopt library \([^)]+\) does not '
        r'match the version of the invoking docopt parser \(0\.0\.0\)\n$'
      )
      assert out == ''
      assert code == 70
      assert re.match(regex, err) is not None


def test_auto_params(monkeypatch, capsys, bash):
  with temp_file('naval_fate.sh') as (script, run):
    out = invoke_docopt(monkeypatch, capsys=capsys, program_params=[script.name, '--line-length', '20'])
    code, out, err = run(bash, 'ship', 'shoot', '3', '1')
    assert code == 0
    first_run = None
    with open(script.name, 'r') as handle:
      first_run = handle.read()
    invoke_docopt(monkeypatch, program_params=[script.name])
    code, out, err = run(bash, 'ship', 'shoot', '3', '1')
    assert code == 0
    with open(script.name, 'r') as handle:
      assert first_run == handle.read()


def test_error_fn(monkeypatch, capsys, bash):
  run = patch_file(monkeypatch, capsys, 'enum_check.sh')
  code, out, err = run(bash, '--color', 'sometimes')
  assert code == 1
  assert out == ''
  assert err == '--color must be auto, always, or never\nUsage: enum_check.sh [options]\n'
