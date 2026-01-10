#!/usr/bin/env perl
#
# Purpose:
#   remove phrases and adjust char order according to frequency
#
# Usage:
#   ./filter-dazhu-mabiao.pl path/to/星陳輸入法_v3.11.0-beta.20260109.185222/

use v5.36;                              # or later to get "unicode_strings" feature, plus strict and warnings
use utf8;                               # so literals and identifiers can be in UTF-8
use warnings qw(FATAL utf8);            # fatalize encoding glitches
use open     qw(:std :encoding(UTF-8)); # undeclared streams in UTF-8
use sort 'stable';                      # preserve input order of equal elements
use Encode   qw(decode);
@ARGV = map { decode('UTF-8', $_, Encode::FB_CROAK) } @ARGV;

use autodie;

my %freq;
open my $fh, '<', $ARGV[0] . '/schema/lua/yuhao/yuhao_charsets.lua';
while (<$fh>) {
    if (/^this\.ubi/ .. /^\]\]/) {
        chomp;
        $freq{$_} = 1000000 - $. if $_ !~ /[\[\]]]/;
    }
}
close $fh;
undef $fh;

my @mabiao;
my %chars;
open $fh, '<', $ARGV[0] . '/mabiao/dazhu/宇浩星陈·陆标简码.txt';
while (<$fh>) {
    chomp;
    my @a = split /\t/, $_, 2;
    next if $a[1] =~ /\p{Han}{2}/;
    push @mabiao, [@a, $freq{$a[1]} // 0];

    my $i = $chars{$a[1]};
    $mabiao[$i] = undef if $i && $mabiao[$i][0] =~ /^.{2,3}$/;

    $chars{$a[1]} = $#mabiao;
}
close $fh;

@mabiao = sort { $a->[0] cmp $b->[0] or $b->[2] <=> $a->[2] } grep { $_ } @mabiao;
for (@mabiao) {
    print "$_->[0]\t$_->[1]\n" if $_;
}
