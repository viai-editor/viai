vim9script

# viai.mcp - the tools
# Maintainer: Hirohito Higashi <h.east.727@gmail.com>

# At most this many tags are listed by viai_help_search.
const MAX_TAGS = 50
# At most this many lines are returned by viai_help_read.
const MAX_LINES = 300

# A line that defines a help tag at its end, such as
#     ch_sendexpr({handle}, {expr} [, {options}])	*ch_sendexpr()*
const TAG_LINE = '\*[^*|" \t]\+\*\s*$'
# A line of "=" that starts a section.
const SECTION_LINE = '^=\{20,}$'

const DEFS = [
  {
    name: 'viai_help_search',
    description: 'Find ViAI help tags that match a Vim regular expression,'
      .. ' e.g. "^ch_send" or "dryrun".  Lists the tags with the help file'
      .. $' they are in, at most {MAX_TAGS}.',
    inputSchema: {
      type: 'object',
      properties: {
        pattern: {type: 'string',
          description: 'A Vim regular expression for the tag names'},
      },
      required: ['pattern'],
    },
  },
  {
    name: 'viai_help_read',
    description: 'Read the ViAI help text of a tag, e.g. "ch_sendexpr()",'
      .. ' "''tabstop''" or ":source-dryrun".  Returns the text from the'
      .. ' tag to the next tag, or the whole section for the tag of a'
      .. ' section heading, e.g. "vim9-classes", or the whole file for'
      .. $' the tag of a help file, e.g. "channel.txt".  At most {MAX_LINES}'
      .. ' lines.',
    inputSchema: {
      type: 'object',
      properties: {
        tag: {type: 'string', description: 'The exact help tag'},
      },
      required: ['tag'],
    },
  },
  {
    name: 'viai_vimscript_check',
    description: 'Check a Vim script without running it, with ":source'
      .. ' ++dryrun" of ViAI: the script is read, its :def functions are'
      .. ' compiled and the errors are returned.  Other commands at the'
      .. ' script level are not run or checked.  To check Vim9 script'
      .. ' commands, put them in a :def function.  Give either "path" or'
      .. ' "source".',
    inputSchema: {
      type: 'object',
      properties: {
        path: {type: 'string', description: 'The file of the script'},
        source: {type: 'string', description: 'The text of the script'},
      },
    },
  },
]

export def List(): list<dict<any>>
  return DEFS
enddef

export def Exists(name: string): bool
  return DEFS->indexof((_, d) => d.name == name) >= 0
enddef

def Text(text: string, is_error = false): dict<any>
  return {content: [{type: 'text', text: text}], isError: is_error}
enddef

# Have taglist() look in the help tags of 'runtimepath'.
def SetHelpTags()
  &tags = globpath(&runtimepath, 'doc/tags', false, true)
    ->map((_, f) => escape(f, ' ,'))->join(',')
enddef

def HelpSearch(args: dict<any>): dict<any>
  var pattern = args->get('pattern', '')
  if type(pattern) != v:t_string || pattern == ''
    return Text('"pattern" must be a non-empty string', true)
  endif
  # taglist() ignores an invalid pattern, but a match gives an error.
  try
    eval '' =~ pattern
  catch
    return Text($'Invalid pattern "{pattern}": {v:exception}', true)
  endtry
  SetHelpTags()
  var found = taglist(pattern)
  if found->empty()
    return Text($'No help tag matches "{pattern}"')
  endif
  var lines = found[: MAX_TAGS - 1]
    ->mapnew((_, t) => t.name .. "\t" .. fnamemodify(t.filename, ':t'))
  if len(found) > MAX_TAGS
    add(lines, $'... and {len(found) - MAX_TAGS} more')
  endif
  return Text(lines->join("\n"))
enddef

