#!/usr/bin/env perl
#
# 检查单字码表重码的首选和二选是否简体优先
#
# Usage:
#   ./check-traditional-duplicates.pl --unihan-dir=../sbfd ~/Library/Rime/yuhao/yustar.full.dict.yaml | sort -k3,3n -k2,2 -k1,1 | cat -n
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

my $freq_file = "$Bin/../简体字频表-2.5b.txt"; # "$Bin/../top6000.txt";
my $variants_file = "$Bin/../sbfd/Unihan_Variants.txt";

GetOptions(
    'freq-file=s'  => \$freq_file,
    'variants-file=s' => \$variants_file,
);

my $freq = read_freq_file($freq_file);
my $variants = parse_unihan_variants($variants_file);
my %simplified = map { $_ => 1 } keys %{$variants};
my %traditional = map { $_ => 1 } map { keys %{$variants->{$_}} } keys %{$variants};

#say scalar keys %simplified, " simplified characters";
#say scalar keys %traditional, " traditional characters";
#say scalar keys %{$freq}, " characters in frequency list";

my %top_candidates;
while (<>) {
    chomp;
    my @a = split;

    next unless $a[1] && $a[0] =~ /^\p{Han}$/;

    $top_candidates{$a[1]} = $a[0] unless exists $top_candidates{$a[1]};

    my $top_candidate = $top_candidates{$a[1]};
    next unless $a[0] ne $top_candidate;
    next unless exists $simplified{$a[0]};
    next unless exists $traditional{$top_candidate};
    next unless exists $freq->{$a[0]};

    say "$a[0]\t$a[1]\t$freq->{$a[0]}\t:\t$top_candidate";
}


################################################################################
sub read_freq_file($path) {
    my %freq;

    open my $fh, '<', $path;
    while (<$fh>) {
        my ($char) = split;
        $freq{$char} = $.;
    }
    close $fh;

    return \%freq;
}

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
