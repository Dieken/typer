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

my $roots_file = $ARGV[0] || "roots.tsv";
my $chaifen_file = $ARGV[1] || "chaifen.tsv";
my $mabiao_file = $ARGV[2] || "mabiao.tsv";


my $roots = read_tsv($roots_file);
my $chaifen = read_tsv($chaifen_file);
my $mabiao = read_tsv($mabiao_file);

my %roots_freq;
while (my ($k, $v) = each %$chaifen) {
    delete $chaifen->{$k} if !exists $mabiao->{$k};

    my @a = $v =~ /{[^}]+}|\S/g;
    $chaifen->{$k} = \@a;
    for (max4(@a)) {
        $roots_freq{$_}++;
    }
}

my %roots_num;
for my $k (sort { $roots_freq{$b} <=> $roots_freq{$a} } keys %roots_freq) {
    $roots_num{$k} = scalar keys %roots_num;
}

my @chars_index;
for my $k (sort { ord($a) <=> ord($b)  } keys %$chaifen) {
    my $v = $chaifen->{$k};

    my $i = ord($k);
    if (@chars_index == 0) {
        push @chars_index, $i, [ [$mabiao->{$k}, map { $roots_num{$_} } max4(@$v)] ];
    } else {
        my $index = $chars_index[-2];
        if ($i - $index >= 1000) {
            push @chars_index, $i, [ [$mabiao->{$k}, map { $roots_num{$_} } max4(@$v)] ];
        } else {
            $chars_index[-1][$i - $index] = [$mabiao->{$k}, map { $roots_num{$_} } max4(@$v)];
        }
    }
}

my @roots_index;
while (my ($k, $v) = each %roots_num) {
    $roots_index[$v * 2] = $k;
    $roots_index[$v * 2 + 1] = ucfirst(lc($roots->{$k}));
}

print "var roots=[", join(",", map { "\"$_\"" }@roots_index), "];\n";
print "var chars=[";
for (my $i = 0; $i < @chars_index; $i += 2) {
    print $chars_index[$i],
        ",[",
        join(",",
            map { $_ ? "[\"$_->[0]\"," . join(",", @{$_}[1 .. @$_ - 1]) . "]" : "" } @{ $chars_index[$i + 1] }
        ),
        "],";
}
print "];\n";
print << 'EOF';
function charinfo(s) {
  let r = [];
  for (let c of s) {
    let i = 0;
    let j = c.codePointAt(0);
    while (i < chars.length) {
      if (j >= chars[i] && j < chars[i] + chars[i + 1].length) {
        j -= chars[i];
        let a = [c];
        let b = chars[i + 1][j];
        a.push(b[0]);
        for (let k = 1; k < b.length; ++k) {
          a.push(roots[2 * b[k]], roots[2 * b[k] + 1]);
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
        $h{$a[0]} = $a[1] if $a[1];
    }
    close $fh;

    return \%h;
}

sub max4(@a) {
    return @a <= 4 ? @a : @a[0..2, -1];
}
