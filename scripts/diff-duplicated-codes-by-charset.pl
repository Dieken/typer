#!/usr/bin/env perl
#
# Purpose:
#   比较新旧码表中各字符集的重码字变化情况。
#
# Usage:
#   curl -LO 'https://ceping.shurufa.app/data/charsets.json'
#   ./diff-duplicated-codes-by-charset.pl

use v5.36;                              # or later to get "unicode_strings" feature, plus strict and warnings
use utf8;                               # so literals and identifiers can be in UTF-8
use warnings qw(FATAL utf8);            # fatalize encoding glitches
use open     qw(:std :encoding(UTF-8)); # undeclared streams in UTF-8
use Encode   qw(decode);
@ARGV = map { decode('UTF-8', $_, Encode::FB_CROAK) } @ARGV;

use autodie;
use Encode;
use Getopt::Long;
use JSON::PP;

my $charset_file = "charsets.json";
my $new_mabiao_file = "mabiao_sc.tsv";
my $old_mabiao_file = "old/mabiao_sc.tsv";

GetOptions(
    "charset-file=s"    => \$charset_file,
    "new-mabiao-file=s" => \$new_mabiao_file,
    "old-mabiao-file=s" => \$old_mabiao_file,
) or die "Error in command line arguments";

my $charsets;
{
    open my $fh, "<:raw", $charset_file;
    local $/;
    my $json = <$fh>;
    $charsets = decode_json($json);
    close $fh;
}

my $new_mabiao = read_tsv($new_mabiao_file);
my $old_mabiao = read_tsv($old_mabiao_file);

my %codes;
while (my ($char, $charset_info) = each %$charsets) {
    for my $charset (keys %$charset_info) {
        next unless $charset_info->{$charset};

        $codes{$charset}{'new'}{$new_mabiao->{$char}}{$char} = 1;
        $codes{$charset}{'old'}{$old_mabiao->{$char}}{$char} = 1;
    }
}

for my $charset (sort keys %codes) {
    my $v = $codes{$charset};

    for my $side (qw(new old)) {
        my %dups;
        while (my ($code, $chars) = each %{  $v->{$side} }) {
            my @chars = sort keys %$chars;
            if (@chars > 1) {
                map { $dups{$_} = 1 } @chars;
            }
        }
        $v->{$side} = \%dups;
    }

    for my $char (sort keys %{ $v->{'new'} }) {
        if (exists $v->{'old'}{$char}) {
            delete $v->{'new'}{$char};
            delete $v->{'old'}{$char};
        }
    }

    my @dups = sort keys %{  $v->{'new'} };
    printf "%18s: %+3d %s\n", "$charset 新增重码字", scalar(@dups), join(" ", @dups);
    @dups = sort keys %{  $v->{'old'} };
    printf "%18s: %+3d %s\n", "$charset 减少重码字", -scalar(@dups), join(" ", @dups);
}

#######################################################################
sub read_tsv($file) {
    my %h;

    open my $fh, "<", $file;
    while (<$fh>) {
        chomp;
        my @a = split;
        $h{$a[0]} = $a[1] if @a >= 2 && !exists $h{$a[0]};
    }
    close $fh;

    return \%h;
}
