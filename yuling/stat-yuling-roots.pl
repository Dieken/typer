#!/usr/bin/env perl

# https://perldoc.perl.org/perluniintro#Perl's-Unicode-Support  v5.28
# https://perldoc.perl.org/feature#The-'signatures'-feature     v5.36
# https://perldoc.perl.org/perlunicook#℞-0:-Standard-preamble   v5.36

use v5.36;                              # or later to get "unicode_strings" feature, plus strict and warnings
use utf8;                               # so literals and identifiers can be in UTF-8
use warnings qw(FATAL utf8);            # fatalize encoding glitches
use open     qw(:std :encoding(UTF-8)); # undeclared streams in UTF-8
use Encode   qw(decode);
@ARGV = map { decode('UTF-8', $_, Encode::FB_CROAK) } @ARGV;

use Getopt::Long;
use List::Util qw/min sum/;
use Term::ANSIColor;
use autodie;

my $zigen_file = "zigen-ling.csv";
my $chaifen_file = "chaifen.csv";
my $mabiao_file = "mabiao_sc.tsv";
my $freq_file = "../简体字频表-2.5b.txt";
my $is_color = 1;
my $is_simplified = 0;

GetOptions(
    "zigen=s", \$zigen_file,
    "chaifen=s", \$chaifen_file,
    "mabiao=s", \$mabiao_file,
    "freq=s", \$freq_file,
    "simplified!", \$is_simplified,
    "color!", \$is_color) or die "Error in options\n";

my $roots = read_csv($zigen_file, 1);
my $chaifen = read_csv($chaifen_file, 1);
my $mabiao = read_csv($mabiao_file);
my $freqs = read_csv($freq_file);

{
    my $num_roots = 0;
    my $num_roots2 = 0;
    my $num_roots3 = 0;
    my $num_rootso = 0;
    my %codes;
    my %comments;

    while (my ($k, $v) = each %$roots) {
        $codes{$v->[1]} = 1;

        if ($v->[2] && $v->[2] =~ /(🈤\S+)/) {
            $comments{$1}++;
        }

        $num_roots++;
        if (length($v->[1]) == 2) {
            $num_roots2++;
            $num_rootso++ if $v->[1] =~ /o$/;
        } else {
            $num_roots3++;
        }
    }

    printf "%6d : %s\n",  $num_roots,         "总字根数";
    printf "%6d : %s\n",  scalar keys %codes, "归并字根组数";
    printf "%6d : %s\n",  $num_roots2,        "两码字根数";
    printf "%6d : %s\n",  $num_roots3,        "三码字根数";
    printf "%6d : %s\n",  $num_rootso,        "两码韵码取o字根数";

    for (sort keys %comments) {
        printf "%6d : %s\n", $comments{$_}, $_;
    }

    print "\n";
}

{
    my $skips = 0;
    my $noskips = 0;
    my $skip_freqs = 0.0;
    my $noskip_freqs = 0.0;

    while (my ($k, $v) = each %$chaifen) {
        next if length($v->[1]) < 4;
        next if $k !~ /^\p{Han}$/;

        my $r1 = substr($v->[1], 0, 1);
        my $n = length($roots->{$r1}[1]);

        if ($n == 2) {
            $noskips++;
            $noskip_freqs += $freqs->{$k}[1] if exists $freqs->{$k};
        } else {
            $skips++;
            $skip_freqs += $freqs->{$k}[1] if exists $freqs->{$k};
        }
    }

    printf "%2.2f%% : %s\n", 100.0 * $skip_freqs/($skip_freqs + $noskip_freqs), "四根字跳根字频比例";
    printf "%2.2f%% : %s\n", 100.0 * $noskip_freqs/($skip_freqs + $noskip_freqs), "四根字不跳根字频比例";
    print "\n";
    printf "%2.2f%% : %s\n", 100.0 * $skips/($skips + $noskips), "四根字跳根字数比例";
    printf "%2.2f%% : %s\n", 100.0 * $noskips/($skips + $noskips), "四根字不跳根字数比例";
    print "\n";
}

{
    my %codes;

    open my $fh, "<", $freq_file;
    while (<$fh>) {
        chomp;
        my @a = split /[,\t]/;
        my $c = $mabiao->{$a[0]}[1];
        $codes{$c}{$.} = $a[0];

        if ($. % 1500 == 0 || ($. <= 1500 && $. % 500 == 0)) {
            my $dup_groups = 0;
            my $dup_chars = 0;
            my %dups;

            while (my ($k, $v) = each %codes) {
                next if keys %$v == 1;
                $dup_groups++;
                $dup_chars += keys %$v;
                $dups{$k} = {
                    chars => $v,
                    seq_min => min(keys %$v),
                    seq_sum => sum(keys %$v),
                };
            }

            printf "前 %4d 重码组数 : %d\n", $., $dup_groups;
            printf "前 %4d 重码字数 : %d\n", $., $dup_chars;
            print "\n";

            unless ($is_simplified) {
                my $i = 0;
                for my $k (sort { $dups{$a}{seq_min} <=> $dups{$b}{seq_min} or
                        $dups{$a}{seq_sum} <=> $dups{$b}{seq_sum} } keys %dups) {
                    $i++;
                    my $chars = $dups{$k}{chars};
                    printf "    前 %4d 重码组 : %3d    %s\n", $., $i,
                           join(" ", map { colorize($chars->{$_}, $_) } sort { $a <=> $b } keys %$chars);
                }

                print "\n";
            }
        }

        last if $. == 6000;
    }
    close $fh;
}

######################################################################
sub read_csv($file, $skip_header = 0) {
    my %h;

    open my $fh, "<", $file;
    while (<$fh>) {
        next if $. == 1 && $skip_header;

        chomp;
        my @a = split /[,\t]/;
        next unless @a >= 2;

        $h{$a[0]} = \@a;
    }
    close $fh;

    return \%h;
}

sub colorize($char, $seq) {
    if ($is_color) {
        if ($seq <= 500) {
            return colored("$char/$seq", "red");
        } elsif ($seq <= 1000) {
            return colored("$char/$seq", "magenta");
        } elsif ($seq <= 1500) {
            return colored("$char/$seq", "cyan");
        }
    }

    return "$char/$seq";
}
