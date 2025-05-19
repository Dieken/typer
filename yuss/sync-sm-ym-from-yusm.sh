#!/usr/bin/env bash

set -euo pipefail
shopt -s failglob

perl -CSDA -lE '
     use YAML::PP qw/LoadFile/;
     use autodie;
     my @a = LoadFile(shift);
     my $h = $a[0]->{form}{mapping};
     for (sort { $h->{$a} cmp $h->{$b} || $a cmp $b } keys %$h) {
        print "$_\t", ucfirst($h->{$_});
     }' 星日.yaml > roots.tmp

perl -CSDA -lanE '
     use Unicode::Normalize;
     use autodie;
     BEGIN {
          open my $fh, "../yusm/roots.tsv";
          while (<$fh>) {
               chomp;
               @F=split;
               $h{$F[0]} = NFKD $F[1];
          }
     }
     if (exists $h{$F[0]}) {
          print "$_\t", substr($h{$F[0]}, 1);
     } else {
          print;
     }' roots.tmp > roots2.tmp

[ -e roots.tsv ] && echo "!!! Compare roots2.tmp with roots.tsv" || cp roots2.tmp roots.tsv

echo "!!! Double check roots.tsv for missing sm and ym"

perl -CSDA -lanE '
     print "      - {element: \"$F[0]\", index: 1, keys: [\"", length($F[2]) > 1 ? substr($F[2], 0, 1) : "@", "\"]}";
     print "      - {element: \"$F[0]\", index: 2, keys: [\"", substr($F[2], -1, 1), "\"]}"' roots.tsv > element_constraints.txt

perl -CSDA -lanE '
     print "    \"$F[0]\": \"", lc(substr($F[1], 0, 1)), length($F[2]) == 1 ? "@" : "", $F[2], "\""' roots.tsv > mapping.txt

echo "!!! Merge mapping.txt and element_constraints.txt to 星日.yaml"
