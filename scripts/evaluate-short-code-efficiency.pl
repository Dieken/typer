#!/usr/bin/env perl
#
# Purpose:
#   评估中文输入法的简码效率，输出使用 N 个简码时的加权码长，
#   参考 https://shurufa.app/docs/statistics.html#%E7%AE%80%E7%A0%81%E6%95%88%E7%8E%87
#
# Usage:
#   ./evaluate-short-code-efficiency.pl [OPTIONS] xxx.dict.yaml...

use v5.36;                              # or later to get "unicode_strings" feature, plus strict and warnings
use utf8;                               # so literals and identifiers can be in UTF-8
use warnings qw(FATAL utf8);            # fatalize encoding glitches
use open     qw(:std :encoding(UTF-8)); # undeclared streams in UTF-8
use Encode   qw(decode);
@ARGV = map { decode('UTF-8', $_, Encode::FB_CROAK) } @ARGV;

use autodie;
use FindBin;
use Getopt::Long;
use List::Util qw(max uniqint uniqstr);
use Unicode::UCD qw(charblock);

my $frequency_file = "$FindBin::Bin/../简体字频表-2.5b.txt";
my $exclude_codes_pattern;
my $ding_codes_pattern;
my @steps = (0, 5, 6, 10, 25, 26, 30, 50, 100, 150, 200, 250, 300, 350, 400, 450, 500, 550, 600, 650, 700, 750, 800, 850, 900, 950, 1000);

GetOptions(
    "frequency=s"       => \$frequency_file,
    "exclude-codes=s"   => \$exclude_codes_pattern,
    "ding-codes=s"      => \$ding_codes_pattern,
);

$exclude_codes_pattern = qr/$exclude_codes_pattern/ if $exclude_codes_pattern;;
$ding_codes_pattern = qr/$ding_codes_pattern/ if $ding_codes_pattern;

my $freq = read_frequency($frequency_file);
my ($chars, $codes) = read_dicts(@ARGV);
my $max_code_length = max map { length($_) } keys %$codes;

my @short_codes;

while (my ($k, $v) = each %$chars) {
    next unless @$v > 1;

    my $full_code_length = code_length($v->[-1]);

    for (my $i = 0; $i < @$v - 1; ++$i) {
        my $short_code_length = code_length($v->[$i]);

        # 没有考虑出简码后，全码后置，导致其它字可能前移跨过翻页的情况，
        # 也没有考虑候选字所处页面对全码长的影响。
        push @short_codes, {
            char    => $k,
            code    => $v->[$i],
            length  => $short_code_length,
            weight  => $freq->{$k} * ($full_code_length - $short_code_length),
        }
    }
}

@short_codes = sort { $b->{weight} <=> $a->{weight} ||
                      $a->{length} <=> $b->{length} ||
                      charblock(ord($a->{char})) cmp charblock(ord($b->{char})) ||
                      ord($a->{char}) <=> ord($b->{char}) } @short_codes;

push @steps, scalar(@short_codes);
@steps = sort { $a <=> $b } uniqint @steps;

for my $step (@steps) {
    last if $step > @short_codes;

    my %short_chars;
    my $total_length = 0.0;
    my $total_freq = 0.0;

    for my $short_code (@short_codes) {
        last if keys(%short_chars) >= $step;

        my $char = $short_code->{char};
        next if exists $short_chars{$char};
        $short_chars{$char} = 1;

        $total_length += $short_code->{length} * $freq->{$char};
        $total_freq += $freq->{$char};
    }

    for my $char (keys %$chars) {
        next if exists $short_chars{$char};

        my $full_code_length = code_length($chars->{$char}->[-1]);

        $total_length += $full_code_length * $freq->{$char};
        $total_freq += $freq->{$char};
    }

    printf "%4d\t%.3f\n", $step, $total_length / $total_freq;
}

#######################################################################
sub read_frequency($file) {
    my %freq;

    open my $fh, "<", $file;
    while (<$fh>) {
        chomp;
        my @a = split;
        next unless @a >= 2 && length($a[0]) == 1 && $a[1] =~ /^[0-9\.]+$/;
        die "Duplicated char found on line $.: $_\n" if exists $freq{$a[0]};
        $freq{$a[0]} = $a[1];
    }
    close $fh;

    return \%freq;
}

sub read_dicts(@files) {
    my %all_chars;
    my %all_codes;

    for my $file (@files) {
        read_dict($file, \%all_chars, \%all_codes);
    }

    normalize_dict(\%all_chars, \%all_codes);

    return (\%all_chars, \%all_codes);
}

# all_chars: { char => [code1, code2, ...] }, no order
# all_codes: { code => [char1, char2, ...] }, order by weight
sub read_dict($file, $all_chars, $all_codes) {
    my $sort_by_weight = 1;

    open my $fh, "<", $file;

    if ($file =~ /\.dict.yaml/) {
        while (<$fh>) {
            $sort_by_weight = 0 if /^\s*sort\s*:\s*original/;
            last if /^\.\.\./;
        }
    }

    my %codes;  # code -> char -> weight
    while (<$fh>) {
        next if /^\s*#/;

        chomp;
        my @a = split /\t/;
        next unless @a >= 2 && exists $freq->{$a[0]};

        my $char = $a[0];
        my $code = "";
        my $weight = 0;

        if ($a[1] =~ /^[0-9\.]+$/) {
            $weight = $sort_by_weight ? $a[1] : -$.;

            die "Miss code after weight in file $file:$.: $_\n" unless $a[2];
            $code = $a[2];
        } else {
            $code = $a[1];
            die "Invalid weight in file $file:$.: $_\n" unless !defined($a[2]) || $a[2] =~ /^[0-9\.]+$/;
            $weight = $sort_by_weight ? ($a[2] // 0) : -$.;
        }

        next if $exclude_codes_pattern && $code =~ $exclude_codes_pattern;

        warn "Duplicated char and code in $file:$.: $_\n" if exists $codes{$code}{$char};
        $codes{$code}{$char} = $weight;

        push @{ $all_chars->{$char} }, $code;
    }

    while (my ($k, $v) = each %codes) {
        my @chars = sort { $v->{$b} <=> $v->{$a} || $a cmp $b } keys %$v;

        push @{ $all_codes->{$k} }, @chars;
    }

    close $fh;
}

# 按码长排序 %$all_chars 中的 codes 并去重;
# 去除 %$all_codes 中的重复 chars;
sub normalize_dict($all_chars, $all_codes) {
    for my $char (keys %$all_chars) {
        my $codes = $all_chars->{$char};
        $all_chars->{$char} = [ sort { length($a) <=> length($b) || $a cmp $b } uniqstr @$codes ];
    }

    for my $code (keys %$all_codes) {
        my $chars = $all_codes->{$code};
        my @chars = uniqstr @$chars;

        $all_codes->{$code} = \@chars;
    }
}

sub code_length($code) {
    my $len = length($code);

    --$len if $code =~ /_$/;    # 末尾有下划线表示空格简码

    ++$len unless $len == $max_code_length ||
                  ($ding_codes_pattern && $code =~ $ding_codes_pattern);

    return $len;
}
