#!/usr/bin/env perl
#
# 分析宇浩日月输入法的拆分表，反推字根的编码
#
# Usage:
#   analyze-roots-of-yusm-input-method.pl [yusm_chaifen*.dict.yaml]

use v5.36;                              # or later to get "unicode_strings" feature, plus strict and warnings
use utf8;                               # so literals and identifiers can be in UTF-8
use warnings qw(FATAL utf8);            # fatalize encoding glitches
use open     qw(:std :encoding(UTF-8)); # undeclared streams in UTF-8
use Encode   qw(decode);
@ARGV = map { decode('UTF-8', $_, Encode::FB_CROAK) } @ARGV;

use Unicode::Normalize;
use autodie;

my $chaifen_file = shift || "yusm_chaifen.dict.yaml";
#my $chaifen_tw_file = shift || "yusm_chaifen_tw.dict.yaml";

my %roots;

my $fh;
open $fh, $chaifen_file;
analyze($fh);
close $fh;
undef $fh;

#open $fh, $chaifen_tw_file;
#analyze($fh);
#close $fh;

for (sort { $roots{$a} cmp $roots{$b} || $a cmp $b } keys %roots) {
    say "$_\t", $roots{$_};
}

#######################################################################

sub analyze($fh) {
    while (<$fh>) { last if /^\.\.\./;  }

    while (<$fh>) {
        my ($char, $chaifen, $code) = $_ =~ /^(\S+)\s+\[([^,]+),([^,]+)/;
        next unless $code && $chaifen !~ /～/;   # skip special root "~" which stands for picking little code

        my @a = $chaifen =~ /((?:{[^}]+})|.)/g;
        my @c = $code =~ /[A-Z][^A-Z]*/g;

        die "Bad chaifen for $char: @a  vs @c\n" if @a != @c;

        for (my $i = 0; $i < @a; ++$i) {
            $roots{$a[$i]} = $c[$i] unless exists $roots{$a[$i]} && length($roots{$a[$i]}) >= length($c[$i]);
        }
    }
}
