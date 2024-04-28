#!/usr/bin/env perl
#
# 分析虎码输入法的拆分表和单字全码表，反推字根的编码
#
# Usage: analyze-roots-of-tiger-input-method.pl [opencc/hu_cf.txt [tiger.dict.yaml]] | cut -f 2,3 | sort -u

use v5.36;                              # or later to get "unicode_strings" feature, plus strict and warnings
use utf8;                               # so literals and identifiers can be in UTF-8
use warnings qw(FATAL utf8);            # fatalize encoding glitches
use open     qw(:std :encoding(UTF-8)); # undeclared streams in UTF-8
use Encode   qw(decode);
@ARGV = map { decode('UTF-8', $_, Encode::FB_CROAK) } @ARGV;

use autodie;

my $chaifen_file = shift || "opencc/hu_cf.txt";
my $chars_file = shift || "tiger.dict.yaml";

my %chaifen;
my %chars;

my $fh;
open $fh, $chaifen_file;
while (<$fh>) {
    chomp;
    my @a = split;
    $a[1] =~ s/^.|&.*$//g;
    $chaifen{$a[0]} = $a[1];
}
close $fh;
undef $fh;

open $fh, $chars_file;
while (<$fh>) { last if /^\.\.\./; }
while (<$fh>){
    chomp;
    my @a = split;
    next unless $a[1];
    $chars{$a[0]} = $a[1] if !exists $chars{$a[0]} || length($chars{$a[0]}) < length($a[1]);
}
close $fh;

while (my ($k, $v) = each %chaifen) {
    my $v2 = $chars{$k};
    next unless $v2;

    my $len = length($v);
    if ($len == 1) {         # 单根字
        say $k, "\t", $v, "\t", substr($v2, 0, 2);
    } elsif ($len == 2) {    # 双根字
        say $k, "\t", substr($v, 1), "\t", substr($v2, 1, 2);
    } elsif ($len == 3) {    # 三根字
        say $k, "\t", substr($v, 2), "\t", substr($v2, 2, 2);
    }
}
