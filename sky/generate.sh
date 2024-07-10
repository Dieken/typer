#!/usr/bin/env bash
#
# Usage: ./generate.sh path/to/天码rime方案 path/to/天码拆分表

set -euo pipefail

# http://soongsky.com/sky/root.php
[ -e sky.woff ] || curl -O http://soongsky.com/css/sky.woff
[ -e root.js ] || curl -O http://soongsky.com/sky/java/root.js
perl -i -CSDA -lnE 'print unless /^\s*\/\*/ .. /^\s*\*\//' root.js

# http://soongsky.com/sky/lookup.php
[ -e code.js ] || curl -O http://soongsky.com/sky/java/code.js

./analyze-sky-root-mapping.pl code.js "$2/拆分表.txt" > roots-mapping-0.tsv 2> roots-mapping-error.txt
perl -CSDA -lanE 'next unless /^{/; if (! exists $h{$F[0]}) { print; $h{$F[0]} = $F[1]; }' roots-mapping-0.tsv > roots-mapping.tsv

# dirty fix:
perl -Mutf8 -CSDA -i -lpE 'if (/^\{邦左\}\s+(\S+)/) { print "{寿上}\t$1"; } if (/^\{寿上\}\s+(\S+)/) { print "{邦左}\t$1"; }' roots-mapping.tsv

perl -CSDA -lnE 's/,\S+//; print if (/^\.\.\./ .. eof) && !/^\.\.\./ && !/^\s*$/' "$1/sky.dict.yaml" > mabiao.tsv

perl -CSDA -lanE 'print "$F[0]\t$F[1]"' "$2/字根表.txt" > roots.tsv

perl -CSDA -lnE 's/^\S+\s+//; @a = split; for (@a[1..$#a]) { print "$a[0]\t$_" }' "$2/拆分表.txt" > chaifen.tsv

../scripts/turn-roots-chaifen-mabiao-into-js.pl roots.tsv chaifen.tsv mabiao.tsv > sky.js
../scripts/generate-roots-chart.pl -u ../sbfd/ -e sky.js -r roots-mapping.tsv -f sky.woff \
    -t "天码字根表 v20240710" \
    roots.tsv chaifen.tsv ../top6000.txt > sky.html

perl -CSDA -i -pE 's/\r//' *.tsv
