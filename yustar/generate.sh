#!/usr/bin/env bash
#
# Usage: ./generate.sh path/to/宇浩星陳_v3.4.5-beta.1/schema

set -euo pipefail

curl -s -O 'https://yuhao.forfudan.com/zigen-star.csv'
curl -s -o yuhao-chaifen.csv 'https://yuhao.forfudan.com/chaifen.csv'

./fix-yuhao-chaifen-dict.pl "$1"/yustar_chaifen{,_tw}.dict.yaml yuhao-chaifen.csv

./analyze-roots-of-yustar-input-method.pl "$1"/yustar_chaifen{,_tw}.dict.yaml |
    cut -f2,3 | sort -u -k2 -k1 > roots.tsv

perl -CSDA -Mutf8 -i -pE 's/^({烏上}\s+D)\?/\1w/' roots.tsv

./analyze-yuhao-root-mapping.pl "$1"/yustar_chaifen.dict.yaml "$1"/yustar_chaifen_tw.dict.yaml yuhao-chaifen.csv > roots-mapping.tsv 2>roots-mapping-error.txt ||
    { cat roots-mapping-error.txt; exit 1; }

perl -CSDA -lnE 'print "$1.dict.yaml" if (/^import_tables/ .. /^\S(?!mport)/) && /^\s*-\s+(.\S+)/' "$1/yustar.dict.yaml" |
    sed -e "s|^|$1|" |
    xargs perl -CSDA -lnE 'print if (/^\.\.\./ .. eof) && !/^\.\.\./ && !/^\s*$/' > mabiao.tsv

perl -CSDA -lnE 'print "$1.dict.yaml" if (/^import_tables/ .. /^\S(?!mport)/) && /^\s*-\s+(.\S+)/' "$1/yustar_sc.dict.yaml" |
    sed -e "s|^|$1|" |
    xargs perl -CSDA -lnE 'print if (/^\.\.\./ .. eof) && !/^\.\.\./ && !/^\s*$/' > mabiao_sc.tsv

perl -CSDA -lne 'print "$1\t$2" if (/^\.\.\./ .. eof) && /^(\S+)\s+\[([^,]+)/' "$1"/yustar_chaifen{,_tw}.dict.yaml |
    sort -u > chaifen.tsv

perl -CSDA -lne 'print "$1\t$2" if (/^\.\.\./ .. eof) && /^(\S+)\s+\[([^,]+)/' "$1/yustar_chaifen.dict.yaml" |
    sort -u > chaifen_sc.tsv

../scripts/turn-roots-chaifen-mabiao-into-js.pl roots.tsv chaifen_sc.tsv mabiao_sc.tsv > yustar_sc.js
../scripts/generate-roots-chart.pl -u ../sbfd/ -e yustar_sc.js roots.tsv chaifen_sc.tsv ../top6000.txt > yustar_sc.html
