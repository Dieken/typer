#!/usr/bin/env perl
#
# 分析宇浩卿雲输入法的拆分表，反推字根的编码
#
# Usage:
#   analyze-roots-of-yujoy-input-method.pl [yujoy_chaifen*.dict.yaml] | cut -f 2,3 | sort -u -k2 -k1

use v5.36;                              # or later to get "unicode_strings" feature, plus strict and warnings
use utf8;                               # so literals and identifiers can be in UTF-8
use warnings qw(FATAL utf8);            # fatalize encoding glitches
use open     qw(:std :encoding(UTF-8)); # undeclared streams in UTF-8
use Encode   qw(decode);
@ARGV = map { decode('UTF-8', $_, Encode::FB_CROAK) } @ARGV;

use Unicode::Normalize;
use autodie;

my $chaifen_file = shift || "yujoy_chaifen.dict.yaml";
my $chaifen_tw_file = shift || "yujoy_chaifen_tw.dict.yaml";

my %unknown_roots;

my $fh;
open $fh, $chaifen_file;
analyze($fh);
close $fh;
undef $fh;

open $fh, $chaifen_tw_file;
analyze($fh);
close $fh;

for (sort { $unknown_roots{$a} cmp $unknown_roots{$b} } keys %unknown_roots) {
    say "?\t$_\t", $unknown_roots{$_} unless $unknown_roots{$_} eq "--";
}

#######################################################################

sub analyze($fh) {
    while (<$fh>) { last if /^\.\.\./;  }

    while (<$fh>) {
        my ($char, $chaifen, $code) = $_ =~ /^(\S+)\s+\[([^,]+),([^,]+)/;
        next unless $code && $chaifen !~ /~/;   # skip special root "~" which stands for picking little code

        my @a = $chaifen =~ /((?:{[^}]+})|.)/g;

        #say "$char /  $chaifen / $code";
        $code = fc(NFKD($code));
        #say "$char /  $chaifen / $code";

        if (@a < 4) {
            say "$char\t$a[$#a]\t", ucfirst(substr($code, -2, 2));
            $unknown_roots{$a[$#a]} = "--";
        }

        for (0 .. $#a - 1) {
            $unknown_roots{$a[$_]} = uc(substr($code, $_, 1)) . "?" unless $unknown_roots{$a[$_]};
        }
    }
}
