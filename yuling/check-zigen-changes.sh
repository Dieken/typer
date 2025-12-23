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

    shift 2
    diff "$@" -U0 <(gshow "$commit~" "$file") <(gshow "$commit" "$file")
}

while getopts "cvh?" opt; do
    case $opt in
    c) COLOR_OPT="--color=always" ;;
    v) VERBOSE=1 ;;
    *) echo "Usage: $0 [OPTIONS] [path/to/zigen-xxx.csv]"
       echo "  -c   Color diff output for verbose mode."
       echo "  -v   Verbose mode."
       echo "  -h   Show help."
       exit 1
   esac
done
shift $(( OPTIND - 1 ))

ZIGEN_CSV="${1:-src/public/zigen-ling.csv}"

echo "$ZIGEN_CSV changes over time:"
echo

git log --format="format:%H %ai" $ZIGEN_CSV |
    while read c d; do
        echo -ne "$c $d\t";
        gdiff $c $ZIGEN_CSV | grep -v '^---' | grep '^-' | wc -l
        [ "$VERBOSE" = 1 ] && gdiff $c $ZIGEN_CSV $COLOR_OPT | grep -Ev '^(---|\+\+\+|@@)' | sed -e 's/^/    /'
    done | grep -v '\s0$'

# vi: ai si et st=4 sts=4 sw=4
