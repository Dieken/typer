#!/usr/bin/env perl
#
# 分析宇浩星陈输入法的拆分表，反推字根的编码
#
# Usage: analyze-roots-of-yustar-input-method.pl | cut -f 2,3 | sort -u

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

sub analyze($fh) {
    while (<$fh>) { last if /^\.\.\./;  }

    while (<$fh>) {
        my ($char, $chaifen, $code) = $_ =~ /^(\S+)\s+\[([^,]+),([^,]+)/;
        next unless $code;

        #say "$char /  $chaifen / $code";
        $code = fc(NFKD($code));
        #say "$char /  $chaifen / $code";

        my $len = length($chaifen);
        if ($len == 1) {
            say "$char\t$chaifen\t", substr($code, 0, 2);
        } elsif ($len == 2) {
            say "$char\t", substr($chaifen, 1, 1), "\t", substr($code, 1, 2);
            say "$char\t", substr($chaifen, 0, 1), "\t", substr($code, 0, 1), substr($code, 3, 1);
        } elsif ($len == 3) {
            say "$char\t", substr($chaifen, 2, 1), "\t", substr($code, 2, 2);
        }
    }
}
