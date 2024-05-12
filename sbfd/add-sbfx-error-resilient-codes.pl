#!/usr/bin/env perl
#
# 为声笔飞系包含声笔字的二字词、三字词生成容错码，目前只支持声笔飞码。
#
# Usage:
#   ./add-sbfx-error-resilient-codes.pl path/to/github.com/sbsrf/sbsrf/sbxlm [声笔字.tsv]
#   cp path/to/github.com/sbsrf/sbsrf/sbxlm/sbfm.extended.dict.yaml.resilient ~/Library/Rime/sbfm.extended.dict.yaml
#   "/Library/Input Methods/Squirrel.app/Contents/MacOS/rime_deployer" --compile build/sbfm2.schema.yaml

use v5.36;                              # or later to get "unicode_strings" feature, plus strict and warnings
use utf8;                               # so literals and identifiers can be in UTF-8
use warnings qw(FATAL utf8);            # fatalize encoding glitches
use open     qw(:std :encoding(UTF-8)); # undeclared streams in UTF-8
use Encode   qw(decode);
@ARGV = map { decode('UTF-8', $_, Encode::FB_CROAK) } @ARGV;

use autodie;

my $sbfm_extended_dict_file = ($ARGV[0] // ".") . "/sbfm.extended.dict.yaml";
#my $sbfd_dict_file = ($ARGV[0] // ".") . "/sbfd.dict.yaml";
my $sb_char_file = $ARGV[1] // "声笔字.tsv";

my %sb_chars;
#my %sp_chars;
my ($fh, $fh2);

open $fh, "<", $sb_char_file;
while (<$fh>) {
    chomp;
    my @a = split;
    if ($a[0] =~ /^\p{Han}$/ && $a[3] =~ /^[a-z]$/) {
        $sb_chars{$a[0]} = $a[3];
        #$sp_chars{substr($a[1], 0, 1) . $a[3]} = $a[0];
    }
}
close $fh;
undef $fh;

print "writing to $sbfm_extended_dict_file.resilient ...\n";
open $fh2, ">", "$sbfm_extended_dict_file.resilient";
open $fh, "<", $sbfm_extended_dict_file;
while (<$fh>) {
    print $fh2 $_;

    # 二字词和三字词
    my ($word, $sep, $code, $extra) = $_ =~ /^(\p{Han}{2,3})(\s+)([a-z]{4})(.*)$/;
    next unless $extra;

    if (length($word) == 2) {
        my $s1 = $code;
        substr($s1, 1, 1) = $sb_chars{substr($word, 0, 1)} if exists $sb_chars{substr($word, 0, 1)};
        print $fh2 "$word$sep$s1$extra\n" if $s1 ne $code;

        my $s2 = $code;
        substr($s2, 3, 1) = $sb_chars{substr($word, 1, 1)} if exists $sb_chars{substr($word, 1, 1)};
        print $fh2 "$word$sep$s2$extra\n" if $s2 ne $code;

        my $s3 = $s2;
        substr($s3, 1, 1) = $sb_chars{substr($word, 0, 1)} if exists $sb_chars{substr($word, 0, 1)};
        print $fh2 "$word$sep$s3$extra\n" if $s3 ne $code && $s3 ne $s1 && $s3 ne $s2;
    } else {
        my $s = $code;
        substr($s, 3, 1) = $sb_chars{substr($word, 2, 1)} if exists $sb_chars{substr($word, 2, 1)};
        print $fh2 "$word$sep$s$extra\n" if $s ne $code;
    }
}
close $fh; undef $fh;
close $fh2; undef $fh2;

#print "writing to $sbfd_dict_file.resilient ...\n";
#open $fh2, ">", "$sbfd_dict_file.resilient";
#open $fh, "<", "$sbfd_dict_file";
#while (<$fh>) {
#    print $fh2 $_;
#
#    # 增加声笔字的声偏字容错码，权重低于已有的声偏字
#    my ($char, $sep1, $code1, $sep2, $weight, $sep3, $code2, $extra) =
#        $_ =~ /^(\p{Han})(\s+)([a-z][^aeuio])(\s+)(\d+)(\s+)([a-z]+)(.*)$/;
#
#    next unless $code1 && $code2 && exists $sp_chars{$code1};
#
#    print $fh2 $sp_chars{$code1},
#        $sep1,
#        $code1,
#        $sep2,
#        $weight > 1 ? $weight - 1 : 0,
#        $sep3,
#        $code1,
#        $extra,
#        "\n";
#}
#close $fh;
#close $fh2;
