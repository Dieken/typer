#!/usr/bin/env bash
#
# Usage: ./generate.sh path/to/github.com/siuze/ShanrenMaLTS

set -euo pipefail

perl -CSDA -Mutf8 -F'\t' -lanE 'next if $. == 1; $F[0] = $F[4] || $F[5] if $F[3] eq "私用区"; print "$F[0]\t$F[1]\t$F[2]"' $1/src/data/字根码表.csv| sort -u > roots.tsv

perl -CSDA -Mutf8 -F'\t' -lanE '
    BEGIN {
        open my $fh, $ARGV[0] or die $!;
        while (<$fh>) {
            next if $. == 1;
            my @F = split /\t/;
            $h{$F[0]} = $F[4] || $F[5] if $F[3] eq "私用区"
        }
        close $fh;
        shift @ARGV;
    }

    next if $. == 1;
    @a = split /\t/;
    $a[1] = join "", map { exists $h{$_} ? $h{$_} : $_ } split //, $a[1];
    print "$a[0]\t$a[1]";
    close ARGV if eof;
' "$1/src/data/字根码表.csv" "$1/src/data/单字表.csv" "$1/src/data/兼容拆分表.csv" > chaifen.tsv
