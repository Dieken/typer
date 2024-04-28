#!/usr/bin/env perl
#
# 分析虎码输入法的拆分表和单字全码表，反推字根的编码
#
# Usage: analyze-roots-of-tiger-input-method.pl [opencc/hu_cf.txt] | cut -f 2,3 | sort -u -k2 -k1

use v5.36;                              # or later to get "unicode_strings" feature, plus strict and warnings
use utf8;                               # so literals and identifiers can be in UTF-8
use warnings qw(FATAL utf8);            # fatalize encoding glitches
use open     qw(:std :encoding(UTF-8)); # undeclared streams in UTF-8
use Encode   qw(decode);
@ARGV = map { decode('UTF-8', $_, Encode::FB_CROAK) } @ARGV;

use autodie;

my $chaifen_file = shift || "opencc/hu_cf.txt";

my %unknown_roots;

open(my $fh, $chaifen_file);
while (<$fh>) {
    my ($char, $chaifen, $code) = $_ =~ /^(\S+)\s+〔([^&]+)&nbsp;·&nbsp;([^&〕]+)/;
    next unless $code;

    my @a = $chaifen =~ /((?:{[^}]+})|.)/g;
    $code = lc($code);

    if (@a <= 3) {
        say $char, "\t", $a[-1], "\t", ucfirst(substr($code, -2));

        $unknown_roots{$a[-1]} = "--";
    } else {
        $unknown_roots{$a[-1]} = uc(substr($code, -1)) . "?" unless $unknown_roots{$a[-1]};
    }

    for (0 .. $#a - 1) {
        $unknown_roots{$a[$_]} = uc(substr($code, $_, 1)) . "?" unless $unknown_roots{$a[$_]};
    }
}
close $fh;

for (sort { $unknown_roots{$a} cmp $unknown_roots{$b} } keys %unknown_roots) {
    say "?\t$_\t", $unknown_roots{$_} unless $unknown_roots{$_} eq "--";
}
