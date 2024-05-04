#!/usr/bin/env perl
#
# 分析宇浩星陈输入法的拆分表，反推字根的编码
#
# Usage: analyze-roots-of-yustar-input-method.pl [yustar_chaifen*.dict.yaml] | cut -f 2,3 | sort -u -k2 -k1

use v5.36;                              # or later to get "unicode_strings" feature, plus strict and warnings
use utf8;                               # so literals and identifiers can be in UTF-8
use warnings qw(FATAL utf8);            # fatalize encoding glitches
use open     qw(:std :encoding(UTF-8)); # undeclared streams in UTF-8
use Encode   qw(decode);
@ARGV = map { decode('UTF-8', $_, Encode::FB_CROAK) } @ARGV;

use Unicode::Normalize;
use autodie;

my $chaifen_file = shift || "yustar_chaifen.dict.yaml";
my $chaifen_tw_file = shift || "yustar_chaifen_tw.dict.yaml";

my $fh;
open $fh, $chaifen_file;
analyze($fh);
close $fh;
undef $fh;

open $fh, $chaifen_file;
analyze($fh);
close $fh;

my %unknown_roots;
sub analyze($fh) {
    while (<$fh>) { last if /^\.\.\./;  }

    while (<$fh>) {
        my ($char, $chaifen, $code) = $_ =~ /^(\S+)\s+\[([^,]+),([^,]+)/;
        next unless $code;

        my @a = $chaifen =~ /((?:{[^}]+})|.)/g;

        #say "$char /  $chaifen / $code";
        $code = fc(NFKD($code));
        #say "$char /  $chaifen / $code";

        if (@a == 1) {
            say "$char\t$a[0]\t", ucfirst(substr($code, 0, 2));

            $unknown_roots{$a[0]} = "--";
        } elsif (@a == 2) {
            say "$char\t", $a[1], "\t", ucfirst(substr($code, 1, 2));
            say "$char\t", $a[0], "\t", uc(substr($code, 0, 1)), substr($code, 3, 1);

            $unknown_roots{$a[0]} = "--";
            $unknown_roots{$a[1]} = "--";
        } elsif (@a == 3) {
            say "$char\t", $a[2], "\t", ucfirst(substr($code, 2, 2));
            $unknown_roots{$a[2]} = "--";

            for (0 .. 1) {
                $unknown_roots{$a[$_]} = uc(substr($code, $_, 1)) . "?" unless $unknown_roots{$a[$_]};
            }
        } else {
            for (0 .. 2) {
                $unknown_roots{$a[$_]} = uc(substr($code, $_, 1)) . "?" unless $unknown_roots{$a[$_]};
            }
            $unknown_roots{$a[-1]} = uc(substr($code, 3, 1)) . "?" unless $unknown_roots{$a[-1]};
        }
    }
}

for (sort { $unknown_roots{$a} cmp $unknown_roots{$b} } keys %unknown_roots) {
    say "?\t$_\t", $unknown_roots{$_} unless $unknown_roots{$_} eq "--";
}
