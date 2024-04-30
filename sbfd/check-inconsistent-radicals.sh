#!/usr/bin/env sh

set -euo pipefail

trap "echo; echo Now you can append equal-radicals-1.tsv to equal-radicals.tsv." EXIT

N=${1:-1}

perl -CSDA -lE 'open $fh, "equal-radicals-0.tsv";
    while (<$fh>) {
        next if $. < $ARGV[0];
        chomp;
        print ">>>> $_";
        system("fgrep", "-m", "20", "$_", "inconsistent-radicals.tsv");
        print STDERR $_ if <STDIN> =~ /y/i}' $N 2>equal-radicals-1.tsv
