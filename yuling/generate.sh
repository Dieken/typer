#!/usr/bin/env bash

set -euo pipefail
shopt -s failglob

VER="v3.11.0-beta.20260104"

[ -e zigen-ling.csv ] || curl -LO 'https://github.com/forfudan/yu/raw/refs/heads/beta/src/public/zigen-ling.csv'
[ -e mabiao-ling.txt  ] || curl -LO 'https://github.com/forfudan/yu/raw/refs/heads/beta/src/public/mabiao-ling.txt'
[ -e chaifen.csv ] || curl -LO 'https://github.com/forfudan/yu/raw/refs/heads/beta/src/public/chaifen.csv'
[ -e _Yuniversus.woff ] || curl -L -o _Yuniversus.woff 'https://shurufa.app/Yuniversus.woff'

perl -CSDA -lnE 'next if $. == 1; @a = split /,/, $_, 3; print join("\t", @a)' zigen-ling.csv > roots.tsv
perl -CSDA -F, -lanE 'next if $. == 1; print join("\t", $F[0], $F[1])' chaifen.csv | grep -v '～' > chaifen_sc.tsv

perl -CSDA -Mautodie -lanE '
     BEGIN {
        open $fh, "roots.tsv";
        while (<$fh>) {
            @a = split;
            $h{$a[0]} = $a[1];
        }
    }

    @r = map { $h{$_} } split //, $F[1];
    $c = @r == 1 ? $r[0] : length($r[0]) == 3 ? substr($r[0], 0, 2) : substr($r[0], 0, 1);
    for ($i = 1; $i < @r; ++$i) {
        next if $i == 2 && length($r[0]) == 3 && @r >= 4;
        $c .= $i < $#r ? substr($r[$i], 0, 1) : $r[$i];
    }

    print $F[0], "\t", substr($c, 0, 4);
' chaifen_sc.tsv > mabiao_sc.tsv

grep -v '^/' mabiao-ling.txt | tac | perl -CSDA -F'\t' -lanE 'next if length($F[1]) > 1 || $h{$F[1]}; $h{$F[1]} = 1; print' | tac  > dazhu-ling-full.txt
echo -e "ver\t靈明輸入法-$VER" >> dazhu-ling-full.txt

../scripts/turn-roots-chaifen-mabiao-into-js.pl roots.tsv chaifen_sc.tsv mabiao_sc.tsv > yuling_sc.js
../scripts/generate-roots-chart.pl -u ../sbfd/ -e yuling_sc.js -f ../yustar/Yuniversus.ttf \
    -t "靈明輸入法字根表 $VER" \
    roots.tsv chaifen_sc.tsv ../top6000.txt > yuling_sc-$VER.html

./stat-yuling-roots.pl --no-color > "yuling_sc-stats-$VER.txt"

../scripts/generate-example-chars.pl --skip-root --chaifen chaifen_sc.tsv --mabiao mabiao_sc.tsv > yuling-example-chars-$VER.txt

[ -e pyproject.toml ] || uv init
uv add genanki
uv run anki-zigen.py
mv 灵明字根.apkg 灵明字根-$VER.apkg
