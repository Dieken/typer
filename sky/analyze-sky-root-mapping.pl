#!/usr/bin/env perl
#
# 分析天码输入法的拆分表，反推 {xxx} 字根到 PUA 字符的映射
#
# Usage:
#   curl -O http://soongsky.com/sky/java/div.js
#   analyze-sky-root-mapping.pl div.js path/to/天码拆分表/拆分表.txt

use v5.36;                              # or later to get "unicode_strings" feature, plus strict and warnings
use utf8;                               # so literals and identifiers can be in UTF-8
use warnings qw(FATAL utf8);            # fatalize encoding glitches
use open     qw(:std :encoding(UTF-8)); # undeclared streams in UTF-8
use Encode   qw(decode);
@ARGV = map { decode('UTF-8', $_, Encode::FB_CROAK) } @ARGV;

use autodie;
use Unicode::UCD qw/charblock prop_value_aliases/;

my $pua_chaifen_file = shift || "div.js";
my $chaifen_file = shift || "拆分表.txt";

my $pua_chaifen = parse_pua_chaifen($pua_chaifen_file);
my $chaifen = parse_chaifen($chaifen_file);

my $mapping = analyze($pua_chaifen, $chaifen);

for (sort { ord($mapping->{$a}[0]) <=> ord($mapping->{$b}[0]) or
            $mapping->{$b}[1] <=> $mapping->{$a}[1] or
            ord($a) <=> ord($b) } keys %$mapping) {
    say "$mapping->{$_}[0]\t$_";
}

sub parse_pua_chaifen($file) {
    my %h;

    open my $fh, "<", $file;
    while (<$fh>) {
        my ($char, $chaifens) = $_ =~ /"([^"]+)"[^"]+"([^"]+)"/;
        next unless $chaifens;

        my @a = split /·/, $chaifens;
        $h{$char} = \@a;
    }
    close $fh;

    return \%h;
}

sub parse_chaifen($file) {
    my %h;

    open my $fh, "<", $file;
    while (<$fh>) {
        next unless /^U\+/;
        chomp;

        my @a = split;
        next unless @a;
        $h{$a[1]} = [ @a[2 .. $#a] ];
    }
    close $fh;

    return \%h;
}

sub analyze($pua_chaifen, $chaifen) {
    my %h;

    say STDERR "pua_chaifen=", scalar(keys %$pua_chaifen), " chaifen=", scalar(keys %$chaifen);

    while (my ($k, $v) = each %$pua_chaifen) {
        if (! exists $chaifen->{$k}) {
            warn "$k from $pua_chaifen_file doesn't exist in $chaifen_file\n";
            next;
        }

        my $v2 = $chaifen->{$k};

        # XXX: 形近归并后的拆分少一个
        if (@$v == 2 && @$v2 == 1) {
            $v2->[1] = $v2->[0];
        }

        if (@$v != @$v2) {
            warn "$k has different division: [@$v] vs [@$v2]\n";
            next;
        }

        for (my $i = 0; $i < @$v; ++$i) {
            next if $v->[$i] eq $v2->[$i];

            my @a = $v->[$i] =~ /\S/g;
            my @b = $v2->[$i] =~ /{[^}]+}|\S/g;

            if (@a != @b) {
                warn "$k has inconsistent division: $v->[$i] vs $v2->[$i]\n";
                next;
            }

            for (my $j = 0; $j < @a; ++$j) {
                my $a = $a[$j];
                my $b = $b[$j];

                next if $a eq $b;

                if (exists $h{$a}) {
                    if ($h{$a}[0] ne $b) {
                        warn "$k has suspicious division: $a -> $h{$a}[0] vs $b\n";
                        next;
                    } else {
                        $h{$a}[1]++;
                    }
                } else {
                    $h{$a} = [$b, 0];
                }
            }
        }
    }

    return \%h;
}
