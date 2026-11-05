#!/bin/bash
# Copy lsp.vim and vim9ls into runtime/pack/dist/opt/.
#
# Usage: tools/sync-plugins.sh [-n | -m {file}] {lsp.vim-repo} {vim9ls-repo}
#
# Each argument is a git clone of https://github.com/h-east/lsp.vim or
# https://github.com/h-east/vim9ls.  The files committed at its HEAD replace
# the package directory, except those only needed to develop the plugin.
# Nothing is done when the version of neither plugin differs from the one in
# its package.  Nothing is copied unless the tracked files of both clones are
# as committed and their tests pass with src/viai, which has to be built.
# Prints the test results, the version and the commit of each plugin, and the
# commit message, whose subject is e.g.
# "runtime(vim9ls): bundled vim9ls is older than 0.1.039".
#
# -n		Only compare the versions: exit 0 when an update is needed
#		and 1 when it is not.  src/viai is not needed.
# -m {file}	Also write the commit message to {file}.

set -eu

usage()
{
    echo "Usage: $0 [-n | -m {file}] {lsp.vim-repo} {vim9ls-repo}" >&2
    exit 1
}

compare_only=0
msg_file=
while getopts nm: opt; do
    case $opt in
        n) compare_only=1 ;;
        m) msg_file=$OPTARG ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))
if [ $# -ne 2 ] || { [ $compare_only -eq 1 ] && [ -n "$msg_file" ]; }; then
    usage
fi
if [ -n "$msg_file" ]; then
    msg_file=$(cd "$(dirname "$msg_file")" && pwd)/$(basename "$msg_file")
fi

lsp_repo=$(cd "$1" && pwd)
vim9ls_repo=$(cd "$2" && pwd)

cd "$(dirname "$0")/.."

# Prints the VERSION of the plugin script on stdin.
version()
{
    sed -n "s/^\(export \)\?const VERSION = '\(.*\)'/\2/p"
}

# head_version {repo} {script with VERSION}
head_version()
{
    (cd "$1" && git show "HEAD:$2") | version
}

# package_version {package} {script with VERSION}
package_version()
{
    version 2>/dev/null < "runtime/pack/dist/opt/$1/$2" || true
}

lsp_version=$(head_version "$lsp_repo" autoload/lsp.vim)
vim9ls_version=$(head_version "$vim9ls_repo" autoload/vim9ls.vim)
old_lsp_version=$(package_version lsp.vim autoload/lsp.vim)
old_vim9ls_version=$(package_version vim9ls autoload/vim9ls.vim)
if [ "$lsp_version" = "$old_lsp_version" ] \
        && [ "$vim9ls_version" = "$old_vim9ls_version" ]; then
    echo "The versions of lsp.vim $lsp_version and vim9ls $vim9ls_version" \
        "are those of the packages, no update is needed"
    exit $compare_only
fi
if [ $compare_only -eq 1 ]; then
    echo "lsp.vim $old_lsp_version -> $lsp_version," \
        "vim9ls $old_vim9ls_version -> $vim9ls_version, an update is needed"
    exit 0
fi

if [ ! -x src/viai ]; then
    echo "src/viai is not there, build ViAI first" >&2
    exit 1
fi
export VIMPROG=$PWD/src/viai VIM=$PWD VIMRUNTIME=$PWD/runtime

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

# check {repo} {package}
check()
{
    if ! (cd "$1" && git diff --quiet HEAD); then
        echo "$2: $1 has changes that are not committed" >&2
        exit 1
    fi
    if ! "$1/test/run" > "$tmp" 2>&1; then
        cat "$tmp"
        echo "$2: the tests failed, nothing was copied" >&2
        exit 1
    fi
    echo "$2: $(tail -n 1 "$tmp")"
}

# sync {repo} {package} {script with VERSION}
sync()
{
    local repo=$1 dir=runtime/pack/dist/opt/$2

    rm -rf "$dir"
    mkdir -p "$dir"
    (cd "$repo" && git archive HEAD -- . ':!.github' ':!.gitignore' \
        ':!README.md' ':!demo' ':!test' ':!tools') | tar -x -C "$dir"
    printf '%s %s %s\n' "$2" "$(version < "$dir/$3")" \
        "$(cd "$repo" && git rev-parse --short=7 HEAD)"
}

check "$lsp_repo" lsp.vim
check "$vim9ls_repo" vim9ls
sync "$lsp_repo" lsp.vim autoload/lsp.vim
sync "$vim9ls_repo" vim9ls autoload/vim9ls.vim

if [ "$vim9ls_version" = "$old_vim9ls_version" ]; then
    problem="bundled lsp.vim is older than $lsp_version"
    prefix="runtime(lsp.vim)"
elif [ "$lsp_version" = "$old_lsp_version" ]; then
    problem="bundled vim9ls is older than $vim9ls_version"
    prefix="runtime(vim9ls)"
else
    problem="bundled lsp.vim and vim9ls are older than $lsp_version"
    problem="$problem and $vim9ls_version"
    prefix="runtime(lsp.vim,vim9ls)"
fi

# wrap {label} {text}: prints {text} after {label}, folded and indented.
wrap()
{
    echo "$2" | fold -s -w 62 | sed -e 's/^ *//' -e 's/ *$//' \
        -e "1s/^/$1/" -e '2,$s/^/          /'
}

message()
{
    echo "$prefix: $problem"
    echo
    wrap "Problem:  " "The $problem."
    wrap "Solution: " "Copy lsp.vim $lsp_version and vim9ls $vim9ls_version."
}

echo
message
if [ -n "$msg_file" ]; then
    message > "$msg_file"
fi
