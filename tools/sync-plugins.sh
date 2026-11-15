#!/bin/bash
# Copy lsp.vim, vim9ls and viai.mcp into runtime/pack/dist/opt/.
#
# Usage: tools/sync-plugins.sh [-n | -m {file}] {lsp.vim-repo} {vim9ls-repo}
#		{viai.mcp-repo}
#
# Each argument is a git clone of https://github.com/h-east/lsp.vim,
# https://github.com/h-east/vim9ls or https://github.com/viai-editor/viai.mcp.
# The files committed at its HEAD replace the package directory, except those
# only needed to develop the plugin.  Nothing is done when the versions of
# all plugins are those of their packages.  Nothing is copied unless the
# tracked files of all clones are as committed and their tests pass with
# src/viai, which has to be built.
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
    echo "Usage: $0 [-n | -m {file}] {lsp.vim-repo} {vim9ls-repo}" \
        "{viai.mcp-repo}" >&2
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
if [ $# -ne 3 ] || { [ $compare_only -eq 1 ] && [ -n "$msg_file" ]; }; then
    usage
fi
if [ -n "$msg_file" ]; then
    msg_file=$(cd "$(dirname "$msg_file")" && pwd)/$(basename "$msg_file")
fi

# The package of each plugin and its script with VERSION.
packages=(lsp.vim vim9ls viai.mcp)
scripts=(autoload/lsp.vim autoload/vim9ls.vim autoload/viaimcp.vim)
repos=()
for arg in "$@"; do
    repos+=("$(cd "$arg" && pwd)")
done

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

# join {item}...: prints "a", "a and b" or "a, b and c".
join()
{
    local out=$1
    shift
    while [ $# -gt 1 ]; do
        out="$out, $1"
        shift
    done
    if [ $# -eq 1 ]; then
        out="$out and $1"
    fi
    echo "$out"
}

all=()
changed=()
changed_versions=()
updates=()
for i in "${!packages[@]}"; do
    new=$(head_version "${repos[i]}" "${scripts[i]}")
    old=$(package_version "${packages[i]}" "${scripts[i]}")
    all+=("${packages[i]} $new")
    if [ "$new" != "$old" ]; then
        changed+=("${packages[i]}")
        changed_versions+=("$new")
        updates+=("${packages[i]} $old -> $new")
    fi
done
if [ ${#changed[@]} -eq 0 ]; then
    echo "The versions of $(join "${all[@]}") are those of the packages," \
        "no update is needed"
    exit $compare_only
fi
if [ $compare_only -eq 1 ]; then
    echo "$(join "${updates[@]}"), an update is needed"
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

for i in "${!packages[@]}"; do
    check "${repos[i]}" "${packages[i]}"
done
for i in "${!packages[@]}"; do
    sync "${repos[i]}" "${packages[i]}" "${scripts[i]}"
done

if [ ${#changed[@]} -eq 1 ]; then
    problem="bundled ${changed[0]} is older than ${changed_versions[0]}"
else
    problem="bundled $(join "${changed[@]}") are older than"
    problem="$problem $(join "${changed_versions[@]}")"
fi
prefix="runtime($(IFS=,; echo "${changed[*]}"))"

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
    wrap "Solution: " "Copy $(join "${all[@]}")."
}

echo
message
if [ -n "$msg_file" ]; then
    message > "$msg_file"
fi
