#!/usr/bin/env perl
#
# Purpose:
#   adjust RIME dict according to frequencies of characters and words
#
# Usage:
#   export R=path/to/星陳輸入法_v3.11.0-beta.20260116.152831/schema
#   a=$(grep '^\s*-\s\+yuhao/' $R/yustar_sc.dict.yaml | perl -lpE 's/\r//; s/\s*#.*//; s/^\s*\-\s*/-d $ENV{R}\//; s/$/.dict.yaml/')
#   ./adjust-dict.pl $a -c ../简体字频表-2.5b.txt -w ../词频数据.txt -c override_weight.txt -w override_weight.txt > yustar_sc.all.dict.yaml
#   #./adjust-dict.pl $a -c $R/yuhao.essay.txt -w $R/yuhao.essay.txt > yustar_sc.all.dict.yaml
#
# 简体字频表-2.5b: 北语刑红兵，https://faculty.blcu.edu.cn/xinghb/zh_CN/article/167473/content/1437.htm
# 词频数据： QQ 092五笔正规闲聊群㊣ 6592557 文件区 【词频】-> 【词频数据.txt】

use v5.36;                              # or later to get "unicode_strings" feature, plus strict and warnings
use utf8;                               # so literals and identifiers can be in UTF-8
use warnings qw(FATAL utf8);            # fatalize encoding glitches
use open     qw(:std :encoding(UTF-8)); # undeclared streams in UTF-8
use Encode   qw(decode);
@ARGV = map { decode('UTF-8', $_, Encode::FB_CROAK) } @ARGV;

use autodie;
use Getopt::Long;
use List::Util qw/any/;
use Time::Piece;

my @dict_files;
my @char_files;
my @word_files;
my $unihan_dir = "../sbfd";
my $min_weight = 10;

GetOptions(
    'dict=s'        => \@dict_files,
    'char-freq=s'   => \@char_files,
    'word-freq=s'   => \@word_files,
    'unihan-dir=s'  => \$unihan_dir,
    'min-weight=i'  => \$min_weight,
);

my $char_weights = read_freqs(1, @char_files);
my $word_weights = read_freqs(0, @word_files);
say STDERR "char weights: ", scalar keys %$char_weights;
say STDERR "word weights: ", scalar keys %$word_weights;

my ($chars, $codes) = read_dicts($char_weights, $word_weights, @dict_files);
say STDERR "chars: ", scalar keys %$chars;
say STDERR "codes: ", scalar keys %$codes;

my $variants = parse_unihan_variants("$unihan_dir/Unihan_Variants.txt");


my @chars_by_weight = sort { $char_weights->{$b} <=>  $char_weights->{$a} or $a cmp $b } keys %$char_weights;

my %quick_num;      # quick_code => num

