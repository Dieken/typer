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
    '隹' => 'cuī',
    '長' => 'cháng',
    '长' => 'cháng',
    '丶' => 'diǎn',
    '冫' => 'èr',
    '叀' => 'chē',
    '丆' => 'chǎng',
    '乀' => 'diǎn',
    '朩' => 'mù',
    '𡗗' => 'dí',
    '夊' => 'pū',
    '疒' => 'bìng',
    '屮' => 'cǎo',
    '卄' => 'cǎo',
    '廾' => 'cǎo',
    '卌' => 'sie',      # ???
    '㔾' => 'jié',
    '龰' => 'zhǐ',
    '巜' => 'chuān',
    '糸' => 'sī',
    '咼' => 'guǎ',
    '爪' => 'zhuǎ',
    '卜' => 'bǔ',
    '{卬左}' => '∅',
    '{乐上}' => '∅',
    '{卯左}' => '∅',
    '{齊右}' => '∅',
    '{衣下}' => '∅',
    '{畏下}' => '∅',
    '{乞上}' => '∅',
    '{亞下}' => '∅',
    '{亜下}' => '∅',
    '{亞中}' => '∅',
    '{介下}' => '∅',
    '{于下}' => '∅',
    '{京上}' => '∅',
    '{亮上}' => '∅',
    '{襄上}' => '∅',
    '{鼠下}' => '∅',
    '{穀框}' => '∅',
    '{囟框}' => '∅',
    '{奐上}' => '∅',
    '{曹上}' => '∅',
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

    next unless $code =~ /[^A-Za-z]$/;

    $code = fc(NFKD($code));
    my $len = length($code);

    $ym = NFKD($ym);
    $ym =~ s/\p{M}//g;
    $ym = 'ü' if $root eq '女';

    $ym = 'i' . $ym if $sm eq 'y' && $ym !~ /^[iu]/;
    $ym = 'u' . $ym if $sm eq 'w' && $ym !~ /^u/;
    $ym = 'r' . $ym if $sm eq 'r';
    $ym =~ s/^u/ü/ if $sm =~ /^[jqxy]/;

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

for (sort { $roots{$a} cmp $roots{$b} || $a cmp $b } keys %roots) {
    my $py = $pinyin{$_};
    if ($py) {
        say STDERR "$_\t", $roots{$_}{code}, "\t$py";
    } else {
        say STDERR "$_\t", $roots{$_}{code};
    }
}
