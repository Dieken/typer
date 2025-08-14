#!/usr/bin/env perl
#
# 分析宇浩·日月输入方案的字根声母、韵母的编码
#
# Usage:
#   ./analyze-roots-encoding.pl [roots.tsv] [../sbfd/UniHan_Readings.txt]

# https://perldoc.perl.org/perluniintro#Perl's-Unicode-Support  v5.28
# https://perldoc.perl.org/feature#The-'signatures'-feature     v5.36
# https://perldoc.perl.org/perlunicook#℞-0:-Standard-preamble   v5.36

use v5.36;                              # or later to get "unicode_strings" feature, plus strict and warnings
use utf8;                               # so literals and identifiers can be in UTF-8
use warnings qw(FATAL utf8);            # fatalize encoding glitches
use open     qw(:std :encoding(UTF-8)); # undeclared streams in UTF-8
use Encode   qw(decode);
@ARGV = map { decode('UTF-8', $_, Encode::FB_CROAK) } @ARGV;

use autodie;
use Unicode::Normalize;

my $roots_file = shift // 'roots.tsv';
my $UniHan_Readings_file = shift // '../sbfd/UniHan_Readings.txt';

my %pinyin;
open my $fh, '<', $UniHan_Readings_file;
while (<$fh>) {
    next unless /^U\+(\S+)\s+kMandarin\s+(\S+)/;
    $pinyin{chr(hex($1))} = $2;
}
close $fh;
undef $fh;

%pinyin = (%pinyin,
    '厂' => 'ān',
    '丆' => 'ān',
    '卜' => 'bǔ',
    '長' => 'cháng',
    '长' => 'cháng',
    '巜' => 'chuān',
    '叀' => 'chē',
    '隹' => 'cuī',
    '卄' => 'cǎo',
    '廾' => 'cǎo',
    '丷' => 'cǎo',  # 像「䒑」
    '𡗗' => 'dí',
    '丶' => 'diǎn',
    '乀' => 'diǎn',
    '丅' => 'dīng', # 像「丁」
    '土' => 'dù',   # 通「杜」
    '冫' => 'èr',
    '咼' => 'guǎ',
    '虫' => 'huì',
    '㔾' => 'jié',
    '朩' => 'mù',
    '夊' => 'pū',
    '糸' => 'sī',
    '乚' => 'yǐ',
    '爪' => 'zhuǎ',
    '龰' => 'zhǐ',

    '㐄' => '∅',
    '丩' => '∅',
    '冂' => '∅',
    '冖' => '∅',
    '勹' => '∅',
    '屮' => '∅',
    '耂' => '∅',

    #'{荒下}' => 'ér',
    #'{飞右}' => 'èr',
    #'{爲下}' => 'wéi',
    #'{微上}' => 'wēi',
);

my %roots;
my %encodings;
open $fh, '<', $roots_file;
while (<$fh>) {
    chomp;
    my ($root, $code) = split;
    my $py = $pinyin{$root} // '';

    if ($ENV{DEBUG}) {
        $py = NFKD($py);
        $py =~ s/\p{M}//g;
    }

    my ($sm, $ym) = $py ? $py =~ /([qwrtypsdfghjklzxcvbnm]*)(\S+)/: ('', '');

    $roots{$root} = {
        code => $code,
        py   => $py,
        sm   => $sm,
        ym   => $ym,
    };

    say STDERR "$root\t$code\t$py\t$sm\t$ym" if $ENV{DEBUG};

    # yusm-v3.9.1-beta.20250809 开始，yusm_chaifen.dict.yaml 中不再用圈字母表示韵码了
    next unless $code =~ /[^A-Za-z]$/ || $code =~ /[aeuio]$/;

    $code = fc(NFKD($code));
    my $len = length($code);

    $ym = NFKD($ym);
    $ym =~ s/\p{M}//g;
    $ym = 'ü' if $root eq '女';

    $ym = 'i' . $ym if $sm eq 'y' && $ym !~ /^[iu]/;
    $ym = 'u' . $ym if $sm eq 'w' && $ym !~ /^u/;
    $ym = 'r' . $ym if $sm eq 'r';
    $ym =~ s/^u/ü/ if $sm =~ /^[jqxy]/;

    # special case: https://shurufa.app/docs/sunmoon.html
    $ym = '[mp]u' if $sm =~ /^[mp]$/ && $ym eq 'u';
    if ($sm eq 'sh' && $ym eq 'i') {
        $ym = $root eq '士' ? '(sh)i/士' : '(sh)i';
    }
    if ($ym eq 'ian') {
        $sm =~ /^[qtdbx]$/ and $ym = '[qtdbx]ian' or $ym = '[pljmn]ian';
    }

    $encodings{substr($code, $len - 1)}{$ym} = 1 if $ym;

    if ($sm) {
        if ($len > 2) {
            $encodings{substr($code, 1, 1)}{$sm} = 1;
        } else {
            $encodings{'∅'}{$sm} = 1;
        }
    }
}
close $fh;

### check whether a yun-mu or sheng-mu is mapped to multiple keys
my %h;
for my $k (keys %encodings) {
    my $y = $encodings{$k};
    my @a = keys %$y;

    for (@a) {
        $h{$_}{$k} = 1;
    }
}
for my $k (sort keys %h) {
    my $y = $h{$k};
    my @a = sort keys %$y;

    say STDERR "[ERROR] multple mappings found for $k: ", join(' ', @a) if @a > 1;
}

### output mapping from key to yun-mu or sheng-mu
$encodings{'o'}{'∅'} = 1;
for my $k (sort keys %encodings) {
    my $y = $encodings{$k};
    my @a = sort keys %$y;

    for (@a) {
        say "$k\t$_" if $k ne $_;
    }
}

for (sort { $roots{$a}{code} cmp $roots{$b}{code} || $a cmp $b } keys %roots) {
    my $py = $pinyin{$_} // '';
    say STDERR "$_\t", $roots{$_}{code}, "\t$py";
}
