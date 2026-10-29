" Test :version Ex command

func Test_version()
  " version should always return the same string.
  let v1 = execute('version')
  let v2 = execute('version')
  call assert_equal(v1, v2)

  call assert_match("^\n\nViAI - Vim Advanced Integrated .*", v1)
endfunc

func Test_version_redirect()
  CheckNotGui
  CheckCanRunGui
  CheckUnix

  call RunVim([], [], '--clean -g --version >Xversion 2>&1')
  call assert_match('Features included', readfile('Xversion')->join())

  call delete('Xversion')
endfunc

" The features[] array in version.c must stay sorted.
func Test_features_sorted()
  let lines = readfile('../version.c')
  let start = match(lines, '^static char \*(features\[\]) =')
  call assert_notequal(-1, start)
  let end = match(lines, '^};', start)
  call assert_notequal(-1, end)

  " Alternatives for a single slot (#if/#elif/#else chains): only one of
  " each group is ever compiled, so they are not separate list positions.
  let ignore = ['dialog_con', 'dialog_gui', 'dialog', 'multi_byte', 'xpm', 'xsmp']

  let names = []
  for line in lines[start : end]
    let name = matchstr(line, '"[+-]\zs[A-Za-z_0-9]\+\ze\%(/dyn\)\=",')
    if name == '' || index(ignore, name) >= 0
      continue
    endif
    if empty(names) || names[-1] !=# name
      call add(names, name)
    endif
  endfor

  call assert_true(len(names) > 100)
  call assert_equal(sort(copy(names), 'i'), names)
endfunc

func Test_version_viai()
  let v = execute('version')
  call assert_match("\nIncluded patches: 1-[^\n]*"
        \ .. "\nViAI is a modified version of Vim \\d\\+\\.\\d\\+"
        \ .. "\nIncluded Vim patches: 1-", v)
endfunc

func Test_has_viai()
  call assert_true(has('viai'))
  call assert_true(has('viai-1.0'))
  call assert_true(has('viai-1.0.0'))
  call assert_true(has('viai-0.9'))
  call assert_true(has('viai-0.9.9999'))
  call assert_false(has('viai-1.0.9999'))
  call assert_false(has('viai-1.1'))
  call assert_false(has('viai-2.0'))
  call assert_false(has('viai-1'))
  call assert_false(has('viai-'))
endfunc

func Test_viai_version_variables()
  call assert_equal(100, v:viai_version)
  let patch = matchstr(execute('version'), "\nIncluded patches: 1-\\zs\\d\\+")
  call assert_equal(1000000 + str2nr(patch), v:viai_versionlong)
  call assert_true(has('viai-1.0.' .. (v:viai_versionlong % 10000)))
  call assert_false(has('viai-1.0.' .. (v:viai_versionlong % 10000 + 1)))
  call assert_fails('let v:viai_version = 1', 'E46:')
  call assert_fails('let v:viai_versionlong = 1', 'E46:')
endfunc

" vim: shiftwidth=2 sts=2 expandtab
