#!/usr/bin/env bash
#
# Usage: ./generate.sh path/to/yuhao_joy_v3.6.1-beta.20241025/schema

set -euo pipefail

[ -e zigen-joy.csv ] || curl -O 'https://shurufa.app/zigen-joy.csv'
[ -e yuhao-chaifen.csv ] || curl -o yuhao-chaifen.csv 'https://shurufa.app/chaifen.csv'

# ---> temporary fix, 2024-10-29
sed -i.bak -e 's/^𭁣,一丷冂丨,/𭁣,一丷冂,/' yuhao-chaifen.csv
# <---

./fix-yuhao-chaifen-dict.pl "$1"/yujoy_chaifen{,_tw}.dict.yaml yuhao-chaifen.csv

./analyze-roots-of-yujoy-input-method.pl "$1"/yujoy_chaifen{,_tw}.dict.yaml |
    fgrep -v '～' |
    cut -f2,3 | sort -u -k2 -k1 > roots.tsv

perl -CSDA -Mutf8 -i -pE 's/^({曾中}\s+J)\?/\1r/' roots.tsv

./analyze-yuhao-root-mapping.pl "$1"/yujoy_chaifen.dict.yaml "$1"/yujoy_chaifen_tw.dict.yaml yuhao-chaifen.csv > roots-mapping.tsv 2>roots-mapping-error.txt ||
    { cat roots-mapping-error.txt; exit 1; }

perl -CSDA -lnE 'print "$1.dict.yaml" if (/^import_tables/ .. /^\S(?!mport)/) && /^\s*-\s+(.\S+)/' "$1/yujoy.dict.yaml" |
    sed -e "s|^|$1/|" |
    xargs perl -CSDA -lnE 'print if (/^\.\.\./ .. eof) && !/^\.\.\./ && !/^\s*$/' |
    fgrep -v '～' > mabiao.tsv

perl -CSDA -lnE 'print "$1.dict.yaml" if (/^import_tables/ .. /^\S(?!mport)/) && /^\s*-\s+(.\S+)/' "$1/yujoy_sc.dict.yaml" |
    sed -e "s|^|$1/|" |
    xargs perl -CSDA -lnE 'print if (/^\.\.\./ .. eof) && !/^\.\.\./ && !/^\s*$/' |
    fgrep -v '～' > mabiao_sc.tsv

perl -CSDA -lne 'print "$1\t$2" if (/^\.\.\./ .. eof) && /^(\S+)\s+\[([^,]+)/' "$1"/yujoy_chaifen{,_tw}.dict.yaml |
    fgrep -v '～' |
    sort -u > chaifen.tsv

perl -CSDA -lne 'print "$1\t$2" if (/^\.\.\./ .. eof) && /^(\S+)\s+\[([^,]+)/' "$1/yujoy_chaifen.dict.yaml" |
    fgrep -v '～' |
    sort -u > chaifen_sc.tsv

cp -f "$1/../font/Yuniversus.ttf" .
../scripts/turn-roots-chaifen-mabiao-into-js.pl roots.tsv chaifen_sc.tsv mabiao_sc.tsv > yujoy_sc.js
../scripts/generate-roots-chart.pl -u ../sbfd/ -e yujoy_sc.js -r roots-mapping.tsv -f Yuniversus.ttf \
    -t "宇浩卿雲字根表 v3.6.1-beta.20241025" \
    roots.tsv chaifen_sc.tsv ../top6000.txt > yujoy_sc.html

perl -CSDA -i -pE 's/\r//' *.tsv *.csv
