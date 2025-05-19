#!/usr/bin/env bash
#
# Usage: ./generate.sh path/to/宇浩日月_v3.9.0-beta.20250518/schema

set -euo pipefail

./analyze-roots-of-yusm-input-method.pl "$1"/yusm_chaifen*.dict.yaml > roots.tsv
perl -i -CSDA -Mutf8 -pE 's/^(\{曾中\}.*)/\1ⓘ/' roots.tsv

./analyze-roots-encoding-of-yusm.pl > encoding.tsv 2> roots2.tsv
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

perl -CSDA -lnE 'print "$1.dict.yaml" if (/^import_tables/ .. /^\S(?!mport)/) && /^\s*-\s+(.\S+)/' "$1/yusm_sc.dict.yaml" |
    sed -e "s|^|$1/|" |
    xargs perl -CSDA -lnE 'print if (/^\.\.\./ .. eof) && !/^\.\.\./ && !/^\s*$/' |
    fgrep -v ' ' |      # 去掉助记简码
    fgrep -v '～' > mabiao.tsv

perl -CSDA -lnE 'print "$1\t$2" if (/^\.\.\./ .. eof) && /^(\S+)\s+\[([^,]+)/' "$1"/yusm_chaifen*.dict.yaml |
    fgrep -v '～' |
    sort -u > chaifen.tsv

../scripts/turn-roots-chaifen-mabiao-into-js.pl roots.tsv chaifen.tsv mabiao.tsv > yusm.js

../scripts/generate-roots-chart.pl -u ../sbfd/ -e yusm.js \
    -t "宇浩日月字根表 v3.9.0-beta.20250518" \
    roots.tsv chaifen.tsv ../top6000.txt > yusm-v3.9.0-beta.20250518.html

perl -CSDA -lanE '$ok=1 if /^\.\.\./; next unless $ok; print "$F[1]\t$F[0]" if $F[1] =~ /^\S?[aeuio]$/' "$1"/yuhao/yusm_sc.short.dict.yaml |
    grep -v '^/' |
    fgrep -v ' ' |      # 去掉助记简码
    fgrep -v '～' > dazhu.txt

perl -CSDA -lanE '$ok=1 if /^\.\.\./; next unless $ok; print "$F[1]\t$F[0]" if $F[1] =~ /^[a-z]+$/' "$1"/yuhao/yusm.full.dict.yaml |
    grep -v '^/' |
    fgrep -v ' ' |      # 去掉助记简码
    fgrep -v '～' >> dazhu.txt
