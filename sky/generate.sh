#!/usr/bin/env bash
#
# Usage: ./generate.sh path/to/天码rime方案 path/to/天码拆分表

set -euo pipefail

perl -CSDA -lnE 'print if (/^\.\.\./ .. eof) && !/^\.\.\./ && !/^\s*$/' "$1/sky.dict.yaml" > mabiao.tsv

perl -CSDA -lanE 'print "$F[0]\t$F[1]"' "$2/字根表.txt" > roots.tsv

perl -CSDA -lnE 's/^\S+\s+//; @a = split; for (@a[1..$#a]) { print "$a[0]\t$_" }' "$2/拆分表.txt" > chaifen.tsv

../scripts/generate-roots-chart.pl -u ../sbfd/ roots.tsv chaifen.tsv ../top6000.txt > sky.html
