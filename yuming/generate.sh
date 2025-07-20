#!/usr/bin/env bash
#
# Usage: ./generate.sh path/to/日月輸入法_$VER/schema

set -euo pipefail

VER=v3.10.1

./analyze-roots-of-yuming-input-method.pl "$1"/yuming_chaifen*.dict.yaml > roots.tsv
perl -i -CSDA -Mutf8 -pE 's/^(\{曾中\}.*)/\1i/' roots.tsv

./analyze-roots-encoding-of-yuming.pl > encoding.tsv 2> roots2.tsv
grep ERROR roots2.tsv && echo "ERROR found in roots2.tsv" && exit 1
mv roots2.tsv roots.tsv

sort encoding.tsv |
    perl -CSDA -lanE '
        push @{ $h{$F[0]} }, $F[1];
        END {
            for $k (sort { ($a =~ /[aeuio]/ || 2) <=> ($b =~ /[aeuio]/ || 2) || $a cmp $b } keys %h) {
                $v = $h{$k};
                print "$k\t@$v";
            }
        }' > encoding2.tsv

perl -CSDA -lnE 'print "$1.dict.yaml" if (/^import_tables/ .. /^\S(?!mport)/) && /^\s*-\s+(.\S+)/' "$1/yuming.dict.yaml" |
    sed -e "s|^|$1/|" |
    xargs perl -CSDA -lnE 'print if (/^\.\.\./ .. eof) && !/^\.\.\./ && !/^\s*$/' |
    fgrep -v ' ' |      # 去掉助记简码
    fgrep -v '～' > mabiao.tsv

perl -CSDA -lnE 'print "$1\t$2" if (/^\.\.\./ .. eof) && /^(\S+)\s+\[([^,]+)/' "$1"/yuming_chaifen*.dict.yaml |
    fgrep -v '～' |
    sort -u > chaifen.tsv

cp -f "$1/../fonts/Yuniversus.ttf" .

../scripts/turn-roots-chaifen-mabiao-into-js.pl roots.tsv chaifen.tsv mabiao.tsv > yuming.js

    # 将韵码映射也放入字根表
    cp roots.tsv roots2.tsv
    perl -CSDA -lanE 'print "$F[1]\t", uc($F[0]) if $F[0] =~ /^[aeuio]$/' encoding.tsv >> roots2.tsv

../scripts/generate-roots-chart.pl -u ../sbfd/ -e yuming.js -r roots-mapping.tsv -f Yuniversus.ttf \
    -t "日月输入法字根表 $VER" \
    roots2.tsv chaifen.tsv ../top6000.txt > yuming-$VER.html

    rm roots2.tsv

perl -CSDA -lanE '$ok=1 if /^\.\.\./; next unless $ok; print "$F[1]\t$F[0]" if length($F[0]) == 1 && length($F[1]) <= 2 && $F[1] =~ /^\S?[aeuio]$/' "$1"/yuhao/yuming.quick.dict.yaml |
    grep -v '^/' |
    fgrep -v ' ' |      # 去掉助记简码
    fgrep -v '～' > dazhu.txt

perl -CSDA -lanE '$ok=1 if /^\.\.\./; next unless $ok; print "$F[1]\t$F[0]" if $F[1] =~ /^[a-z]+$/' "$1"/yuhao/yuming.full.dict.yaml |
    grep -v '^/' |
    fgrep -v ' ' |      # 去掉助记简码
    fgrep -v '～' >> dazhu.txt
