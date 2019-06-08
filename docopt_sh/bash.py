import re
from shlex import quote


class Function(object):

  def __init__(self, name):
    self.name = name

  def __str__(self):
    return '{name}(){{\n{body}\n}}'.format(name=self.name, body=self.body)

  def __repr__(self):
    lines = self.body.split('\n')
    if len(lines) > 5:
      shortend_body = '\n'.join(body[:2]) + '\n  ...\n' + '\n'.join(body[-2:])
    else:
      shortened_body = body
    return '{name}(){{\n{shortend_body}\n}}'.format(name=self.name, body=shortend_body)


class HelperTemplate(Function):

  def __init__(self, name, function_body):
    self.function_body = function_body
    super(HelperTemplate, self).__init__(name)

  @property
  def body(self):
    return self.function_body


class Helper(Function):

  def __init__(self, template, replacements):
    self.template = template
    self.replacements = replacements
    super(Helper, self).__init__(template.name)

  @property
  def body(self):
    body = self.template.function_body
    for placeholder, replacement in self.replacements.items():
      body = body.replace(placeholder, replacement)
    return body


def bash_variable_name(name, prefix=''):
  name = name.replace('<', '_')
  name = name.replace('>', '_')
  name = name.replace('-', '_')
  name = name.replace(' ', '_')
  return prefix + name


def bash_variable_value(value):
  if value is None:
    return ''
  if type(value) is bool:
    return 'true' if value else 'false'
  if type(value) is int:
    return str(value)
  if type(value) is str:
    return quote(value)
  if type(value) is list:
    return '(%s)' % ' '.join(bash_variable_value(v) for v in value)
  raise Exception('Unhandled value type %s' % type(value))


def bash_ifs_value(value):
  if value is None or value == '':
    return "''"
  if type(value) is bool:
    return 'true' if value else 'false'
  if type(value) is int:
    return str(value)
  if type(value) is str:
    return quote(value)
  if type(value) is list:
    raise Exception('Unable to convert list to bash value intended for an IFS separated field')
  raise Exception('Unhandled value type %s' % type(value))


def minify(parser_str, max_length):
  lines = parser_str.split('\n')
  lines = remove_leading_spaces(lines)
  lines = remove_empty_lines(lines)
  lines = remove_newlines(lines, max_length)
  return '\n'.join(lines)


def remove_leading_spaces(lines):
  for line in lines:
    yield re.sub(r'^\s*', '', line)


def remove_empty_lines(lines):
  for line in lines:
    if line != '':
      yield line


def remove_newlines(lines, max_length):
  def is_comment(line):
    return re.match(r'^\s*#', line) is not None

  def needs_separator(line):
    return re.search(r'; (then|do)$|else$|\{$', line) is None

  def has_continuation(line):
    return re.search(r'\\\s*$', line) is not None

  def remove_continuation(line):
    return re.sub(r'\s*\\\s*$', '', line)

  def combine(line1, line2):
    if is_comment(line1) or is_comment(line2):
      if not is_comment(line1):
        return line1
      if not is_comment(line2):
        return line2
      return None
    if has_continuation(line1):
      return remove_continuation(line1) + ' ' + line2
    if needs_separator(line1):
      return line1 + '; ' + line2
    else:
      return line1 + ' ' + line2

  previous = next(lines)
  for line in lines:
    combined = combine(previous, line)
    if combined is None:
      previous = next(lines, None)
    elif len(combined) > max_length:
      yield previous
      previous = line
    else:
      previous = combined
  if previous:
    yield previous