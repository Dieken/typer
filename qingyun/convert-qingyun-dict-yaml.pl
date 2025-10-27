#!/usr/bin/env perl
#
# Usage:
#  convert-qingyun-dict-yaml.pl ~/Library/Rime/snow_qingyun.dict.yaml > converted_snow_qingyun.dict.yaml

use v5.36;                              # or later to get "unicode_strings" feature, plus strict and warnings
use utf8;                               # so literals and identifiers can be in UTF-8
use warnings qw(FATAL utf8);            # fatalize encoding glitches
use open     qw(:std :encoding(UTF-8)); # undeclared streams in UTF-8
use Encode   qw(decode);
@ARGV = map { decode('UTF-8', $_, Encode::FB_CROAK) } @ARGV;

use List::Util qw(min);

# https://input.tansongchen.com/snow-qingyun/spelling.html
my %consonnats = (
    'zh' => 'z',
    'ch' => 'c',
    'sh' => 's',
);

# https://input.tansongchen.com/snow-qingyun/spelling.html
my %vowels0 = (
    'a, ia, ua, ou, iou, iu'        => 'a',
    'o, io, uo, ao, iao'            => 'o',
    'e, ie, ue, üe, ei, uei, ui'    => 'e',
    'i, er, ai, uai'                => 'i',
    'u, ü'                          => 'u',
    'an, ian, uan, üan'             => ';',
    'ang, iang, uang'               => ',',
    'en, in, uen, un, ün, n, m'     => '.',
    'eng, ing, ueng, ong, iong, ng' => '/',
);

my %vowels;
while (my ($k, $v) = each %vowels0) {
    my @a = split /\s*,\s*/, $k;
    for (@a) {
        $vowels{$_} = $v;
    }
}

while (<>) {
    my ($char, $code, $weight) = $_ =~ /^(\S+)\t([a-zü ]+)\t(\d+)$/;

    unless (defined $weight) {
        print;
        next;
    }

    my @codes = map {
        $_ = "v$_" if /^[aeo]/;

        if (/^([^aeuioü]h?)(\S+)$/) {
            ($consonnats{$1} // $1) . ($vowels{$2} // do {
                warn "WARN: $char\t$code\t$weight: unknown vowel $2\n";
                $2;
            });
        } else {
            warn "WARN: $char\t$code\t$weight: unknown pinyin $_\n";
            $_;
        }
    } split /\s+/, $code;

    # https://input.tansongchen.com/snow-qingyun/basic.html
    my $c = '';
    if (length($char) == 1) {
        $c .= substr($_, 0, 1) for @codes[0 .. min(2, $#codes)];
        $c .= substr($codes[-1], @codes < 4 ? 1 : 0, 1);
    } else {
        $c .= substr($_, 0, 1) for @codes[0 .. min(3, $#codes)];
        $c .= substr($codes[-1], 1, 1) if @codes < 4;
    }

    print "$char\t$c\t$weight\n";
}
