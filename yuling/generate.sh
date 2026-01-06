#!/usr/bin/env bash

set -euo pipefail
shopt -s failglob

VER="v3.11.0-beta.20260105"

[ -e zigen-ling.csv ] || curl -LO 'https://github.com/forfudan/yu/raw/refs/heads/beta/src/public/zigen-ling.csv'
[ -e mabiao-ling.txt  ] || curl -LO 'https://github.com/forfudan/yu/raw/refs/heads/beta/src/public/mabiao-ling.txt'
[ -e chaifen.csv ] || curl -LO 'https://github.com/forfudan/yu/raw/refs/heads/beta/src/public/chaifen.csv'
[ -e _Yuniversus.woff ] || curl -L -o _Yuniversus.woff 'https://shurufa.app/Yuniversus.woff'

# XXX: temporary fix, 2026-01-06
perl -CSDA -Mutf8 -F, -lapE '
    s/^艹/卄/ unless /Cǎo/;
    s/^卄/艹/ if /Cǎo/;
    s/^(丄.*)/\1 ㊟同上歸併/ unless /歸併/;
    s/\s*🈤不取聲母// if /^甲/ && length($F[1]) > 2;
    s/^([爪巴⺁也习].*)/\1 🈤不取聲母/ unless length($F[1]) > 2 || /不取/;
' zigen-ling.csv > zigen-ling-fixed.csv

perl -CSDA -F, -lanE 'use autodie; use sort "stable";
    BEGIN {
        open $fh, "ling-rhymes.txt";
        our %h = ();
        while (<$fh>) {
            chomp;
            my @a = split /[\s\(\)A-Z]*/;
            for (@a) { $h{$_} = - (1 + scalar keys %h) if length($_) > 0 }
        }
    }
    if ($. == 1) { print; next }
    die "Unknown root: $F[0]\n" unless exists $h{$F[0]};
    $h{$F[0]} = - $h{$F[0]};
    push @a, [$_, @F];
    END {
        for (keys %h) { die "Unknown old root: $_\n" if $h{$_} < 0 }
        @a = sort { substr($a->[2], 0, 1) cmp substr($b->[2], 0, 1) || $h{$a->[1]} <=> $h{$b->[1]} } @a;
        for (@a) { print $_->[0] }
    }
' zigen-ling-fixed.csv > zigen-ling-reordered.csv

perl -CSDA -lnE 'next if $. == 1; @a = split /,/, $_, 3; print join("\t", @a)' zigen-ling-fixed.csv > roots.tsv
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
../scripts/generate-roots-chart.pl -u ../sbfd/ -e yuling_sc.js -f _Yuniversus.woff \
    -t "靈明輸入法字根表 $VER" \
    roots.tsv chaifen_sc.tsv ../top6000.txt > yuling_sc-$VER.html

./htmlize-ling-rhymes.pl --title 灵明输入法字根口诀-$VER > 灵明输入法字根口诀-$VER.html
grep -Eo '<ruby\s+class=.two-letter-root.*?rp>' 灵明输入法字根口诀-$VER.html | sed -E 's/^/WARN: /' >&2 || true

./stat-yuling-roots.pl --no-color > "yuling_sc-stats-$VER.txt"

../scripts/generate-example-chars.pl --skip-root --chaifen chaifen_sc.tsv --mabiao mabiao_sc.tsv > yuling-example-chars-$VER.txt

[ -e pyproject.toml ] || uv init
uv add genanki
uv run anki-zigen.py
mv 灵明字根.apkg 灵明字根-$VER.apkg
