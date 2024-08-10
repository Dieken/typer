#!/usr/bin/env perl
#
# Purpose:
#   生成覆盖字根的最小字符集码表
#
# Usage:
#   ./generate-example-chars.pl [chaifen.tsv] [mabiao.tsv] [char_freq.tsv] [roots.tsv]

use v5.36;                              # or later to get "unicode_strings" feature, plus strict and warnings
use utf8;                               # so literals and identifiers can be in UTF-8
use warnings qw(FATAL utf8);            # fatalize encoding glitches
use open     qw(:std :encoding(UTF-8)); # undeclared streams in UTF-8
use Encode   qw(decode);
@ARGV = map { decode('UTF-8', $_, Encode::FB_CROAK) } @ARGV;

use autodie;
use Unicode::UCD qw/charblock/;

my $chaifen_file = shift // 'chaifen.tsv';
my $mabiao_file = shift // 'mabiao.tsv';
my $freq_file = shift // '../top6000.txt';
my $roots_file = shift // 'roots.tsv';

my %roots;
{
    open my $fh, "<", $roots_file;
    while (<$fh>) {
        chomp;
        my @a = split;
        $roots{$a[0]} = 1 if $a[0] && $a[0] !~ /^#/;
    }
    close $fh;
}

my %chaifen;
{
    open my $fh, "<", $chaifen_file;
    while (<$fh>) {
        chomp;
        my @a = split /\s+/, $_, 2;
        next unless $a[0] && $a[0] !~ /^#/ &&
            !exists $chaifen{$a[0]} &&
            #charblock(ord($a[0])) ne "Private Use Area";
            #charblock(ord($a[0])) =~ /^CJK/;
            #charblock(ord($a[0])) =~ /^(?:CJK Unified Ideographs|CJK Compatibility Ideographs|CJK Radicals Supplement|Tangut)/;    # for sky-20240710
            charblock(ord($a[0])) =~ /^CJK Unified Ideographs/;

        my @b = $a[1] =~ /{[^}]+}|\S/g;
        $chaifen{$a[0]} = @b > 4 ? [ @b[0..2, -1] ] : \@b;
    }
    close $fh;
}

my %mabiao;
{
    open my $fh, "<", $mabiao_file;
    while (<$fh>) {
        chomp;
        my @a = split;
        next unless $a[0] && $a[0] !~ /^#/;
        next if exists $mabiao{$a[0]} && length($a[1]) <= length($mabiao{$a[0]});
        $mabiao{$a[0]} = $a[1];
    }
    close $fh;
}

my %chars;
{
    open my $fh, "<", $freq_file;
    while (<$fh>) {
        chomp;
        my @a = split;
        $chars{$a[0]} = scalar(keys(%chars)) if $_ && $_ !~ /^#/ && length($a[0]) == 1;
    }
    close $fh;

    my $n = keys %chars;

    for (keys %chaifen) {
        $chars{$_} = $n + ord($_) unless exists $chars{$_};
    }
}

{
    for my $char (sort { $chars{$a} <=> $chars{$b} } keys %chars) {
        my $cf = $chaifen{$char};

        my @founds;
        for (@$cf) {
            if (exists $roots{$_}) {
                delete $roots{$_};
                push @founds, $_;
            }
        }

        if (@founds > 0) {
            print "$char\t$mabiao{$char}\t", join("", @$cf), "\t# ", join("", @founds), "\t", charblock(ord($char)), "\n";
        }
    }

    if (keys(%roots) > 0) {
        print STDERR "# Not found: ", join(" ", keys(%roots)), "\n";
    }
}
