#!/usr/bin/env perl
#
# 检查码表的性能，如单手打字
#
# Usage:
#   ./scripts/check-code-performance.pl PATH-TO-RIME.dict.yaml

# https://perldoc.perl.org/perluniintro#Perl's-Unicode-Support  v5.28
# https://perldoc.perl.org/feature#The-'signatures'-feature     v5.36
# https://perldoc.perl.org/perlunicook#℞-0:-Standard-preamble   v5.36

use v5.36;                              # or later to get "unicode_strings" feature, plus strict and warnings
use utf8;                               # so literals and identifiers can be in UTF-8
use warnings qw(FATAL utf8);            # fatalize encoding glitches
use open     qw(:std :encoding(UTF-8)); # undeclared streams in UTF-8
use Encode   qw(decode);
use FindBin qw($Bin);
@ARGV = map { decode('UTF-8', $_, Encode::FB_CROAK) } @ARGV;

use autodie;

my %h;
open my $fh, "$Bin/../top6000.txt";
while (<$fh>) {
    chomp;
    $h{$_} = $.;
}
close $fh;

my @table;
while (<>) {
    chomp;
    my @F = split /\t/;
    next unless $F[0] && exists $h{$F[0]};

    # 检查单手打的字
    push @table, [ $h{$F[0]}, @F ] if $F[1] =~ /^(?:[qwertasdfgzxcvb]+|[^qwertasdfgzxcvb]+)$/ && length($F[1]) > 2;
}

@table = sort { $a->[0] <=> $b->[0] || $a->[1] cmp $b->[1] || $a->[2] cmp $b->[2] } @table;
for (@table) {
    print join("\t", @$_), "\n";
}
