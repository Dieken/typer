#!/usr/bin/env sh

[ -e zigen-ling.csv ] || curl -O 'https://88d6cb5c.yuhaoim.pages.dev/zigen-ling.csv'
[ -e chaifen.json ] || {
    curl -o chaifen.json.gz 'https://88d6cb5c.yuhaoim.pages.dev/chaifen.json'
    gunzip chaifen.json.gz
}

perl -CSDA -lnE '@a = split /,/, $_, 3; print join("\t", @a)' zigen-ling.csv > roots.tsv

jq -r 'to_entries[] | "\(.key)\t\(.value.d)"' chaifen.json > chaifen.tsv

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
' chaifen.tsv > mabiao.tsv
