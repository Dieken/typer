#!/usr/bin/env perl
#
# 根据字根表、拆分表、单字码表生成内嵌这些信息的 JavaScript 代码，以方便在静态网页上实现拆分查询。
#
# Usage: ./turn-roots-chaifen-mabiao-into-js.pl [roots.tsv [chaifen.tsv [mabiao.tsv]]] > some.js
#
# 这个脚本是通用的，除了假设了取码规则是 ABCZ 四根。

use v5.36;                              # or later to get "unicode_strings" feature, plus strict and warnings
use utf8;                               # so literals and identifiers can be in UTF-8
use warnings qw(FATAL utf8);            # fatalize encoding glitches
use open     qw(:std :encoding(UTF-8)); # undeclared streams in UTF-8
use Encode   qw(decode);
@ARGV = map { decode('UTF-8', $_, Encode::FB_CROAK) } @ARGV;

use autodie;
use Getopt::Long;
use JSON::PP;

my $indent_json = 0;
GetOptions(
    "indent-json!"      => \$indent_json,
);

my $roots_file = $ARGV[0] || "roots.tsv";
my $chaifen_file = $ARGV[1] || "chaifen.tsv";
my $mabiao_file = $ARGV[2] || "mabiao.tsv";

my $roots = read_tsv($roots_file);
my $chaifen = read_tsv($chaifen_file);
my $mabiao = read_tsv($mabiao_file);

while (my ($k, $v) = each %$roots) {
    die "ERROR: multiple codes \"@$v\" found for root \"$k\"\n" if @$v > 1;
    $roots->{$k} = $v->[0];
}

my %roots_freq;
while (my ($k, $v) = each %$chaifen) {
    unless (exists $mabiao->{$k}) {
        delete $chaifen->{$k};
        next;
    }

    for (my $i = 0; $i < @$v; ++$i) {
        my @a = $v->[$i] =~ /{[^}]+}|\S/g;
        $v->[$i] = \@a;
        for (max4(@a)) {
            $roots_freq{$_}++;
        }
    }
}

my %roots_num;
for my $k (sort { ($roots_freq{$b} <=> $roots_freq{$a}) || ($a cmp $b) } keys %roots_freq) {
    $roots_num{$k} = scalar keys %roots_num;
}

my @chars_index;
for my $k (sort { ord($a) <=> ord($b)  } keys %$chaifen) {
    my $v = $chaifen->{$k};

    my $i = ord($k);
    if (@chars_index == 0) {
        push @chars_index, $i, [ encode_mabiao_and_chaifen($mabiao->{$k}, $v) ];
    } else {
        my $index = $chars_index[-2];
        if ($i - $index >= 1000) {
            push @chars_index, $i, [ encode_mabiao_and_chaifen($mabiao->{$k}, $v) ];
        } else {
            $chars_index[-1][$i - $index] = encode_mabiao_and_chaifen($mabiao->{$k}, $v);
        }
    }
}

my @roots_index;
while (my ($k, $v) = each %roots_num) {
    $roots_index[$v * 2] = $k;
    $roots_index[$v * 2 + 1] = ucfirst(lc($roots->{$k}));
}

my $json = JSON::PP->new->utf8(0)->pretty($indent_json)->canonical;
my $s = $json->encode(\@roots_index);
chomp $s;
print "var roots = ", $s, ";\n\n";

$s = $json->encode(\@chars_index);
chomp $s;
$s =~ s/\bnull,/,/g unless $indent_json;
print "var chars = ", $s, ";\n\n";

print << 'EOF';
function charinfo(s) {
  let r = [];

  for (let c of s) {
    let i = 0;
    let j = c.codePointAt(0);

    while (i < chars.length) {
      if (j >= chars[i] && j < chars[i] + chars[i + 1].length) {
        j -= chars[i];

        let a = { char: c, info: null };
        let b = chars[i + 1][j];

        if (! b) {
          r.push(a);
          break;
        }

        let info = { codes: Array.isArray(b[0]) ? b[0] : [ b[0] ], chaifens: [] };
        a.info = info;

        if (Array.isArray(b[1])) {
          for (let k = 1; k < b.length; ++k) {
            let chaifen = [];

            for (let l = 0; l < b[k].length; ++l) {
              chaifen.push({ root: roots[2 * b[k][l]], code: roots[2 * b[k][l] + 1] });
            }

            info.chaifens.push(chaifen);
          }
        } else {
          let chaifen = [];

          for (let k = 1; k < b.length; ++k) {
            chaifen.push({ root: roots[2 * b[k]], code: roots[2 * b[k] + 1] });
          }

          info.chaifens.push(chaifen);
        }

        r.push(a);
        break;
      }

      i += 2;
    }

    if (i >= chars.length) r.push([c, null]);
  }

  return r;
}
EOF


#######################################################################
sub read_tsv($file) {
    my %h;

    open my $fh, "<", $file;
    while (<$fh>) {
        chomp;
        my @a = split;
        $h{$a[0]}{$a[1]} = 1 if @a >= 2 && substr($a[0], 0, 1) ne "#";
    }
    close $fh;

    while (my ($k, $v) = each %h) {
        $h{$k} = [ sort keys %$v ];
    }

    return \%h;
}

sub max4(@a) {
    return @a <= 4 ? @a : @a[0..2, -1];
}

sub encode_mabiao_and_chaifen($codes, $chaifens) {
    my @a;

    if (@$codes == 1) {
        # avoid extra "[ ... ]", reduce file size
        push @a, $codes->[0];
    } else {
        push @a, $codes;
    }

    if (@$chaifens == 1) {
        # avoid extra "[ ... ]", reduce file size
        push @a, map { $roots_num{$_} } max4(@{ $chaifens->[0] });
    } else {
        for (@$chaifens) {
            push @a, [ map { $roots_num{$_} } max4(@$_) ];
        }
    }

    return \@a;
}
