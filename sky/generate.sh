#!/usr/bin/env bash
#
# Usage: ./generate.sh path/to/天码rime方案 path/to/天码拆分表

set -euo pipefail

perl -CSDA -lnE 'print if (/^\.\.\./ .. eof) && !/^\.\.\./ && !/^\s*$/' $1/sky.dict.yaml > mabiao.tsv

cp $2/字根表.txt roots.tsv

perl -CSDA -lpE 's/^\S+\s+//' $2/拆分表.txt > chaifen.tsv
