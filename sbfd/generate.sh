#!/usr/bin/env sh
#
# Usage: ./analyze.sh path/to/github.com/sbsrf/sbsrf/

set -euo pipefail

perl -CSDA -lE 'use autodie;
     open $fh, "$ARGV[0]/sbxlm/lua/sbxlm/radicals.txt";
     while (<$fh>) {
         @a = split;
         $h{$a[0]} = $a[1];
     }
     close $fh;
     undef $fh;

     open $fh, "$ARGV[0]/sbxlm/sbfd.dict.yaml";
     while (<$fh>) {
         next unless /^(\S)\s++\S++\s++\d++\s++[^aeuio]([^aeuio])/;
         say "$1\t$h{$1}\t$2";
    }
    close $fh;
' "$1" | cut -f 2,3 | sort -u -k2 -k1 > roots.tsv

cp "$1/sbxlm/lua/sbxlm/radicals.txt" chaifen.tsv

perl -CSDA -lnE "print if /^\S\s+[a-z0-9']+\$/" "$1/sbxlm/sbf.dict.yaml" > mabiao.tsv

perl -CSDA -lnE 'next unless /^(\S)\s++(\S++)\s++\d++\s++(\S+)/; say "$1\t$2"' "$1/sbxlm/sbfd.dict.yaml" >> mabiao.tsv


[ -f CJKRadicals.txt ] || curl -LO 'https://www.unicode.org/Public/UCD/latest/ucd/CJKRadicals.txt'
[ -f Unihan.zip ] || curl -LO 'https://www.unicode.org/Public/UCD/latest/ucd/Unihan.zip'
unzip -oq Unihan.zip

perl -CSDA -lE 'use autodie;
    open $fh, "CJKRadicals.txt";
    while (<$fh>) {
        next if /^\s*+(?:#.*)?$/;
        next unless /^(\d+).*;\s+(\S+)\s*$/;
        $h[$1] = chr(hex($2));
    }
    close $fh;
    undef $fh;

    open $fh, "Unihan_IRGSources.txt";
    while (<$fh>) {
        @a = $_ =~ /^U\+(\S+)\s+kRSUnicode(\s.*)$/;
        next unless @a;
        @b = $a[1] =~ /\s(\d+)/g;
        say chr(hex($a[0])), map { "\t$h[$_]" } @b;
    }
    close $fh;
' > Unihan-radicals.tsv

touch equal-radicals.tsv
perl -CSDA -lE 'use autodie; use utf8; use List::Util qw(any);
     open $fh, "Unihan-radicals.tsv";
     while (<$fh>) {
        my @a = split;
        $a = shift @a;
        $h{$a} = \@a;
    }
    close $fh;
    undef $fh;

    open $fh, "equal-radicals.tsv";
    while (<$fh>) {
        my @a = split;
        $h2{$a[0]}{$a[1]} = 1;
    }
    close $fh;
    undef $fh;

    open $fh, "chaifen.tsv";
    while (<$fh>) {
        my @a = split;
        next if $a[1] =~ /^[乛一丿丨丶]$/;

        say join("\t", @a, @{ $h{$a[0]} }) unless any { $_ eq $a[1] or $h2{$a[1]}{$_} } @{ $h{$a[0]} };
    }
    close $fh
' > inconsistent-radicals.tsv

perl -CSDA -lanE 'for (@F[2..$#F]) { say "$F[0]\t$F[1]\t$_" }' inconsistent-radicals.tsv |
    cut -f 2,3 | sort | uniq -c | sort -k1,1nr |
    perl -CSDA -lanE 'print "$F[1]\t$F[2]"' > equal-radicals-0.tsv
