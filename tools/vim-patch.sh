#!/bin/bash
# Import one Vim commit into ViAI on a new branch "vim-patch-<hash>".
#
# Usage: tools/vim-patch.sh [-n] <Vim commit hash>
#
# Creates in $VIM_PATCH_DIR (default: .git/vim-patch of the ViAI repository):
#   <hash>.patch    the Vim commit without its Signed-off-by lines
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

    git format-patch -1 --stdout "$full" | sed '/^Signed-off-by: /d' \
        > "$patch_file"

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

    # "git am -3" needs the blobs the patch applies to, ViAI has no Vim
    # history.
    git -C "$VIM_REPO" show --format= --raw --no-abbrev "$full" |
        awk '$3 !~ /^0+$/ { print $3 }' |
        while read -r blob; do
            git -C "$VIM_REPO" cat-file blob "$blob" |
                git hash-object -w --stdin > /dev/null
        done

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
