#!/usr/bin/env perl
#
# Purpose:
#   add words for 宇浩·日月
#
# Usage:
#   ./add-words.pl OPTIONS [some.dict.yaml|some-dict.txt]...

use v5.36;                              # or later to get "unicode_strings" feature, plus strict and warnings
use utf8;                               # so literals and identifiers can be in UTF-8
use warnings qw(FATAL utf8);            # fatalize encoding glitches
use open     qw(:std :encoding(UTF-8)); # undeclared streams in UTF-8
use Encode   qw(decode);
@ARGV = map { decode('UTF-8', $_, Encode::FB_CROAK) } @ARGV;

use autodie;
use Getopt::Long;
use Time::Piece;
use Unicode::Normalize qw(NFKD);

my $chaifen = $ENV{DICT_FILE} ? $ENV{DICT_FILE} : "$ENV{HOME}/Library/Rime/yusm_chaifen.dict.yaml";
my $dict_name = 'yusm.words_extra';
my $min_weight = 0;

GetOptions(
    'chaifen=s'     => \$chaifen,
    'name=s'        => \$dict_name,
    'weight=i'      => \$min_weight,
);

print STDERR "chaifen: $chaifen\n";
print STDERR "dict_name: $dict_name\n";
print STDERR "min_weight: $min_weight\n";

my $is_yusm = $chaifen =~ /yusm.*chaifen\.dict\.yaml/;
my $chars = $is_yusm ? read_chaifen($chaifen) : read_mabiao($chaifen);
print STDERR "chars: ", scalar(keys %$chars), "\n\n";

if ($dict_name) {
    my $version = localtime->strftime('%Y%m%d');
    print <<"END";
# encoding: utf-8
---
name: "$dict_name"
version: "$version"
sort: by_weight
columns:
  - text
  - code
  - weight
...

END
}

