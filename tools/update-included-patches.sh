#!/bin/bash
# Add the Vim patches imported with a "vim-patch:" token to included_patches[]
# in src/version.c.
#
# Usage: tools/update-included-patches.sh [--check]
#
# Reads the tokens at the start of a line in all commit messages, also the
# lines of the commit that lists the N/A patches.  "partial:" imports and
# Declined patches are not added.  Numbers already in the list are kept.
# Prints the added numbers, one per line.  With --check src/version.c is not
# changed and the exit status is 1 when a number is missing.

set -eu

cd "$(dirname "$0")/.."

check=0
if [ $# -eq 1 ] && [ "$1" = "--check" ]; then
    check=1
elif [ $# -ne 0 ]; then
    echo "Usage: $0 [--check]" >&2
    exit 1
fi

version=$(awk '$1 == "#define" { v[$2] = $3 }
    END { print v["VIM_VERSION_MAJOR"] "." v["VIM_VERSION_MINOR"] }' \
    src/version.h)

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

git log --format=%B |
    awk -v prefix="vim-patch:$version." '
        index($0, prefix) != 1 { next }
        / -- Declined: / { next }
        {
            rest = substr($0, length(prefix) + 1)
            if (rest !~ /^[0-9]+: / || rest ~ /^[0-9]+:partial: /)
                next
            sub(/:.*/, "", rest)
            print rest + 0
        }' | sort -n -u > "$tmp/imported"

awk '
    /^static int included_patches\[\] =/ { in_list = 1; next }
    in_list && /^};/ { exit }
    in_list && /^    [0-9]+,$/ { print $1 + 0 }' src/version.c |
    sort -n -u > "$tmp/listed"

awk 'NR == FNR { listed[$1]; next } !($1 in listed)' \
    "$tmp/listed" "$tmp/imported" > "$tmp/added"
sed "s/^/$version./" "$tmp/added"
if [ ! -s "$tmp/added" ]; then
    exit 0
fi
if [ $check -eq 1 ]; then
    exit 1
fi

sort -n -r -u "$tmp/listed" "$tmp/added" > "$tmp/all"
awk -v all="$tmp/all" '
    /^static int included_patches\[\] =/ {
        print
        getline
        print
        while ((getline n < all) > 0)
            print "/**/\n    " n ","
        print "/**/\n    0"
        skip = 1
        next
    }
    skip && /^};/ { skip = 0 }
    !skip { print }' src/version.c > "$tmp/version.c"
cat "$tmp/version.c" > src/version.c
