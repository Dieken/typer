#!/usr/bin/env perl
#
# 根据宇浩官网的拆分表，修正宇浩卿雲输入法的拆分表。
#
# Usage:
#   curl -s -o yuhao-chaifen.csv 'https://shurufa.app/chaifen.csv'
#   fix-yuhao-chaifen-dict.pl [yujoy_chaifen*.dict.yaml] yuhao-chaifen.csv

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

my $chaifen_file = shift || "yujoy_chaifen.dict.yaml";
my $chaifen_tw_file = shift || "yujoy_chaifen_tw.dict.yaml";
my $yuhao_chaifen_file = shift || "yuhao-chaifen.csv";

my $yuhao_chaifen = parse_yuhao_chaifen($yuhao_chaifen_file);
my %override_chaifen;

# yuhao-chaifen.csv     => expected-chaifen.dict.yaml,   # current-chaifen.dict.yaml
my %roots_mapping = (
    "爫" => "爫",        # not 爪
    "亅" => "亅",        # not 乙
    "礻" => "礻",        # not 示
    "" => "{𠇊右}",    # not {衣下}

# Find CJK chars mapping to {xxx}:
#   export LC_ALL=C; join -1 1 -2 2 <(sort roots-mapping.tsv) <(perl -CSDA -lnE 'print if /^\p{Han}\s+\{[^\}]+\}$/' chaifen.tsv | sort -u -k2,2) | perl -CSDA -lanE 'print "    \"$F[1]\" => \"$F[2]\",        # not \"$F[0]\"" unless $h{$F[1]}; $h{$F[1]} = 1'

    "" => "𠂉",        # not "{乞上}"
    "" => "𰀪",        # not "{二撇}"
    "" => "𬺰",        # not "{于下}"
    "" => "𫝀",        # not "{五下}"
    "" => "𠀎",        # not "{冓上}"
    "" => "𢆉",        # not "{南心}"
    "" => "𠂎",        # not "{卯左}"
    "" => "𬼖",        # not "{反彐}"
    "" => "𰃦",        # not "{向框}"
    "" => "⺆",        # not "{周框}"
    "" => "𰀁",        # not "{奉下}"
    "" => "𦣞",        # not "{姬右}"
    "" => "𦣝",        # not "{弬右}"
    "" => "𠁁",        # not "{斲左}"
    "" => "𫩏",        # not "{横日}"
    "" => "𣥂",        # not "{步下}"
    "" => "𱼀",        # not "{炙上}"
    "" => "𠃜",        # not "{眉上}"
    "" => "𫶧",        # not "{荒下}"
    "" => "𧘇",        # not "{衣下}"
    "" => "𧰨",        # not "{豕下}"
    "" => "𣎆",        # not "{贏框}"
    "" => "𠂤",        # not "{阜上}"
    "" => "𠂭",        # not "{鬯中}"
    "" => "𱍸",        # not "{齊右}"
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