# add quick codes
for my $char (@chars_by_weight[0 .. 8200]) {
    next unless exists $chars->{$char};
    next if exists $variants->{$char};

    my @char_codes = keys %{ $chars->{$char} };

    for my $code (@char_codes) {
        for my $n (1 .. 3) {
            last if length($code) <= $n;

            my $quick = substr($code, 0, $n);

            # whether duplicate shorter quick code
            #last if $n > 1 && exists $codes->{substr($code, 0, $n - 1)}{$char};    # 简码字只出现一次
            #last if $n > 1 && 1 == ($codes->{substr($code, 0, 1)}{$char} // -1);   # 首选一简字只出现一次
            last if $n > 1 && 1 == ($codes->{substr($code, 0, $n - 1)}{$char} // -1);   # 首选简码字只出现一次

            unless (exists $quick_num{$quick}) {
                if (exists $codes->{$quick}) {
                    $quick_num{$quick} = scalar grep {
                        /^\p{Han}$/ && any { length($_) > $n } keys %{ $chars->{$_} }
                    } keys %{ $codes->{$quick} };
                } else {
                    $quick_num{$quick} = 0;
                }
            }

            next if $quick_num{$quick} >= 3;

            unless (exists $codes->{$quick}{$char}) {
                $quick_num{$quick}++;
                $codes->{$quick}{$char} = $quick_num{$quick};
            }
        }
    }
}

my $version = localtime()->strftime("%Y%m%d.%H%M%S");
print <<END;
# encoding: utf-8
---
name: "yustar_sc.all"
version: "$version"
sort: original
columns:
  - text
  - code
...

END

for my $code (sort { length($a) <=> length($b) or $a cmp $b } keys %$codes) {
    my @words = keys %{ $codes->{$code} };

    if (length($code) < 4) {
        @words = sort { ($char_weights->{$b} // 0) <=> ($char_weights->{$a} // 0) or $a cmp $b } @words;
    } else {
        @words = sort {
            my ($la, $lb) = (length($a), length($b));
            ($lb > 1 ? 2 : 1) <=> ($la > 1 ? 2 : 1) or
            (($lb > 1 ? $word_weights->{$b} : $char_weights->{$b}) // 0) <=>
              (($la > 1 ? $word_weights->{$a} : $char_weights->{$a}) // 0) or
            $a cmp $b } @words;
    }

    for (@words) {
        #say "$_\t$code\t", (length($_) == 1 ? $char_weights->{$_} : $word_weights->{$_}) // -1;
        next if exists $word_weights->{$_} && $word_weights->{$_} >= 1 && $word_weights->{$_} < $min_weight;
        say "$_\t$code";
    }
}

#######################################################################
sub read_dicts($char_weights, $word_weights, @dicts) {
    my %chars;      # char => code => 1
    my %codes;      # code => char/word => 1
    my $weight_delta = 1e-8;
    my $weight_default = 1.0 - $weight_delta;

    for my $dict (@dicts) {
        open my $fh, '<', $dict;

        while (<$fh>) {
            last if /^\.\.\./;
        }

        while (<$fh>) {
            next if /^\s*#/;

            chomp;

            my @a = split /\t/;
            next unless @a >= 2;

            next if $a[1] =~ /^[a-z]{1,2}$/i;       # throw away 1-quick and 2-quick codes
            next if $a[1] =~ /^[a-z]{1,3}$/i && $a[0] =~ /^\p{Han}{2,}$/;  # throw away quick words

            $codes{$a[1]}{$a[0]} = 0;

            if (length($a[0]) == 1) {
                $chars{$a[0]}{$a[1]} = 1;
                $char_weights->{$a[0]} = $weight_default unless exists $char_weights->{$a[0]};
            } else {
                $word_weights->{$a[0]} = $weight_default unless exists $word_weights->{$a[0]};
            }

            $weight_default -= $weight_delta;
        }

        close $fh;
    }

    # remove 3-quick codes
    while (my ($char, $char_codes) = each %chars)  {
        my @a = sort { length($b) <=> length($a) } grep { /^[a-z]+$/i } keys %$char_codes;
        my $n = length($a[0]);
        for (@a[1 .. $#a]) {
            delete $codes{$_}{$char} if length($_) < $n;
        }
    }

    return (\%chars, \%codes);
}

sub read_freqs($is_char, @dicts) {
    my %weights;        # char/word => weight

    for (@dicts) {
        my $is_rime_dict = /\.dict\.yaml$/;

        open my $fh, '<', $_;

        if ($is_rime_dict) {
            while (<$fh>) {
                last if /^\.\.\./;
            }
        }

        while (<$fh>) {
            next if /^\s*#/;

            chomp;

            my @a;
            if ($is_rime_dict) {
                @a = split /\t/, $_, 3;
            } else {
                @a = split;
            }
            next unless $a[0] && (
                ($is_char && length($a[0]) == 1) ||
                (!$is_char && length($a[0]) > 1));

            my $weight = ($is_rime_dict ? $a[2] : $a[1]) // 0;
            $weights{$a[0]} = $weight;
        }

        close $fh;
    }

    return \%weights;
}

sub parse_unihan_variants($path) {
    my %variants;

    open my $fh, '<', $path;
    while (<$fh>) {
        chomp;

        my @a = split;
        next unless $a[2] && $a[0] =~ /^U\+/;

        if ($a[1] eq 'kTraditionalVariant') {
            map { $variants{to_char($_)}{to_char($a[0])} = 1 if $_ ne $a[0] } @a[2..$#a];
        } elsif ($a[1] eq 'kSimplifiedVariant') {
            map { $variants{to_char($a[0])}{to_char($_)} = 1 if $_ ne $a[0] } @a[2..$#a];
        }
    }
    close $fh;

    return \%variants;
}

sub to_char($codepoint) {
    return chr(hex(substr($codepoint, 2)));
}
