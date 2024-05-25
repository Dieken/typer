#!/usr/bin/env perl
#
# 分析宇浩星陈输入法的拆分表，反推 {xxx} 字根到 PUA 字符的映射
#
# Usage:
#   curl -s -o yuhao-chaifen.csv 'https://yuhao.forfudan.com/chaifen.csv'
#   analyze-yuhao-root-mapping.pl yustar_chaifen.dict.yaml yustar_chaifen_tw.dict.yaml yuhao-chaifen.csv

use v5.36;                              # or later to get "unicode_strings" feature, plus strict and warnings
use utf8;                               # so literals and identifiers can be in UTF-8
use warnings qw(FATAL utf8);            # fatalize encoding glitches
use open     qw(:std :encoding(UTF-8)); # undeclared streams in UTF-8
use Encode   qw(decode);
@ARGV = map { decode('UTF-8', $_, Encode::FB_CROAK) } @ARGV;

use autodie;
use Unicode::UCD qw/charblock/;

my $chaifen_file = shift || "yustar_chaifen.dict.yaml";
my $chaifen_tw_file = shift || "yustar_chaifen_tw.dict.yaml";
my $yuhao_chaifen_file = shift || "yuhao-chaifen.csv";

my $yuhao_chaifen = parse_yuhao_chaifen($yuhao_chaifen_file);
my %mapping;

analyze_chaifen_dict($chaifen_file, 0);
analyze_chaifen_dict($chaifen_tw_file, 1);

for (sort keys %mapping) {
    say "$_\t$mapping{$_}";
}

sub parse_yuhao_chaifen($file) {
    my %h;

    open my $fh, "<", $file;
    while (<$fh>) {
        next if $. == 1;
        chomp;
        my @a = split /,/;
        next unless @a >= 3;
        $h{$a[0]} = [ @a[1..2] ];
    }
    close $fh;

    return \%h;
}

sub analyze_chaifen_dict($file, $is_tw) {
    my %h;

    open my $fh, "<", $file;

    while (<$fh>) { last if /^\.\.\./;  }
    while (<$fh>) {
        my ($char, $chaifen, $code) = $_ =~ /^(\S+)\s+\[([^,]+),([^,]+)/;
        next unless $code && $chaifen =~ /{/;

        my @a = $chaifen =~ /{[^}]+}|\S/g;
        my @b = (($is_tw ? $yuhao_chaifen->{$char}[1] : "") || $yuhao_chaifen->{$char}[0]) =~ /\S/g;

        my $msg = "Inconsistent chaifen for $char: [@a] vs [@b]";
        die "$msg\n" if scalar(@a) != scalar(@b);

        for (my $i = 0; $i < @a; ++$i) {
            if ($a[$i] =~ /{/) {
                if (exists $mapping{$a[$i]}) {
                    if ($mapping{$a[$i]} ne $b[$i]) {
                        if (charblock(ord($b[$i])) eq "Private Use Area") {
                            die "$msg -> $a[$i]($mapping{$a[$i]}) vs $b[$i]\n";
                        } else {
                            warn "$msg -> $a[$i]($mapping{$a[$i]}) vs $b[$i]\n";
                        }
                    }
                } else {
                    if (charblock(ord($b[$i])) eq "Private Use Area") {
                        $mapping{$a[$i]} = $b[$i];
                    } else {
                        warn "$msg -> $a[$i] vs $b[$i]\n";
                    }
                }
            } else {
                warn "$msg -> $a[$i] vs $b[$i]\n" if $a[$i] ne $b[$i];
            }
        }
    }

    close $fh;
}
