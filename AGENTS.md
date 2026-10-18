# AGENTS.md

Guidance for AI coding agents working in the ViAI repository.

## Project

ViAI (Vim Advanced Integrated) is a text editor written in C, based on Vim
(https://github.com/vim/vim).  It started from Vim 9.2.1186 and keeps
importing the patches of Vim.  The differences from Vim are described in
`runtime/doc/viai.txt` (`:help viai`).

The code is old and has grown organically over the past 30+ years. Some
files are vendored from upstream projects (`src/xdiff`, `src/libvterm`);
parts of the runtime are occasionally shared with forks like Neovim.

ViAI, like Vim, strives to be portable across several different operating
systems and aims to be a stable, robust editor gradually developing new
features while remaining backwards compatible as much as possible.

At the same time, ViAI can be compiled with different feature sets, from the
POSIX compatible minimal vi to a full-fledged GUI editor which includes
additional scripting interfaces.

See `runtime/doc/develop.txt` for the high level design goals.

## Build and test

    # Full build on Unix/Linux (from src/):
    make

    # Run the full test suite:
    make test

    # Generate proto files
    make proto

    # Run a single test file:
    cd src/testdir && make test_name.res

Output is in testdir/messages and testdir/test.log

The program is built as `src/viai` (`viai.exe` and `gviai.exe` on
MS-Windows).

Builds on Windows depend on the Environment, see `src/INSTALLpc.txt`
for Cygwin/MSYS and MSVC ways to build ViAI

Before submitting any patch, at minimum:
1. The build succeeds without new warnings.
2. Relevant tests pass.
3. The code matches the style of the file being edited.

## Layout

- `src/` - the C source. Subsystem names are usually obvious from filenames
  (`buffer.c`, `window.c`, `search.c`, `vim9compile.c`, etc.).
- `src/proto/` - function prototypes, one `.pro` file per source file.
  Regenerated; do not hand-edit unless you know what you're doing.
- `src/po` - Translations
- `src/xxd` - for the xxd subproject
- `src/xdiff` - for the xdiff library (imported from git)
- `src/libvterm` - for the libvterm library
- `src/testdir/` - tests. Vim-script files named `test_*.vim`.
  Screendump expected output lives in `src/testdir/dumps/`.
- `runtime/doc/` - user-facing documentation in Vim help format
- `runtime/syntax/generator` - Syntax script for Vim Script, automatically generated
  from Vims source
- `runtime/`  - runtime files shipped with ViAI.  A file that has a
  maintainer may still be changed in ViAI when needed.  Do not update the
  Last Change header of files imported from Vim: it would conflict with Vim
  patches.
- `src/version.c` - contains the `viai_included_patches[]` list for ViAI
  patches and the `included_patches[]` list for Vim patches.  Every patch
  touching anything below `src/` (with the exception of `src/po`) needs a new
  entry at the top of its list, will be updated only when merging into the
  master tree.

## Relationship with Vim

- **Vim patches are imported as separate commits.**  Never mix a Vim patch
  with ViAI changes in one commit.  Every Vim commit, imported or not, is
  recorded in the git log with a `vim-patch:` token: `vim-patch:9.2.NNNN`
  for a numbered patch, `vim-patch:<hash>` (the first 7 characters of the
  Vim commit hash) for a commit without a patch number, such as
  `runtime(...)`.
- **An imported Vim commit** is authored by the ViAI maintainer and keeps
  the message from Vim, with these changes:
    - The subject is the token followed by the subject from Vim without
      its `patch 9.2.NNNN: ` prefix, e.g.
      `vim-patch:9.2.1187: <subject>` or `vim-patch:1a2b3c4: <subject>`.
    - Issue and pull request numbers refer to Vim:
      `closes: vim/vim#NNNNN`, not `closes: #NNNNN`.
    - The URL of the Vim commit follows the Problem/Solution header:
      `https://github.com/vim/vim/commit/<full hash>`.
    - The author of the Vim commit is credited with `Co-authored-by:`,
      next to the `Co-authored-by:` lines from Vim.
    - `Signed-off-by:` lines from Vim are dropped: they certify the
      contribution to Vim, not to ViAI.  The ViAI maintainer adds their
      own `Signed-off-by:`.
    - When the patch had to be adapted to ViAI (e.g. renamed files), a
      short paragraph describes the adaptation.
  Its pull request links to the one of Vim (`vim/vim#NNNNN`) and repeats
  the `Co-authored-by:` lines in its description.  A pull request with
  several imported commits is titled `vim-patch: <summary>` and lists the
  message of each commit under a `#### <subject>` heading.
- **Vim commits that are not imported** are listed in the message of one
  commit, one per line, each with a reason:

      vim-patch:9.2.1188: <subject> -- N/A: CI of Vim only
      vim-patch:1a2b3c4: <subject> -- N/A: netrw only
      vim-patch:9.2.1190: <subject> -- Declined: <reason>

  "N/A" means the commit does not apply to ViAI, "Declined" means ViAI does
  not want the change.  The same commit adds the numbers of the N/A patches
  to `included_patches[]` in `src/version.c`, so that `has('patch-...')` is
  true for them.  Declined patches are not added.
- **License**: ViAI's own changes are licensed under the Apache License 2.0,
  code imported from Vim (the initial import and every `vim-patch:` commit)
  under the Vim license.
- **Keep the diff against Vim small**, so that Vim patches keep applying.
  Change existing Vim code only where needed.  Put ViAI-specific tests in
  their own files (e.g. `src/testdir/test_viai_config.vim`).
- **ViAI has its own version** (`VIAI_VERSION_MAJOR` and
  `VIAI_VERSION_MINOR` in `src/version.h`) and patch numbers (1.0.0001, ...).
  `v:version` and `has('patch-...')` keep reporting the Vim version.

## Commit format

ViAI uses Vim's strict commit message format. The subject line is a
one-sentence **problem statement**, not a description of the fix:

    short description of the problem

    Problem:  Restatement of the problem as a full sentence, possibly
              with a reporter attribution in parentheses.
    Solution: Short description of the fix, ending with the author's
              name in parentheses when it is not the maintainer.

    optional longer description of the problem and solution goes here in prose.
    Do not use bullet points.

    fixes:   #NNNN
    related: #NNNN
    closes:  #NNNN

    Assisted-by: <AI tool>
    Co-authored-by: Name
    Signed-off-by: Author Name <email>

Rules:

- **Subject line states the problem**, not the solution. "fix typo" is
  wrong; "typo in foo() causes OOB read" is right.
- **Problem line is a full sentence with a trailing period.** It mirrors
  the subject.
- **Solution line ends with `(Author Name)`** — parentheses, period
  after them — unless the author is the maintainer (Hirohito Higashi).
- **Longer prose**, if any, goes after the Problem/Solution header
- **`fixes:` references the issue** the patch fixes.
  **`closes:` references the PR** that introduces the fix.
  **`related:` references related issues**, including issues that caused this
  one.
  All can appear. Colon, aligned, no trailing period.
- **`Signed-off-by:` is required** for the Developer Certificate of Origin (DCO).
- **`Co-Authored-by:` is allowed** and is the accepted way to
  acknowledge human assistance transparently. Human coauthors should usually
  also have their own Signed-off-by.
- **`Assisted-by:` is required** when AI was used.
- **A numbered ViAI patch** has the subject `patch 1.0.NNNN: ` followed by
  the problem statement.  The number is added when merging.

## C code conventions

- **Indentation is 4 spaces per level.** Existing files use tabs with
  `ts=8 sts=4 sw=4 noet` (set by the modeline in the file),
  so tabs of width 8 appear where two levels of indent collapse. `sign.c`,
  `sound.c`, and any new file must use spaces only and follow the style from
  the .editorconfig file.
- **Opening braces go on their own line (Allman style)** — for function
  definitions and for control-flow constructs (`if`/`else`/`for`/`while`/
  `do`) alike.
- **Function definitions**: return type on its own indented line, with
  the function name beginning on the next line.
- Initialize locals where a reader cannot trivially see the first
  assignment (common for pointers and return-value accumulators).
  Don't add `= 0` initializers for values that are always assigned
  before use — they can hide real uninitialized-read bugs from
  the compiler.
- `for (int i = 0; ...)` loop declarations are fine in files that
  use them; older files may declare the counter at the top of the
  block.
- **Function-scope declarations at the top of a block** is the historical
  style, but mid-block declarations are acceptable in files that have
  adopted them. Match the surrounding code.
- **Custom types end in `_T`** (e.g., `buf_T`, `linenr_T`, `pos_T`).
  Never use `_t` — it collides with POSIX typedefs.
- **C language is C95 plus specific C99 features**: `//` comments,
  mixed declarations and statements, `__func__`, `bool`/`_Bool`,
  variadic macros, compound literals, `static inline`, trailing enum
  commas. Do not reach for later C standards — Vim still must build
  with Compaq C on OpenVMS. See `*assumptions-C-compiler*` in
  `develop.txt` for the full list.
- **`bool` / `true` / `false` are acceptable.** Vim is transitioning
  from `int` with `TRUE`/`FALSE` to C99 `bool`. Do not "fix" `bool`
  back to `int`. Within a single patch, be consistent — don't mix
  `true` and `TRUE` in new code.
- **Do not mass-convert** `TRUE`/`FALSE` to `true`/`false` across files
  unless that is the patch's explicit purpose. Opportunistic
  conversions create noise in diffs.
- **`STRLEN_LITERAL("...")`** should be used when the length of a
  string literal is needed. Avoid `STRLEN()` on literals.
- **`vim_snprintf_safelen()`** returns the written length; prefer it
  over `vim_snprintf()` when the length is then needed.
- **Prefer `dict_add_string_len()`** when the string length is already
  known, over `dict_add_string()` which calls `STRLEN()`.
- **String/buffer parameters go `(char_u *buf, size_t buflen)`** —
  length alongside pointer, in bytes. Use `size_t` for byte counts,
  `int` only where required by legacy APIs.
- **Guards before divisions.** Check for divisor zero explicitly, even
  when a composite earlier guard would prevent it. Relying on
  transitive guards is fragile.
- When introducing new allocations, verify the cleanup paths handle all exit
  conditions (early return, error branches, etc).

**Use Vim wrappers instead of libc where one exists:**

| libc          | Vim                    | Why                         |
|---------------|------------------------|-----------------------------|
| `free()`      | `vim_free()`           | Tolerates NULL              |
| `malloc()`    | `alloc()` / `lalloc()` | Checks for OOM              |
| `strcpy()`    | `STRCPY()`             | Cast for `char_u *`         |
| `strchr()`    | `vim_strchr()`         | Handles special characters  |
| `strrchr()`   | `vim_strrchr()`        | Handles special characters  |
| `memcpy()`    | `mch_memmove()`        | Handles overlapping copies  |
| `bcopy()`     | `mch_memmove()`        | Handles overlapping copies  |
| `memset()`    | `vim_memset()`         | Uniform across systems      |
| `isspace()`   | `vim_isspace()`        | Handles bytes > 127         |
| `iswhite()`   | `vim_iswhite()`        | TRUE only for tab and space |

Further rules, not spelled out here, live in `runtime/doc/develop.txt`:

- `*style-names*` — reserved name patterns (`is*`, `to*`, `str*`, `mem*`,
  `wcs*`, `.*_t`, `__.*`), forbidden identifiers (`delete`, `this`, `new`,
  `time`, `index`), and the 31-character function-name limit.
- `*style-spaces*`, `*style-examples*` — spacing and one-statement-per-line.
- `*style-various*` — `FEAT_` feature prefix, uppercase `#define`,
  `#ifdef HAVE_X` rather than `#if HAVE_X`, no `'\"'`.
- `*assumptions-makefiles*` — POSIX.1-2001 `make` only in the main
  Makefiles (no `%` rules, `:=`, `.ONESHELL`, GNU conditionals).
- Vim uses `char_u` instead of `char` type
- Vim uses the macros `STRLEN`, `STRCPY`, `STRCMP`, `STRCAT` that work
  with the `char_u` type.
- `*style-clang-format*` — `sign.c` and `sound.c` are formatted with
  `clang-format`; re-run it after editing those files.

## Vim9 script conventions (in tests and runtime files)

- Write modern Vim style (new files can use Vim9 script, but compatibility
  with Neovim and other forks is a concern, so in doubt please ask!)
- **Drop `l:` prefix from local variables** in Vim-script tests.
- **Don't add `CheckFeature` inside individual tests** if it's already
  at the top of the file.
- If a test file doesn't gate features at the top, add CheckFeature to
  individual tests that depend on specific build features.

## Test conventions

- Tests are in `src/testdir/test_*.vim`.
- Reproducible tests beat "it doesn't crash" tests. If a patch fixes
  a rendering bug, add a screendump test. If it fixes incorrect output,
  assert the output.
- Add comprehensive tests for newly added features and include them
  in existing tests if possible
- **Screendump tests** use `CheckScreendump`, `RunVimInTerminal`,
  `VerifyScreenDump`, and live dumps in `src/testdir/dumps/`.
- `v9.CheckScriptSuccess(lines)` / `v9.CheckScriptFailure(lines, error, lnum)`
  are the standard way to test Vim9 script behavior at script-load time.
- When fixing a bug reported as an issue, include a test that
  reproduces the original report, not just a minimal synthetic case.
- Tests for Syntax runtime are in `runtime/syntax/testdir`
- Tests for Indent runtime are in `runtime/indent/testdir`

## Common gotchas

- **Distinguish what code enforces from what docs claim.** If a patch
  changes documented behavior, say so in the Problem/Solution.
- **Generated files** (`src/auto/configure`, generated Wayland protocol
  C, etc.) should only be regenerated when their source changes.
  Mixing unrelated regeneration into a functional patch creates noise.

## Documentation

- User-facing option or feature changes require a `runtime/doc/*.txt`
  update in the same patch.  **Update the help text that describes the
  changed behavior**, also in Vim's help files, so that the help stays
  correct for ViAI, and list the change in `runtime/doc/viai.txt`, the
  overview of the differences from Vim.
- Bump the `Last change:` header only of ViAI's own help files, such as
  `viai.txt`.

### Help file style

See `runtime/doc/helphelp.txt` (`*help-writing*`) for the authoritative
reference. Key conventions:

- **File header**: first line is `*filename.txt*` then a tab then a
  short description. That description appears under `LOCAL ADDITIONS`
  in `help.txt`. The version and `Last change:` date go on the second
  line, right aligned.
- **Modeline**: every help file ends with a Vim modeline — typically
  `vim:tw=78:ts=8:noet:ft=help:norl:`.
- **Layout**: `'textwidth'` 78, `'tabstop'` 8, indent and align with
  tab characters. Two spaces between sentences. Run `:retab`
  (not `:retab!`, and review the diff) after editing.
- **Tags** are defined as `*tag-name*`, usually right-aligned on the
  line where the thing they name is introduced. Tag names must be
  unique across all of `runtime/doc/`; for plugin help, prefix with
  the plugin name.
- **Cross-references inside help text**:
    - `|tag-name|` — hot-link to an existing tag.
    - `` `:cmd` `` — Ex command, highlighted as a code block.
    - `'option'` — option name, in single quotes.
    - `<Key>` or `CTRL-X` — special keys.
    - `{placeholder}` — user-supplied argument.
- **Sections** are separated by a line of `=` starting in column 1.
  Column or subsection headings end with `~` to trigger heading
  highlighting.
- **Code blocks** start with `>` at the end of the introducing line
  and end with `<` as the first non-blank on a later line (any line
  starting in column 1 also implicitly closes the block). Use `>vim`
  (or another language name) to request syntax highlighting inside
  the block.
- **Notation** — `Note`, `Todo`, `Error` and a few similar words are
  auto-highlighted; do not try to fake the highlighting by other means.
- **Language**: gender-neutral language is preferred for new or updated
  text; existing wording does not need to be rewritten for this alone.

## Security

Before reporting a suspected security issue or submitting a patch
that touches security-sensitive code, read `SECURITY.md`. Follow
the disclosure process described there.

## Before submitting

1. Commit message follows the format above.
2. All modified code compiles without new warnings.
3. Tests pass, and new functionality has regression tests.
4. Documentation is updated for user-visible changes.
5. Signed-off-by is present.
6. Diff contains only changes relevant to the stated problem —
   no stray whitespace fixes, no unrelated refactors, no unrelated
   regeneration of `auto/configure`.
7. For multi-patch series: each commit compiles and passes its own
   tests. A known-broken intermediate state that a later patch fixes
   is not acceptable — squash instead.
8. The branch is pushed to the fork and a pull request to viai-editor/viai
   is opened.  It is merged only after CI passes.

## When in doubt

- Make the smallest possible change to achieve the goal. Do not rewrite
  entire files or functions when a targeted edit suffices.
- Read surrounding code and match its style rather than imposing an
  "improvement."
- Err toward smaller, more focused patches. A patch that does three
  things is three patches.
- If a patch fixes a symptom of a deeper bug, say so in the Problem
  and acknowledge the scope limitation in the Solution.
- Before claiming a bug exists, reproduce it. Before claiming code does X, read
  the code. Do not rely on training-data memory of file contents.
- Before running shell commands that modify files outside the working tree,
  install packages, push branches, or invoke network operations, confirm with
  the user.
