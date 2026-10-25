#!/bin/bash
# Import one Vim commit into ViAI on a new branch "vim-patch-<hash>".
#
# Usage: tools/vim-patch.sh [-n] <Vim commit hash>
#
# Creates in $VIM_PATCH_DIR (default: .git/vim-patch of the ViAI repository):
#   <hash>.patch    the Vim commit without its Signed-off-by lines and
#                   without its number in included_patches[]
#   <hash>.msg      the commit message used in ViAI
#   <hash>.pr.txt   the pull request description (the same message)
# With -n only these files are created, no branch or commit.  Stops before
# "git push"; check the commit first.  When the patch does not apply,
# "git am -3" leaves conflict markers and the remaining commands are printed.
#
# $VIAI_REPO is the ViAI repository (default: the one containing this
# script), $VIM_REPO the Vim repository (default: "vim" next to it).

set -eu

# Everything is in a function, called together with "exit" on the last line,
# so that bash has read the whole script before "git switch" below changes it
# in the working tree.
main() {
    VIAI_REPO=${VIAI_REPO:-$(cd "$(dirname "$0")/.." && pwd)}
    VIM_REPO=${VIM_REPO:-$VIAI_REPO/../vim}
    OUT_DIR=${VIM_PATCH_DIR:-$(git -C "$VIAI_REPO" rev-parse \
        --absolute-git-dir)/vim-patch}
    mkdir -p "$OUT_DIR"

    dry_run=0
    if [ $# -eq 2 ] && [ "$1" = "-n" ]; then
        dry_run=1
        shift
    fi
    if [ $# -ne 1 ]; then
        echo "Usage: $0 [-n] <Vim commit hash>" >&2
        exit 1
    fi

    cd "$VIM_REPO"
    full=$(git rev-parse --verify "$1^{commit}")
    short=${full:0:7}
    subject=$(git log -1 --format=%s "$full")
    author="$(git log -1 --format='%an <%ae>' "$full")"
    author_email=$(git log -1 --format=%ae "$full")
    body=$(git log -1 --format=%b "$full")

    patch_file=$OUT_DIR/$short.patch
    msg_file=$OUT_DIR/$short.msg
    pr_file=$OUT_DIR/$short.pr.txt
    branch=vim-patch-$short

    # "git am -3" needs the blobs the patch applies to, ViAI has no Vim
    # history.  In ViAI the header of a help file names ViAI instead of Vim:
    # the version in the first line and the title, without an author, in the
    # third or fourth line.  The header is changed in these blobs and in the
    # patch alike, so that the patch applies, also with a 3-way merge.
    viai_version=$(awk '$1 == "#define" { v[$2] = $3 }
        END { print v["VIAI_VERSION_MAJOR"] "." v["VIAI_VERSION_MINOR"] }' \
        "$VIAI_REPO/src/version.h")
    fix_header='
        function fix_header(s) {
            if (s ~ /^\*[^*]+\*[ \t]+For Vim version [0-9]+\.[0-9]+\./)
                sub(/Vim version [0-9]+\.[0-9]+\./,
                    "ViAI version " ver ".", s)
            else if (s ~ /^[ \t]+VIM (REFERENCE|USER) MANUAL/) {
                sub(/VIM/, "VIAI", s)
                sub(/[ \t]+by .*/, "", s)
            } else if (s ~ /^[ \t]+VIM - main help file$/)
                sub(/VIM/, "VIAI", s)
            return s
        }'
    # Vim adds the patch number to included_patches[] next to the number of
    # the patch before it, thus the patch would not apply without that patch.
    # The hunk is left out, tools/update-included-patches.sh adds the number
    # after the merge.
    drop_patch_number='
        function end_hunk(  i) {
            if (number_only)
                dropped++
            else {
                if (has_number)
                    print "src/version.c: a hunk adds the patch number " \
                        "and changes other lines, it is kept" > "/dev/stderr"
                for (i = 0; i < nhunk; i++)
                    file[nfile++] = hunk[i]
                kept++
            }
            nhunk = 0
            in_hunk = 0
        }
        function end_file(  i) {
            if (kept > 0 || dropped == 0)
                for (i = 0; i < nfile; i++)
                    print file[i]
            nfile = 0
            in_file = 0
        }
        in_hunk {
            hunk[nhunk++] = $0
            c = substr($0, 1, 1)
            if (c == "+" && $0 ~ /^\+(\/\*\*\/|    [0-9]+,)$/)
                has_number = 1
            else if (c == "+" || c == "-")
                number_only = 0
            if (c == " " || c == "-")
                old_left--
            if (c == " " || c == "+")
                new_left--
            if (old_left <= 0 && new_left <= 0)
                end_hunk()
            next
        }
        in_file && /^@@ / {
            old_left = split($2, o, ",") > 1 ? o[2] : 1
            new_left = split($3, n, ",") > 1 ? n[2] : 1
            hunk[0] = $0
            nhunk = 1
            in_hunk = 1
            number_only = 1
            has_number = 0
            seen_hunk = 1
            next
        }
        in_file && !seen_hunk && !/^diff --git / {
            file[nfile++] = $0
            next
        }
        in_file {
            end_file()
        }
        $0 == "diff --git a/src/version.c b/src/version.c" {
            in_file = 1
            seen_hunk = 0
            kept = 0
            dropped = 0
            file[nfile++] = $0
            next
        }
        { print }
        END {
            if (in_file)
                end_file()
        }'
    blob_map=$OUT_DIR/$short.blobs
    : > "$blob_map"
    git show --format= --raw --no-abbrev "$full" |
        while read -r _ _ old new _ path; do
            for blob in "$old" "$new"; do
                case $blob in
                    *[!0]*) ;;
                    *) continue ;;
                esac
                case $path in
                    runtime/doc/*/*) is_help=0 ;;
                    runtime/doc/*.txt) is_help=1 ;;
                    *) is_help=0 ;;
                esac
                if [ $is_help -eq 0 ]; then
                    git cat-file blob "$blob" |
                        git -C "$VIAI_REPO" hash-object -w --stdin > /dev/null
                    continue
                fi
                fixed=$(git cat-file blob "$blob" |
                    awk -v ver="$viai_version" "$fix_header"'
                        NR <= 4 { $0 = fix_header($0) }
                        { print }' |
                    git -C "$VIAI_REPO" hash-object -w --stdin)
                if [ "$fixed" != "$blob" ]; then
                    echo "$blob $fixed" >> "$blob_map"
                fi
            done
        done

    git format-patch -1 --full-index --stdout "$full" |
        sed '/^Signed-off-by: /d' |
        awk -v map="$blob_map" -v ver="$viai_version" "$fix_header"'
            BEGIN {
                while ((getline line < map) > 0) {
                    split(line, f, " ")
                    fixed[f[1]] = f[2]
                }
            }
            /^diff --git / {
                help = $3 ~ /^a\/runtime\/doc\/[^\/]+\.txt$/
                in_hunk = 0
                print
                next
            }
            help && /^index / {
                split($2, h, /\.\./)
                if (h[1] in fixed)
                    h[1] = fixed[h[1]]
                if (h[2] in fixed)
                    h[2] = fixed[h[2]]
                sub(/^index [^ ]+/, "index " h[1] ".." h[2])
                print
                next
            }
            help && /^@@ / {
                split($2, o, ",")
                split($3, n, ",")
                old_lnum = -o[1]
                new_lnum = n[1] + 0
                in_hunk = 1
                print
                next
            }
            help && in_hunk && /^[-+ ]/ {
                c = substr($0, 1, 1)
                lnum = c == "+" ? new_lnum : old_lnum
                if (lnum <= 4)
                    $0 = c fix_header(substr($0, 2))
                if (c != "+")
                    old_lnum++
                if (c != "-")
                    new_lnum++
                print
                next
            }
            { print }' | awk "$drop_patch_number" > "$patch_file"
    rm -f "$blob_map"

    case $subject in
        "patch "[0-9]*": "*)
            num=${subject#patch }
            num=${num%%: *}
            new_subject="vim-patch:$num: ${subject#patch $num: }"
            ;;
        *)
            new_subject="vim-patch:$short: $subject"
            ;;
    esac

    cd "$VIAI_REPO"
    my_email=$(git config user.email)
    if [ "$author_email" = "$my_email" ]; then
        author=""
    fi

    if [ $dry_run -eq 0 ]; then
        if ! git diff --quiet HEAD; then
            echo "$VIAI_REPO has uncommitted changes" >&2
            exit 1
        fi
        if git rev-parse --verify -q "refs/heads/$branch" > /dev/null; then
            echo "Branch $branch already exists" >&2
            exit 1
        fi
    fi

    # Message layout: subject, prose, URL, fixes/related/closes, then
    # Co-authored-by (Vim author first) and Assisted-by (only from Vim).
    {
        echo "$new_subject"
        echo
        printf '%s\n' "$body" | awk \
                -v url="https://github.com/vim/vim/commit/$full" \
                -v author="$author" '
            { lc = tolower($0) }
            lc ~ /^signed-off-by: / { next }
            lc ~ /^(fixes|related|closes): / {
                gsub(/ #/, " vim/vim#")
                refs[nrefs++] = $0
                next
            }
            lc ~ /^co-authored-by: / { coauth[ncoauth++] = $0; next }
            lc ~ /^assisted-by: / { assist[nassist++] = $0; next }
            { prose[nprose++] = $0 }
            END {
                while (nprose > 0 && prose[nprose - 1] == "")
                    nprose--
                for (i = 0; i < nprose; i++)
                    print prose[i]
                if (nprose > 0)
                    print ""
                print url
                print ""
                for (i = 0; i < nrefs; i++)
                    print refs[i]
                if (nrefs > 0)
                    print ""
                if (author != "")
                    print "Co-authored-by: " author
                for (i = 0; i < ncoauth; i++)
                    print coauth[i]
                for (i = 0; i < nassist; i++)
                    print assist[i]
            }'
    } > "$msg_file"

    cp "$msg_file" "$pr_file"

    if [ $dry_run -eq 1 ]; then
        cat "$msg_file"
        exit 0
    fi

    git switch -c "$branch" master
    if ! git am -3 -s "$patch_file"; then
        echo >&2
        echo "git am failed.  Resolve the conflicts, then:" >&2
        echo "  git add -u" >&2
        echo "  git am --continue" >&2
        echo "  git commit --amend --reset-author -s -F $msg_file" >&2
        echo "  git log --format='%an <%ae>%n%n%B' -1" >&2
        echo "  git push -u origin $branch" >&2
        echo "To undo:" >&2
        echo "  git am --abort" >&2
        echo "  git switch master" >&2
        echo "  git branch -D $branch" >&2
        exit 1
    fi
    git commit --amend --reset-author -s -F "$msg_file"

    echo
    git log --format='%an <%ae>%n%n%B' -1
    echo "PR title: $new_subject"
    echo "PR description: $pr_file"
    echo "Next:"
    echo "  git push -u origin $branch"
    echo "  https://github.com/viai-editor/viai/compare/master...h-east:viai:$branch"
}

main "$@"; exit
