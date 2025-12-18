#!/usr/bin/env bash
#
# Usage:
#   cd github.com/forfudan/yu
#   ./check-zigen-changes.sh [path/to/zigen-xxx.csv]

gshow() {
    local commit="$1" file="$2"

    git show "$commit:$file" | perl -CSDA -F, -lanE 'next if $.==1; print "$F[0]\t$F[1]"' | LC_ALL=C sort
}

gdiff() {
    local commit="$1" file="$2"

    diff -U0 <(gshow "$commit~" "$file") <(gshow "$commit" "$file")
}

ZIGEN_CSV="${1:-src/public/zigen-ling.csv}"

echo "$ZIGEN_CSV changes over time:"
echo

git log --format="format:%H %ai" $ZIGEN_CSV |
    while read c d; do
        echo -ne "$c $d\t";
        gdiff $c $ZIGEN_CSV | grep -v '^---' | grep '^-' | wc -l;
    done | grep -v '\s0$'