def HelpRead(args: dict<any>): dict<any>
  var tag = args->get('tag', '')
  if type(tag) != v:t_string || tag == ''
    return Text('"tag" must be a non-empty string', true)
  endif
  SetHelpTags()
  var found = taglist('^' .. escape(tag, '\^$.*~[]') .. '$')
    ->filter((_, t) => t.name ==# tag)
  if found->empty()
    return Text($'No help tag "{tag}"', true)
  endif
  var file = found[0].filename
  var lines = readfile(file)
  var start = match(lines, '\V*' .. escape(tag, '\') .. '*')
  if start < 0
    return Text($'Tag "{tag}" not found in {file}', true)
  endif

  # The tag of the file, on the first line, gives the whole file.  The tag of
  # a section heading gives the whole section: at most two lines without a
  # tag, the heading or an empty line, come after the line of "=".
  var section = start == 0
  var first = start
  var top = start
  while top > 0 && lines[top - 1] =~ TAG_LINE
    top -= 1
  endwhile
  if top > 0
    for k in range(top - 1, max([0, top - 3]), -1)
      if lines[k] =~ SECTION_LINE
        section = true
        first = k + 1
        break
      elseif lines[k] =~ TAG_LINE
        break
      endif
    endfor
  endif
  while lines[first] =~ '^\s*$'
    first += 1
  endwhile

  # The tags of the text may take more than one line.
  var i = start + 1
  while i < len(lines) && lines[i] =~ TAG_LINE
    i += 1
  endwhile
  # The text ends before the modeline, the line of "=" that starts the next
  # section unless the text is the whole file, or the next tag that follows
  # an empty line unless the text is a section.
  while i < len(lines)
    if lines[i] =~ '^ vim:'
        || (start > 0 && lines[i] =~ SECTION_LINE)
        || (!section && lines[i] =~ TAG_LINE && lines[i - 1] =~ '^\s*$')
      break
    endif
    i += 1
  endwhile
  var text = lines[first : i - 1]
  var cut = len(text) > MAX_LINES
  text = text[: MAX_LINES - 1]
  # Without the empty lines at the end.
  while !text->empty() && text[-1] =~ '^\s*$'
    remove(text, -1)
  endwhile
  var head = $'{fnamemodify(file, ':t')}:{first + 1}'
  return Text(([head] + text + (cut ? ['[...]'] : []))->join("\n"))
enddef

def VimscriptCheck(args: dict<any>): dict<any>
  if args->has_key('path') == args->has_key('source')
    return Text('Give either "path" or "source"', true)
  endif
  var file: string
  var tmp = ''
  if args->has_key('path')
    var path = args.path
    if type(path) != v:t_string || !filereadable(path)
      return Text($'Cannot read "{path}"', true)
    endif
    file = fnamemodify(path, ':p')
  else
    var source = args.source
    if type(source) != v:t_string
      return Text('"source" must be a string', true)
    endif
    tmp = tempname() .. '.vim'
    writefile(split(source, "\n", true), tmp)
    # On MS-Windows tempname() may give short names: ":p" expands them to
    # the long names that the errors show.
    tmp = fnamemodify(tmp, ':p')
    file = tmp
  endif

  # A ViAI of its own reads the script: what a dry run defines stays in that
  # ViAI.  It finds what the script imports by name on the same
  # 'runtimepath'.
  var out = tempname()
  var cmd = [v:progpath, '--clean', '-es', '-N',
    '--cmd', 'let &runtimepath = ' .. string(&runtimepath),
    '--cmd', 'silent! language messages C',
    '-c', 'redir! > ' .. fnameescape(out),
    '-c', 'silent! source ++dryrun ' .. fnameescape(file),
    '-c', 'redir END', '-c', 'qa!']
  system(cmd->mapnew((_, a) => shellescape(a))->join(' '), '')
  var lines = filereadable(out) ? readfile(out) : []
  delete(out)
  if tmp != ''
    delete(tmp)
  endif

  lines->filter((_, l) => l != '')
  if lines->empty()
    return Text('No errors found')
  endif
  var text = lines->join("\n")
  if tmp != ''
    text = substitute(text, '\V' .. escape(tmp, '\'), '<source>', 'g')
  endif
  return Text(text)
enddef

export def Call(name: string, args: dict<any>): dict<any>
  if name == 'viai_help_search'
    return HelpSearch(args)
  elseif name == 'viai_help_read'
    return HelpRead(args)
  endif
  return VimscriptCheck(args)
enddef

# vim: ts=2 sw=0 et
