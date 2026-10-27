#!/bin/bash
# Add the Vim patches imported with a "vim-patch:" token to included_patches[]
# in src/version.c.
#
# Usage: tools/update-included-patches.sh [--check]
#
# Reads the tokens at the start of a line in all commit messages and the lines
# of tools/vim-patch-not-imported.txt.  "partial:" imports are not added.  N/A
# patches are added like imported ones, Declined patches are added as a
# comment ("// 1246,").  Numbers already in the list are kept.
# Prints the changed numbers, one per line: "9.2.1246" for an added number,
# "9.2.1246 declined" for an added comment and "9.2.1246 not declined" for a
# removed comment.  With --check src/version.c is not changed and the exit
# status is 1 when included_patches[] needs a change.

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

# Prints the patch number of a line starting with a "vim-patch:" token.
number='
    function number(line,    rest)
    {
        if (index(line, prefix) != 1)
            return ""
        rest = substr(line, length(prefix) + 1)
        if (rest !~ /^[0-9]+: / || rest ~ /^[0-9]+:partial: /)
            return ""
        sub(/:.*/, "", rest)
        return rest + 0
    }'

git log --format=%B |
    awk -v prefix="vim-patch:$version." "$number"'
        (n = number($0)) != "" { print n }' > "$tmp/imported"

: > "$tmp/declined"
awk -v prefix="vim-patch:$version." -v declined="$tmp/declined" "$number"'
    (n = number($0)) == "" { next }
    / -- N\/A #[0-9]+$/ { print n }
    / -- Declined #[0-9]+$/ { print n > declined }' \
    tools/vim-patch-not-imported.txt >> "$tmp/imported"

awk '
    /^static int included_patches\[\] =/ { in_list = 1; next }
    in_list && /^};/ { exit }
    in_list && /^    [0-9]+,$/ { print $1 + 0 }
    in_list && /^\/\/ [0-9]+,$/ { print $2 + 0 > "/dev/stderr" }' \
    src/version.c > "$tmp/listed" 2> "$tmp/commented"

# Numbers in the first file that are in none of the others.
only_in()
{
    awk 'FILENAME == ARGV[1] { n[$1]; next } { delete n[$1] }
        END { for (i in n) print i }' "$@" | sort -n -u
}

only_in "$tmp/imported" "$tmp/listed" > "$tmp/added"
sort -n -u "$tmp/listed" "$tmp/added" > "$tmp/numbers"
only_in "$tmp/declined" "$tmp/numbers" > "$tmp/comments"
only_in "$tmp/comments" "$tmp/commented" > "$tmp/new_comments"
only_in "$tmp/commented" "$tmp/comments" "$tmp/numbers" > "$tmp/old_comments"

sed "s/^/$version./" "$tmp/added"
sed "s/^\(.*\)/$version.\1 declined/" "$tmp/new_comments"
sed "s/^\(.*\)/$version.\1 not declined/" "$tmp/old_comments"
if [ ! -s "$tmp/added" ] && [ ! -s "$tmp/new_comments" ] &&
        [ ! -s "$tmp/old_comments" ]; then
    exit 0
fi
if [ $check -eq 1 ]; then
    exit 1
fi

sort -n -r -u "$tmp/numbers" "$tmp/comments" > "$tmp/all"
awk -v all="$tmp/all" -v comments="$tmp/comments" '
    BEGIN {
        while ((getline n < comments) > 0)
            comment[n]
    }
    /^static int included_patches\[\] =/ {
        print
        getline
        print
        while ((getline n < all) > 0)
            if (n in comment)
                print "/**/\n// " n ","
            else
                print "/**/\n    " n ","
        print "/**/\n    0"
        skip = 1
        next
    }
    skip && /^};/ { skip = 0 }
    !skip { print }' src/version.c > "$tmp/version.c"
cat "$tmp/version.c" > src/version.c
