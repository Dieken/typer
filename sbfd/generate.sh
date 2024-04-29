#!/usr/bin/env sh
#
# Usage: ./analyze.sh path/to/github.com/sbsrf/sbsrf/

set -euo pipefail

perl -CSDA -lE 'use autodie;
     open $fh, "$ARGV[0]/sbxlm/lua/sbxlm/radicals.txt";
     while (<$fh>) {
         chomp;
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

perl -CSDA -lnE "print if /^\S\s+[a-z0-9']+\$/" $1/sbxlm/sbf.dict.yaml > mabiao.tsv

perl -CSDA -lnE 'next unless /^(\S)\s++(\S++)\s++\d++\s++(\S+)/; say "$1\t$2"' "$1/sbxlm/sbfd.dict.yaml" >> mabiao.tsv
