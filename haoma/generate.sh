#!/usr/bin/env bash
#
# Usage: ./generate.sh path/to/github.com/hertz-hwang/rime-hao

set -euo pipefail

D="${1:-}"

[ -d "$D" ] || {
    echo "Usage: $0 path/to/github.com/hertz-hwang/rime-hao"
    exit 1
}

perl -w -CSDA -lnE '($roots, $codes) = $_ =~ /\(([^,]+),([^,]+)/; @a = $roots =~ /\{[^\}]+\}|\S/g; @c = $codes =~ /[a-zA-Z]{2}/g; if (@a > 4) { @a = @a[0,1,2,$#a] } for (my $i = 0; $i < @a; ++$i) { print "$a[$i]\t$c[$i]" }' "$D/schemas/hao/opencc/hao_div.txt" | LC_ALL=C sort -u > roots.tsv

perl -w -CSDA -lanE '($roots) = $F[1] =~ /\(([^,]+)/; @a = $roots =~ /\{[^\}]+\}|\S/g; if (@a > 4) { @a=@a[0,1,2,$#a] }; print "$F[0]\t", join("", @a)' "$D/schemas/hao/opencc/hao_div.txt" > chaifen.tsv

perl -CSDA -Mutf8 -lanE 'print "$F[0]\t$F[1]" if (/单字开始/ .. /单字结束/) && @F > 1' "$D/schemas/hao/leopard.dict.yaml" > mabiao.tsv

../scripts/turn-roots-chaifen-mabiao-into-js.pl roots.tsv chaifen.tsv mabiao.tsv > haoma.js

../scripts/generate-roots-chart.pl -u ../sbfd/ -e haoma.js -t '豹码(好码)字根表 v20250326' roots.tsv chaifen.tsv ../top6000.txt > haoma-v20250326.html

