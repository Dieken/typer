#!/usr/bin/env bash
#
# Usage: ./generate.sh "path/to/虎码秃版 中州韵 （Linux UOS）"

set -euo pipefail

./analyze-roots-of-tiger-input-method.pl "$1/opencc/hu_cf.txt" | cut -f2,3 | sort -u -k2 -k1 > roots.tsv

perl -CSDA -lnE 'print if (/^\.\.\./ .. eof) && !/^\.\.\./ && !/^\s*$/' "$1/tiger.dict.yaml" > mabiao.tsv

perl -CSDA -lne 'print "$1\t$2" if /^(\S+)\s+.([^&]+)/' "$1/opencc/hu_cf.txt" |
    sort -u > chaifen.tsv

perl -CSDA -lanE '$a = $F[0]; next if exists $h{$a}; $h{$a} = 1; push @a, $a; if (@a == 6000) { print join("\n", @a); last }' mabiao.tsv > ../top6000.txt
