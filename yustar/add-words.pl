#!/usr/bin/env perl
#
# Purpose:
#   add words from https://github.com/gaboolic/rime-frost
#
# Usage:
#   export R=$HOME/Library/Rime
#   a=$(grep '^\s*-\s\+yuhao/' $R/yustar_sc.dict.yaml | perl -lpE 's/\r//; s/^\s*\-\s*/-o $ENV{R}\//; s/$/.dict.yaml/')
#   ./add-words.pl $a -n cn_dicts/base.dict.yaml > yuhao.extended.tsv
#   echo >> $R/yuhao/yuhao.extended.dict.yaml
#   cat yuhao.extended.tsv >> $R/yuhao/yuhao.extended.dict.yaml

use v5.36;                              # or later to get "unicode_strings" feature, plus strict and warnings
use utf8;                               # so literals and identifiers can be in UTF-8
use warnings qw(FATAL utf8);            # fatalize encoding glitches
use open     qw(:std :encoding(UTF-8)); # undeclared streams in UTF-8
use Encode   qw(decode);
@ARGV = map { decode('UTF-8', $_, Encode::FB_CROAK) } @ARGV;

use autodie;
use Getopt::Long;
use List::Util qw/uniqstr/;

my @old_dicts;
my @new_dicts;

GetOptions(
    'old-dict=s' => \@old_dicts,
    'new-dict=s' => \@new_dicts,
);

my ($chars, $words) = read_old_dicts(@old_dicts);
my $new_words = read_new_dicts(@new_dicts);

say STDERR "characters: ", scalar keys %$chars;
say STDERR "words: ", scalar keys %$words;
say STDERR "new words: ", scalar @$new_words;

my @added_words;

for my $word (@$new_words) {
    my @codes = calc_codes($word, $chars);

    for my $code (@codes) {
        if (! exists $words->{$code} || keys %{ $words->{$code} } < 3) {
            if (! exists $words->{$code}{$word}) {
                $words->{$code}{$word} = 1;
                push @added_words, [$word, $code];
            }
        }
    }
}

@added_words = sort { $a->[1] cmp $b->[1] } @added_words;

say STDERR "added words: ", scalar @added_words;
for (@added_words) {
    say $_->[0], "\t", $_->[1];
}

#######################################################################
sub read_old_dicts(@dict) {
    my %chars;
    my %words;

    for my $dict (@dict) {
        open my $fh, '<', $dict;

        while (<$fh>) {
            last if /^\.\.\./;
        }

        while (<$fh>) {
            chomp;

            my @a = split;
            next unless $a[0] && $a[0] =~ /^\p{Han}/ && length($a[1]) >= 2;

            if (length($a[0]) == 1) {       # char
                if (exists $chars{$a[0]}) {
                    my $found = 0;

                    for (@{ $chars{$a[0]} }) {
                        my $len1 = length($_);
                        my $len2 = length($a[1]);

                        if ($len1 < $len2) {
                            if ($_ eq substr($a[1], 0, $len1)) {
                                $found = 1;
                                $_ = $a[1];
                                last;
                            }
                        } else {
                            if ($a[1] eq substr($_, 0, $len2)) {
                                $found = 1;
                                last;
                            }
                        }
                    }

                    if (! $found) {
                        push @{ $chars{$a[0]} }, $a[1];
                    }
                } else {
                    $chars{$a[0]} = [ $a[1] ];
                }

            } else {                # word
                $words{$a[1]}{$a[0]} = 1;
            }
        }

        close $fh;
    }

    while (my ($k, $v) = each %chars) {
        my @a = sort { length($b) <=> length($a) || $a cmp $b } @$v;
        for (my $i = 1; $i < @a; ++$i) {
            if (length($a[$i]) < length($a[0])) {
                splice @a, $i;
                last;
            }
        }

        @a = uniqstr map { substr($_, 0, 2) } @a;
        $chars{$k} = \@a;
    }

    return (\%chars, \%words);
}

sub read_new_dicts(@dicts) {
    my %words;

    for (@dicts) {
        open my $fh, '<', $_;

        while (<$fh>) {
            last if /^\.\.\./;
        }

        while (<$fh>) {
            chomp;

            my @a = split /\t/, $_, 3;
            next unless $a[0] && $a[0] =~ /^\p{Han}/ && length($a[0]) >= 2;

            $words{$a[0]} = $a[2] // 0;     # word => weight
        }

        close $fh;
    }

    my @a = sort { $words{$b} <=> $words{$a} || $a cmp $b } keys %words;
    return \@a;
}

sub calc_codes($word, $chars) {
    my $len = length($word);
    my $c1 = substr($word, 0, 1);
    my $c2 = substr($word, 1, 1);

    my @codes;

    if ($len == 2) {
        if (exists $chars->{$c1} && exists $chars->{$c2}) {
            for my $i (@{ $chars->{$c1} }) {
                for my $j (@{ $chars->{$c2} }) {
                    push @codes, $i . $j;
                }
            }
        }
    } elsif ($len == 3) {
        my $c3 = substr($word, 2, 1);

        if (exists $chars->{$c1} && exists $chars->{$c2} && exists $chars->{$c3}) {
            for my $i (@{ $chars->{$c1} }) {
                for my $j (@{ $chars->{$c2} }) {
                    for my $k (@{ $chars->{$c3} }) {
                        push @codes, substr($i, 0, 1) . substr($j, 0, 1) . $k;
                    }
                }
            }
        }
    } elsif ($len >= 4) {
        my $c3 = substr($word, 2, 1);
        my $c4 = substr($word, -1, 1);

        if (exists $chars->{$c1} && exists $chars->{$c2} && exists $chars->{$c3} && exists $chars->{$c4}) {
            for my $i (@{ $chars->{$c1} }) {
                for my $j (@{ $chars->{$c2} }) {
                    for my $k (@{ $chars->{$c3} }) {
                        for my $l (@{ $chars->{$c4} }) {
                            push @codes, substr($i, 0, 1) . substr($j, 0, 1) . substr($k, 0, 1) . substr($l, 0, 1);
                        }
                    }
                }
            }
        }
    }

    return @codes;
}
