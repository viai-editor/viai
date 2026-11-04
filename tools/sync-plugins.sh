#!/bin/bash
# Copy lsp.vim and vim9ls into runtime/pack/dist/opt/.
#
# Usage: tools/sync-plugins.sh {lsp.vim-repo} {vim9ls-repo}
#
# Each argument is a git clone of https://github.com/h-east/lsp.vim or
# https://github.com/h-east/vim9ls.  The files committed at its HEAD replace
# the package directory, except those only needed to develop the plugin.
# Nothing is done when the version of neither plugin differs from the one in
# its package.  Nothing is copied unless the tracked files of both clones are
# as committed and their tests pass with src/viai, which has to be built.
# Prints the test results, and the version and the commit of each plugin.

set -eu

if [ $# -ne 2 ]; then
    echo "Usage: $0 {lsp.vim-repo} {vim9ls-repo}" >&2
    exit 1
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
if [ "$lsp_version" = "$(package_version lsp.vim autoload/lsp.vim)" ] \
        && [ "$vim9ls_version" = \
            "$(package_version vim9ls autoload/vim9ls.vim)" ]; then
    echo "The versions of lsp.vim $lsp_version and vim9ls $vim9ls_version" \
        "are those of the packages, no update is needed"
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
