#!/usr/bin/env bash
#
# Usage: ./generate.sh path/to/宇浩星陳_v3.4.5-beta.1/schema

set -euo pipefail

./analyze-roots-of-yustar-input-method.pl "$1"/yustar_chaifen*.dict.yaml | cut -f2,3 | sort -u -k2 -k1 > roots.tsv

perl -CSDA -Mutf8 -i -pE 's/^({烏上}\s+D)\?/\1w/' roots.tsv

curl -s 'https://521github.com/extdomains/raw.githubusercontent.com/forFudan/yu/main/src/public/zigen-star.csv' |
    perl -CSDA -lnE 'next if $. == 1; s/,/\t/; print' | sort -k2 -k1 > zigen-star.tsv

perl -CSDA -lnE 'print "$1.dict.yaml" if (/^import_tables/ .. /^\S(?!mport)/) && /^\s*-\s+(.\S+)/' "$1/yustar.dict.yaml" |
    sed -e "s|^|$1|" |
    xargs perl -CSDA -lnE 'print if (/^\.\.\./ .. eof) && !/^\.\.\./ && !/^\s*$/' > mabiao.tsv

perl -CSDA -lne 'print "$1\t$2" if (/^\.\.\./ .. eof) && /^(\S+)\s+\[([^,]+)/' "$1"/yustar_chaifen*.dict.yaml |
    sort -u > chaifen.tsv

perl -CSDA -lne 'print "$1\t$2" if (/^\.\.\./ .. eof) && /^(\S+)\s+\[([^,]+)/' "$1/yustar_chaifen.dict.yaml" |
    sort -u > chaifen_sc.tsv

../scripts/generate-roots-chart.pl -u ../sbfd/ roots.tsv chaifen_sc.tsv ../top6000.txt > yustar.html
