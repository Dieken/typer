#!/usr/bin/env perl
#
# 根据正常码表生成赵小锋的二三四顶码表
#
# Usage: ./generate-xiao-feng-ding-dict.pl --top-chars=top-chars.txt --use-end --length-order PATH/TO/RIME/DICT.yaml...

use v5.36;                              # or later to get "unicode_strings" feature, plus strict and warnings
use utf8;                               # so literals and identifiers can be in UTF-8
use warnings qw(FATAL utf8);            # fatalize encoding glitches
use open     qw(:std :encoding(UTF-8)); # undeclared streams in UTF-8
use Encode   qw(decode);
@ARGV = map { decode('UTF-8', $_, Encode::FB_CROAK) } @ARGV;

use autodie;
use Getopt::Long;

my $top_chars = "top-chars.txt";
my $top_n = 3000;       # 取前多少个高频字，不建议超过 3000
my $use_end = 0;        # 使用第三码还是末码，0 为第三码，1 为末码，使用末码的重码较少
my $length_order = 0;   # 按字频分配简码时是否优先按全码长度分配，0 为仅按字频，1 为按长度和字频，推荐用 1 以减少记忆简码
my $max_length = 4;     # 最大码长，不超过 4

GetOptions(
    'top-chars=s' => \$top_chars,
    'top-n=i'    => \$top_n,
    'use-end'    => \$use_end,
    'length-order' => \$length_order,
    'max-length=i' => \$max_length,
);

my %dict;
while (<>) {
    chomp;

    my @a = split;
    next unless @a >= 2 && $a[0] =~ /^\p{Han}$/;

    $dict{$a[0]} = $a[1] unless exists $dict{$a[0]} && length($dict{$a[0]}) >= length($a[1]);
}

my @new_dict;

my %top_chars;
open my $fh, '<', $top_chars;
while (<$fh>) {
    chomp;

    last if $. > $top_n;
    $top_chars{$_}{sequence} = $.;
    $top_chars{$_}{length} = length($dict{$_});
}
close $fh;

for (sort { ($length_order ? $top_chars{$a}{length} <=> $top_chars{$b}{length} : 0) ||
            $top_chars{$a}{sequence} <=> $top_chars{$b}{sequence} }
        keys %top_chars) {
    for my $i (0 .. $max_length - 1) {
        my $code = $dict{$_};
        die "Unknown char $_" unless defined $code;

        if ($use_end && $i == ($max_length - 1) && length($code) > $max_length) {
            $code = substr($code, 0, $max_length - 1) . substr($code, -1);
        } else {
            $code = substr($code, 0, $i + 1);
        }

        if (! exists $new_dict[$i]{$code}) {
            $new_dict[$i]{$code} = 1;
            print "$_\t$code\n";
            last;
        } elsif ($i == ($max_length - 1)) {
            warn "Duplicated code $code ($_)\n";
            print "$_\t$code\n";
        }
    }
}