while (<>) {
    next if /^\s*#/;

    chomp;

    my @a = split /\t/;
    next unless @a >= 2;

    my $word = $a[0];
    my $weight = $a[$#a];
    $weight = 0 if $weight =~ /[^0-9]/;

    next unless $word =~ /^\p{Han}{2,}$/ && $weight >= $min_weight;

    my $code = $is_yusm ? gen_yusm_dict($word) : gen_fixed4_dict($word);
    next unless $code;

    $code = lc(substr($code, 0, 5));
    print "$word\t$code\t$weight\n";
}

sub gen_yusm_dict($word) {
    my $code = "";
    my $n = length($word);

    if ($n == 2) {
        my $c1 = substr($word, 0, 1);
        my $c2 = substr($word, 1, 1);

        if (exists $chars->{$c1} && exists $chars->{$c2}) {
            $c1 = substr($chars->{$c1}, 0, 2);
            return "" if $c1 =~ /[aeuio]$/;

            $c2 = last_code($chars->{$c2}, 2);
            $code = "$c1$c2";
        } else {
            warn "Missing char for: $word\n";
        }
    } elsif ($n == 3) {
        my $c1 = substr($word, 0, 1);
        my $c2 = substr($word, 1, 1);
        my $c3 = substr($word, 2, 1);

        if (exists $chars->{$c1} && exists $chars->{$c2} && exists $chars->{$c3}) {
            $c1 = substr($chars->{$c1}, 0, 1);
            $c2 = substr($chars->{$c2}, 0, 1);
            $c3 = last_code($chars->{$c3}, 2);
            $code = "$c1$c2$c3";
        } else {
            warn "Missing char for: $word\n";
        }
    } elsif ($n == 4) {
        my $c1 = substr($word, 0, 1);
        my $c2 = substr($word, 1, 1);
        my $c3 = substr($word, 2, 1);
        my $c4 = substr($word, 3, 1);

        if (exists $chars->{$c1} && exists $chars->{$c2} && exists $chars->{$c3} && exists $chars->{$c4}) {
            $c1 = substr($chars->{$c1}, 0, 1);
            $c2 = substr($chars->{$c2}, 0, 1);
            $c3 = substr($chars->{$c3}, 0, 1);
            $c4 = last_code($chars->{$c4}, 1);
            $code = "$c1$c2$c3$c4";
        } else {
            warn "Missing char for: $word\n";
        }
    } else {
        my $c1 = substr($word, 0, 1);
        my $c2 = substr($word, 1, 1);
        my $c3 = substr($word, 2, 1);
        my $c4 = substr($word, 3, 1);
        my $c5 = substr($word, $n - 1, 1);

        if (exists $chars->{$c1} && exists $chars->{$c2} && exists $chars->{$c3} && exists $chars->{$c4} && exists $chars->{$c5}) {
            $c1 = substr($chars->{$c1}, 0, 1);
            $c2 = substr($chars->{$c2}, 0, 1);
            $c3 = substr($chars->{$c3}, 0, 1);
            $c4 = substr($chars->{$c4}, 0, 1);
            $c5 = substr($chars->{$c5}, 0, 1);
            $code = "$c1$c2$c3$c4$c5";
        } else {
            warn "Missing char for: $word\n";
        }
    }

    return $code;
}

sub gen_fixed4_dict($word) {
    my $code = "";
    my $n = length($word);

    if ($n == 2) {
        my $c1 = substr($word, 0, 1);
        my $c2 = substr($word, 1, 1);

        if (exists $chars->{$c1} && exists $chars->{$c2}) {
            $code = substr($chars->{$c1}, 0, 2) . substr($chars->{$c2}, 0, 2);
        } else {
            #warn "Missing char for: $word\n";
        }
    } elsif ($n == 3) {
        my $c1 = substr($word, 0, 1);
        my $c2 = substr($word, 1, 1);
        my $c3 = substr($word, 2, 1);

        if (exists $chars->{$c1} && exists $chars->{$c2} && exists $chars->{$c3}) {
            $code = substr($chars->{$c1}, 0, 1) . substr($chars->{$c2}, 0, 1) . substr($chars->{$c3}, 0, 2);
        } else {
            #warn "Missing char for: $word\n";
        }
    } else {
        my $c1 = substr($word, 0, 1);
        my $c2 = substr($word, 1, 1);
        my $c3 = substr($word, 2, 1);
        my $c4 = substr($word, $n - 1, 1);

        if (exists $chars->{$c1} && exists $chars->{$c2} && exists $chars->{$c3} && exists $chars->{$c4}) {
            $code = substr($chars->{$c1}, 0, 1) . substr($chars->{$c2}, 0, 1) . substr($chars->{$c3}, 0, 1) . substr($chars->{$c4}, 0, 1);
        } else {
            #warn "Missing char for: $word\n";
        }
    }

    return $code;
}

sub read_chaifen($file) {
    my %chars;

    open my $fh, '<', $file;
    while (<$fh>) {
        last if /^\.\.\./;
    }

    while (<$fh>) {
        my @a = split;
        next unless $a[1] && $a[1] =~ /^\[[^,]+,([^,]+),/;
        $chars{$a[0]} = NFKD($1);
    }

    close $fh;

    return \%chars;
}

sub read_mabiao($file) {
    my %chars;

    open my $fh, '<', $file;

    if ($file =~ /\.dict.\.yaml/) {
        while (<$fh>) {
            last if /^\.\.\./;
        }
    }

    while (<$fh>) {
        chomp;
        my @a = split;
        next unless $a[1] && $a[0] =~ /^\p{Han}$/ && $a[1] =~ /^[a-z]+$/;
        $chars{$a[0]} = $a[1] if !exists $chars{$a[0]} || length($a[1]) > length($chars{$a[0]});
    }

    close $fh;

    return \%chars;
}

sub last_code($code, $n) {
    my $c1 = substr($code, 0, $n);
    if (length($code) > $n) {
        my ($c2) = substr($code, $n) =~ /([A-Z][a-z]*)$/;
        if ($c2) {
            $c1 .= $c2;
        } else {
            $c1 = $code;
        }
    }

    return $c1;
}
