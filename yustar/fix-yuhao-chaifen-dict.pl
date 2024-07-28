#!/usr/bin/env perl
#
# 根据宇浩官网的拆分表，修正宇浩星陈输入法的拆分表。
#
# Usage:
#   curl -s -o yuhao-chaifen.csv 'https://yuhao.forfudan.com/chaifen.csv'
#   fix-yuhao-chaifen-dict.pl [yustar_chaifen*.dict.yaml] yuhao-chaifen.csv

use v5.36;                              # or later to get "unicode_strings" feature, plus strict and warnings
use utf8;                               # so literals and identifiers can be in UTF-8
use warnings qw(FATAL utf8);            # fatalize encoding glitches
use open     qw(:std :encoding(UTF-8)); # undeclared streams in UTF-8
use Encode   qw(decode encode);
@ARGV = map { decode('UTF-8', $_, Encode::FB_CROAK) } @ARGV;

use autodie;
use File::Basename;
use File::Compare;
use File::Temp qw(tempfile);
use Time::Piece;

my $chaifen_file = shift || "yustar_chaifen.dict.yaml";
my $chaifen_tw_file = shift || "yustar_chaifen_tw.dict.yaml";
my $yuhao_chaifen_file = shift || "yuhao-chaifen.csv";

my $yuhao_chaifen = parse_yuhao_chaifen($yuhao_chaifen_file);
my %override_chaifen;

# yuhao-chaifen.csv     => expected-chaifen.dict.yaml,   # current-chaifen.dict.yaml
my %roots_mapping = (
    '爫' => '爫',        # not 爪
    '⺈' => '⺈',        # not 冖
    '廾' => '廾',        # not 卄
    '' => '𠂇',        # not ナ
    '' => '𰀁',       # not キ
    '乙' => '乙',        # not 乛
    '㇆' => '㇆',        # not 乛
    '覀' => '覀',        # not 西
    '' => '𫩏',       # not 日
    '' => '{曾中}',     # not 日
    'ユ' => 'ユ',        # not コ

# Find CJK chars mapping to {xxx}:
#   join -1 1 -2 2 <(sort roots-mapping.tsv) <(perl -CSDA -lnE 'print if /^\P{PUA}\s+\{[^\}]+\}$/' chaifen.tsv | sort -k2,2) | perl -CSDA -lanE "print \"    '\$F[1]' => '\$F[2]',        # not \$F[0]\""

    '' => '𰀪',        # not {两撇}
    '' => '𬺰',        # not {于下}
    '' => '𫝀',        # not {五下}
    '' => '𠀎',         # not {冓上}
    '' => '𠂎',         # not {卯左}
    '' => '𰀄',        # not {反彐}
    '' => '𰃦',        # not {向框}
    '' => '𠃜',         # not {眉上}
    '' => '𫶧',        # not {荒下}
    '' => '𣎆',         # not {贏頭}
    '' => '𱍸',        # not {齊右}
    '' => '𪚴',        # not {龜下}
);

# https://github.com/forFudan/yuhao/issues/44
for (keys %$yuhao_chaifen) {
    for (my $i = 0; $i < 2; ++$i) {
        my $s = $yuhao_chaifen->{$_}[$i];
        $override_chaifen{$_}[$i] = [] if $s;

        for (my $j = 0; $j < length($s); ++$j) {
            my $c = substr($s, $j, 1);
            $override_chaifen{$_}[$i][$j] = $roots_mapping{$c} if exists $roots_mapping{$c};
        }
    }
}

fix($chaifen_file, 0);
fix($chaifen_tw_file, 1);

#######################################################################
sub parse_yuhao_chaifen($file) {
    my %h;

    open my $fh, "<", $file;
    while (<$fh>) {
        next if $. == 1;
        chomp;
        my @a = split /,/;
        next unless @a >= 3;
        $h{$a[0]} = [ @a[1..2] ];
    }
    close $fh;

    return \%h;
}

sub fix($file, $is_tw) {
    my ($out, $outfile) = tempfile(basename($file) . "-XXXXXX", DIR => dirname($file));

    open my $fh, "<", $file;

    while (<$fh>) {
        print $out encode("UTF-8", $_, Encode::FB_CROAK | Encode::LEAVE_SRC);
        last if /^\.\.\./;
    }

    while (<$fh>) {
        my ($char, $sep, $chaifen, $extra) = $_ =~ /^(\S+)(\s+\[)([^,]+)(.*)$/;
        my $chaifen2 = undef;
        if ($char && exists $override_chaifen{$char}) {
            $chaifen2 = $override_chaifen{$char}[$is_tw];
            $chaifen2 ||= $override_chaifen{$char}[0] if $is_tw;
        }
        unless ($char && $chaifen && $chaifen2) {
            print $out encode("UTF-8", $_, Encode::FB_CROAK);
            next;
        }

        my @a = $chaifen =~ /{[^}]+}|\S/g;
        my $b = $chaifen2;

        for (my $i = 0; $i < @$b; ++$i) {
            $a[$i] = $b->[$i] if $b->[$i];
        }

        print $out encode("UTF-8", "$char$sep" . join("", @a) . $extra . "\n", Encode::FB_CROAK);
    }

    close $fh;
    close $out;

    if (compare($file, $outfile) != 0) {
        rename($file, "$file-" . localtime->strftime("%Y%m%d-%H%H%S"));
        rename($outfile, $file);
    } else {
        unlink $outfile;
    }
}
