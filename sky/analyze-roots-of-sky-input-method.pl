#!/usr/bin/env perl
#
# 分析天码输入法的拆分表和单字全码表，反推字根的编码
#
# Usage: analyze-roots-of-sky-input-method.pl [拆分表.txt [单字全码.txt]] | cut -f 2,3 | sort -u -k2 -k1

use v5.36;                              # or later to get "unicode_strings" feature, plus strict and warnings
use utf8;                               # so literals and identifiers can be in UTF-8
use warnings qw(FATAL utf8);            # fatalize encoding glitches
use open     qw(:std :encoding(UTF-8)); # undeclared streams in UTF-8
use Encode   qw(decode);
@ARGV = map { decode('UTF-8', $_, Encode::FB_CROAK) } @ARGV;

use autodie;

my $chaifen_file = shift || "拆分表.txt";
my $chars_file = shift || "单字全码.txt";

my %chaifen;
my %chars;

my $fh;
open $fh, $chaifen_file;
while (<$fh>) {
    chomp;
    my @a = split;
    my @b = $a[2] =~ /((?:{[^}]+})|.)/g;
    $chaifen{$a[1]} = \@b;
}
close $fh;
undef $fh;

open $fh, $chars_file;
while (<$fh>){
    chomp;
    my @a = split;
    $chars{$a[0]} = $a[1] unless exists $chars{$a[0]};
}
close $fh;

my %unknown_roots;
while (my ($k, $v) = each %chaifen) {
    my $v2 = $chars{$k};
    next unless $v2;

    if (@$v == 1) {         # 单根字
        say $k, "\t", $v->[0], "\t", ucfirst(lc(substr($v2, 0, 2)));

        $unknown_roots{$v->[0]} = "--";
    } elsif (@$v == 2) {    # 双根字
        say $k, "\t", $v->[1], "\t", ucfirst(lc(substr($v2, 1, 2)));
        say $k, "\t", $v->[0], "\t", uc(substr($v2, 0, 1)), length($v2) == 4 ? lc(substr($v2, 3, 1)) : "v";

        $unknown_roots{$v->[0]} = "--";
        $unknown_roots{$v->[1]} = "--";
    } elsif (@$v == 3) {    # 三根字
        say $k, "\t", $v->[2], "\t", ucfirst(lc(substr($v2, 2, 2)));

        for (0 .. 1) {
            $unknown_roots{$v->[$_]} = uc(substr($v2, $_, 1)) . "?" unless $unknown_roots{$v->[$_]};
        }
    } else {
        for (0 .. 2) {
            $unknown_roots{$v->[$_]} = uc(substr($v2, $_, 1)) . "?" unless $unknown_roots{$v->[$_]};
        }
        $unknown_roots{$v->[-1]} = uc(substr($v2, 3, 1)) . "?" unless $unknown_roots{$v->[-1]};
    }
}

for (sort { $unknown_roots{$a} cmp $unknown_roots{$b} } keys %unknown_roots) {
    say "?\t$_\t", $unknown_roots{$_} unless $unknown_roots{$_} eq "--";
}
