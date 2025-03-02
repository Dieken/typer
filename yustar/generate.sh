#!/usr/bin/env bash
#
# Usage: ./generate.sh path/to/yuhao_star_v3.8.0-beta.20250210/schema

set -euo pipefail

[ -e zigen-star.csv ] || curl -O 'https://shurufa.app/zigen-star.csv'
[ -e yuhao-chaifen.csv ] || curl -o yuhao-chaifen.csv 'https://shurufa.app/chaifen.csv'

./fix-yuhao-chaifen-dict.pl "$1"/yustar_chaifen{,_tw}.dict.yaml yuhao-chaifen.csv
perl -CSDA -Mutf8 -i -pE 's/\{眉上\}/𠃜/g; s/\{乞上\}/𠂉/g; s/\{周框\}/⺆/g' "$1"/yustar_chaifen{,_tw}.dict.yaml yuhao-chaifen.csv

./analyze-roots-of-yustar-input-method.pl "$1"/yustar_chaifen{,_tw}.dict.yaml |
    fgrep -v '～' |
    cut -f2,3 | sort -u -k2 -k1 > roots.tsv

perl -CSDA -Mutf8 -i -pE 's/^({烏上}\s+D)\?/\1w/' roots.tsv

./analyze-yuhao-root-mapping.pl "$1"/yustar_chaifen.dict.yaml "$1"/yustar_chaifen_tw.dict.yaml yuhao-chaifen.csv > roots-mapping.tsv 2>roots-mapping-error.txt ||
    { cat roots-mapping-error.txt; exit 1; }

perl -CSDA -lnE 'print "$1.dict.yaml" if (/^import_tables/ .. /^\S(?!mport)/) && /^\s*-\s+(.\S+)/' "$1/yustar.dict.yaml" |
    sed -e "s|^|$1/|" |
    xargs perl -CSDA -lnE 'print if (/^\.\.\./ .. eof) && !/^\.\.\./ && !/^\s*$/' |
    fgrep -v '～' > mabiao.tsv

perl -CSDA -lnE 'print "$1.dict.yaml" if (/^import_tables/ .. /^\S(?!mport)/) && /^\s*-\s+(.\S+)/' "$1/yustar_sc.dict.yaml" |
    sed -e "s|^|$1/|" |
    xargs perl -CSDA -lnE 'print if (/^\.\.\./ .. eof) && !/^\.\.\./ && !/^\s*$/' |
    fgrep -v '～' > mabiao_sc.tsv

perl -CSDA -lne 'print "$1\t$2" if (/^\.\.\./ .. eof) && /^(\S+)\s+\[([^,]+)/' "$1"/yustar_chaifen{,_tw}.dict.yaml |
    fgrep -v '～' |
    sort -u > chaifen.tsv

perl -CSDA -lne 'print "$1\t$2" if (/^\.\.\./ .. eof) && /^(\S+)\s+\[([^,]+)/' "$1/yustar_chaifen.dict.yaml" |
    fgrep -v '～' |
    sort -u > chaifen_sc.tsv

cp -f "$1/../font/Yuniversus.ttf" .
../scripts/turn-roots-chaifen-mabiao-into-js.pl roots.tsv chaifen_sc.tsv mabiao_sc.tsv > yustar_sc.js
../scripts/generate-roots-chart.pl -u ../sbfd/ -e yustar_sc.js -r roots-mapping.tsv -f Yuniversus.ttf \
    -t "宇浩星陳字根表 v3.8.0-beta.20250210" \
    roots.tsv chaifen_sc.tsv ../top6000.txt > yustar_sc.html

perl -CSDA -i -pE 's/\r//' *.tsv *.csv
