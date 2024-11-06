#!/usr/bin/env perl
#
# 根据正常码表生成赵小锋的二三顶码表
#
# Usage: ./generate-two-three-ding-dict.pl --top-chars=top-chars.txt PATH/TO/RIME/DICT.yaml...

use v5.36;                              # or later to get "unicode_strings" feature, plus strict and warnings
use utf8;                               # so literals and identifiers can be in UTF-8
use warnings qw(FATAL utf8);            # fatalize encoding glitches
use open     qw(:std :encoding(UTF-8)); # undeclared streams in UTF-8
use Encode   qw(decode);
@ARGV = map { decode('UTF-8', $_, Encode::FB_CROAK) } @ARGV;

use autodie;
use Getopt::Long;

my $top_chars = "top-chars.txt";
my $top_n = 3000;
my $use_end = 0;

GetOptions(
    'top-chars=s' => \$top_chars,
    'top-n=i'    => \$top_n,
    'use-end'    => \$use_end,
);

my %dict;
while (<>) {
    chomp;

    my @a = split;
    next unless @a >= 2 && $a[0] =~ /^\p{Han}$/;

    $dict{$a[0]} = $a[1] unless exists $dict{$a[0]} && length($dict{$a[0]}) >= length($a[1]);
}

my @new_dict = ({}, {}, {});

open my $fh, '<', $top_chars;
while (<$fh>) {
    chomp;

    last if $. > $top_n;

    for my $i (0 .. 2) {
        my $code = $dict{$_};
        die "Unknown char $_" unless defined $code;

        if ($use_end && $i == 2 && length($code) > 3) {
            $code = substr($code, 0, 2) . substr($code, -1);
        } else {
            $code = substr($code, 0, $i + 1);
        }

        if (! exists $new_dict[$i]{$code}) {
            $new_dict[$i]{$code} = 1;
            print "$_\t$code\n";
            last;
        } elsif ($i == 2) {
            warn "Duplicated code $code ($_)\n";
            print "$_\t$code\n";
        }
    }
}
close $fh;
