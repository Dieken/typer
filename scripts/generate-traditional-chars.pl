#!/usr/bin/env perl
#
# 生成简繁字对照表
#
# Usage: ./generate-traditional-chars.pl --unihan-dir=../sbfd | tabulate -f plain
#
# 参考「简繁转换一对多列表」： https://zh.wikipedia.org/wiki/%E7%B0%A1%E7%B9%81%E8%BD%89%E6%8F%9B%E4%B8%80%E5%B0%8D%E5%A4%9A%E5%88%97%E8%A1%A8

use v5.36;                              # or later to get "unicode_strings" feature, plus strict and warnings
use utf8;                               # so literals and identifiers can be in UTF-8
use warnings qw(FATAL utf8);            # fatalize encoding glitches
use open     qw(:std :encoding(UTF-8)); # undeclared streams in UTF-8
use Encode   qw(decode);
@ARGV = map { decode('UTF-8', $_, Encode::FB_CROAK) } @ARGV;

use autodie;
use FindBin qw($Bin);
use Getopt::Long;

my $unihan_dir = "$Bin/../sbfd";

GetOptions(
    'unihan-dir=s' => \$unihan_dir,
);

my $variants = parse_unihan_variants("$unihan_dir/Unihan_Variants.txt");
my $mandarins = parse_unihan_mandarins("$unihan_dir/Unihan_Readings.txt");
my $sources = parse_unihan_sources("$unihan_dir/Unihan_IRGSources.txt");

for my $char (sort keys %$variants) {
    say charinfo($char), "\t:\t", join("\t", map { charinfo($_) } sort keys %{$variants->{$char}});
}

################################################################################
sub parse_unihan_variants($path) {
    my %variants;

    open my $fh, '<', $path;
    while (<$fh>) {
        chomp;

        my @a = split;
        next unless $a[2] && $a[0] =~ /^U\+/;

        if ($a[1] eq 'kSimplifiedVariant') {
            map { $variants{to_char($_)}{to_char($a[0])} = 1 if $_ ne $a[0] } @a[2..$#a];
        } elsif ($a[1] eq 'kTraditionalVariant') {
            map { $variants{to_char($a[0])}{to_char($_)} = 1 if $_ ne $a[0] } @a[2..$#a];
        }
    }
    close $fh;

    return \%variants;
}

sub to_char($codepoint) {
    return chr(hex(substr($codepoint, 2)));
}

sub parse_unihan_mandarins($path) {
    my %mandarins;

    open my $fh, '<', $path;
    while (<$fh>) {
        chomp;

        my @a = split;
        next unless $a[2] && $a[0] =~ /^U\+/;

        if ($a[1] eq 'kMandarin') {
            $a[2] =~ s/\s+$/,/g;
            $mandarins{to_char($a[0])} = $a[2];
        }
    }
    close $fh;

    return \%mandarins;
}

sub parse_unihan_sources($path) {
    my %sources;

    open my $fh, '<', $path;
    while (<$fh>) {
        chomp;

        my @a = split;
        next unless $a[2] && $a[0] =~ /^U\+/;

        if ($a[1] =~ /^kIRG_(\S+)Source$/) {
            $sources{to_char($a[0])}{$1} = 1;
        }
    }
    close $fh;

    return \%sources;
}

sub charinfo($char) {
    sprintf("U+%04X %s %s %s",
        ord($char),
        $char,
        $mandarins->{$char} // "-",
        join(",", sort keys %{$sources->{$char}}));
}
