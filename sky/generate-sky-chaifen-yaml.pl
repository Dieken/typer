#!/usr/bin/env perl
#
# 更新「天碼·宇製」RIME 方案中的拆分表
#
# Usage:
#   ./generate-sky-chaifen-yaml.pl 天碼·宇製_20241031/sky_chaifen.dict.yaml 天码拆分表/拆分表.txt 天码拆分表/字根表.txt > sky_chaifen.dict.yaml

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

my ($chaifen_yaml_file, $chaifen_file, $roots_file) = @ARGV;
my $chaifen = read_chaifen_file($chaifen_file);
#my $chars = read_full_char_file($full_char_file);
my $roots = read_roots_file($roots_file);

my $skip = 1;
open my $fh, '<', $chaifen_yaml_file;
while (<$fh>) {
    print if $skip;

    if (/^\.\.\.\s*$/) {
        $skip = 0;
        next;
    }

    next if $skip;

    if (/^\s*$/ || /^\s*#/) {
        print;
        next;
    }

    chomp;

    my @a = split /\t/, $_, 2;

    die "找不到拆分：$_\n" unless exists $chaifen->{$a[0]};
    my @cf = @{ $chaifen->{$a[0]} };
    @cf = @cf[0..2, @cf - 1] if @cf > 4;

    my $code = '';
    if (@cf == 1) {
        my $r1 = $roots->{$cf[0]};
        $code = $r1->[0] . circlefy2($r1->[1]);
    } elsif (@cf == 2) {
        my $r1 = $roots->{$cf[0]};
        my $r2 = $roots->{$cf[1]};
        $code = substr($r1->[0], 0, 1) . $r2->[0] . circlefy(substr($r1->[0], 1, 1));
        $code =~ s/ⓥ$//;
    } elsif (@cf == 3) {
        my $r1 = $roots->{$cf[0]};
        my $r2 = $roots->{$cf[1]};
        my $r3 = $roots->{$cf[2]};
        $code = join('', map { substr($_->[0], 0, 1) } ($r1, $r2)) . $r3->[0];
    } elsif (@cf == 4) {
        my $r1 = $roots->{$cf[0]};
        my $r2 = $roots->{$cf[1]};
        my $r3 = $roots->{$cf[2]};
        my $r4 = $roots->{$cf[3]};
        $code = join('', map { substr($_->[0], 0, 1) } ($r1, $r2, $r3, $r4));
    } else {
        die "空的拆分: $_\n";
    }

    $a[1] =~ s/^\[(?:[^,]*,){2}//;
    print "$a[0]\t[", join('', @cf), ",$code,$a[1]\n";
}
close $fh;

sub read_chaifen_file($file) {
    my %h;
    open my $fh, '<', $file;
    while (<$fh>) {
        chomp;
        my @a = split;      # 每行第一个拆分是正式拆分，后面的是兼容拆分
        my @roots = $a[2] =~ /\{[^\}]+\}|\S/g;
        die "拆分表有重复单字： $_\n" if exists $h{$a[1]};
        $h{$a[1]} = \@roots;
    }
    close $fh;
    return \%h;
}

sub read_full_char_file($file) {
    my %h;
    open my $fh, '<', $file;
    while (<$fh>) {
        chomp;
        my @a = split;
        next if exists $h{$a[1]};   # 靠前的是正式拆分对应的全码
        $h{$a[0]} = $a[1];
    }
    close $fh;
    return \%h;
}

sub read_roots_file($file) {
    my %h;
    open my $fh, '<', $file;
    while (<$fh>) {
        chomp;
        my @a = split;
        $h{$a[0]} = [ucfirst($a[1]), $a[2] // ''];
    }
    close $fh;
    return \%h;
}

sub circlefy($s) {
    $s =~ tr/abcdefghijklmnopqrstuvwxyz/ⓐⓑⓒⓓⓔⓕⓖⓗⓘⓙⓚⓛⓜⓝⓞⓟⓠⓡⓢⓣⓤⓥⓦⓧⓨⓩ/r;
}

sub circlefy2($s) {
    $s =~ tr/abcdefghijklmnopqrstuvwxyz/ⒶⒷⒸⒹⒺⒻⒼⒽⒾⒿⓀⓁⓂⓃⓄⓅⓆⓇⓈⓉⓊⓋⓌⓍⓎⓏ/r;
}
