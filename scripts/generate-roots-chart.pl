#!/usr/bin/env perl
#
# 根据字根表、拆分表、字频表生成 HTML 格式的字根图
#
# Usage: ./generate-roots-chart.pl [OPTIONS] [roots.tsv [chaifen.tsv [top6000.txt]]] > charts.html
#
# 这个脚本是通用的，除了假设了取码规则是 ABCZ 四根。

use v5.36;                              # or later to get "unicode_strings" feature, plus strict and warnings
use utf8;                               # so literals and identifiers can be in UTF-8
use warnings qw(FATAL utf8);            # fatalize encoding glitches
use open     qw(:std :encoding(UTF-8)); # undeclared streams in UTF-8
use Encode   qw(decode);
@ARGV = map { decode('UTF-8', $_, Encode::FB_CROAK) } @ARGV;

use autodie;
use File::Spec;
use Getopt::Long;
use JSON::PP;
use List::Util qw/max uniqstr/;
use Unicode::UCD qw/charblock/;

my $page_size = $ENV{PAGE_SIZE} || 500;
my $max_examples= $ENV{MAX_EXAMPLES} || 10;
my $unihan_dir = $ENV{UNIHAN_DIR} || ".";
my $indent_json = 0;
my $only_json = 0;
my $title = "字根图";

GetOptions(
    "max-examples=i"    => \$max_examples,
    "page-size=i"       => \$page_size,
    "unihan-dir=s"      => \$unihan_dir,
    "indent-json!"      => \$indent_json,
    "only-json!"        => \$only_json,
    "title=s"           => \$title,
);

my $uh = load_unihan($unihan_dir);

my $roots_file = $ARGV[0] || "roots.tsv";
my $chaifen_file = $ARGV[1] || "chaifen.tsv";
my $topchars_file = $ARGV[2] || "top6000.txt";

my $roots = read_tsv($roots_file);
my $chaifen = read_tsv($chaifen_file);
my $topchars = read_tsv($topchars_file);

my $max_pages = int((keys(%$topchars) - 1) / $page_size) + 1;

my %roots_freq;
my %roots_is_traditional;
my %roots_examples;
my %pua_cache;
my %root_to_chars;
my $n = keys(%$topchars) + 1;
for my $k (sort {
                my $v1 = exists $topchars->{$a} ? $topchars->{$a}[0] : max(ord($a), $n);
                my $v2 = exists $topchars->{$b} ? $topchars->{$b}[0] : max(ord($b), $n);
                $pua_cache{$a} //= charblock(ord($a)) eq "Private Use Area";
                $pua_cache{$b} //= charblock(ord($b)) eq "Private Use Area";
                $v1 = 0x10FFFF if $pua_cache{$a};
                $v2 = 0x10FFFF if $pua_cache{$b};
                $v1 <=> $v2
           } keys %$chaifen) {
    my $v = $chaifen->{$k};

    for (@$v[2 .. @$v - 1]) {
        my @a = $_ =~ /{[^}]+}|\S/g;

        my $seq = exists $topchars->{$k} ? $topchars->{$k}[0] : 0;
        my $page = $seq == 0 ? 0 : int(($seq - 1) / $page_size) + 1;   # page 0 means not in top 6000
        my $is_traditional = $uh->{ord($k)}{kSimplifiedVariant};
        my $is_simplified = $uh->{ord($k)}->{kTraditionalVariant};

        for (uniqstr sort max4(@a)) {
            next if exists $root_to_chars{$_}{$k};

            $roots_freq{$_}[$page]++;
            $root_to_chars{$_}{$k} = 1;

            if ($is_traditional) {
                $roots_is_traditional{$_} = 1 unless exists $roots_is_traditional{$_};
            }
            if ($is_simplified) {
                $roots_is_traditional{$_} = 0;
            }

            if (!exists $roots_examples{$_} || @{ $roots_examples{$_} } < $max_examples) {
                push @{ $roots_examples{$_} }, $k;
            }
        }
    }
}

my %chart;
while (my ($k, $v) = each %$roots) {
    my @a = @$v;
    my ($code, $pinyin, $comment) = ($a[2], $a[3], join(" ", @a[4..$#a]));
    $pinyin = ($uh->{ord($k)}{kMandarin} // "") if $k !~ /{/ && (!$pinyin || $pinyin !~ /[^a-z]/);
    $pinyin //= "";

    my @freq = @{ $roots_freq{$k} };
    $freq[1] //= 0;
    for (my $i = 2; $i <= $max_pages; ++$i) {
        $freq[$i] = ($freq[$i] // 0) + $freq[$i - 1];
    }
    $freq[0] += $freq[-1];

    $chart{uc(substr($code, 0, 1))}{ucfirst(lc($code))}{$k} = {
        pinyin => $pinyin,
        comment => $comment,
        freq => \@freq,
        traditional => $roots_is_traditional{$k} ? 1 : 0,
        examples => $roots_examples{$k},
    };
}

my $chart_json = JSON::PP->new->utf8(0)->pretty($indent_json)->canonical->encode(\%chart);
chomp $chart_json;
if ($only_json) {
    say $chart_json;
} else {
    my $script = "var page_size = $page_size;\n" .
        "var max_pages = $max_pages;\n" .
        "var chart_json = $chart_json;\n";
    printf template(), $script;
}


#######################################################################
sub read_tsv($file) {
    my %h;

    open my $fh, "<", $file;
    while (<$fh>) {
        chomp;
        my @a = split;
        next unless @a;

        if (exists $h{$a[0]}) {
            push @{ $h{$a[0]} }, @a[1..$#a];
        } else {
            $h{$a[0]} = [$., @a];
        }
    }
    close $fh;

    return \%h;
}

sub max4(@a) {
    return @a <= 4 ? @a : @a[0..2, -1];
}

sub load_unihan($dir) {
    my $unihan_variants = File::Spec->catfile($dir, "Unihan_Variants.txt");
    my $unihan_readings = File::Spec->catfile($dir, "Unihan_Readings.txt");
    my %h;

    open my $fh, "<", $unihan_variants;
    while (<$fh>) {
        next unless /^U\+/;

        my @a = split;
        next unless $a[1] eq "kSimplifiedVariant" || $a[1] eq "kTraditionalVariant";
        $h{hex(substr($a[0], 2))}{$a[1]} = $a[2];
    }
    close $fh;
    undef $fh;

    open $fh, "<", $unihan_readings;
    while (<$fh>) {
        next unless /^U\+/;

        my @a = split;
        next unless $a[1] eq "kMandarin";
        $h{hex(substr($a[0], 2))}{$a[1]} = $a[2];
    }
    close $fh;

    return \%h;
}

sub template() {
    return <<"END";
<!DOCTYPE html>
<html lang="zh" dir="ltr">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
  <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>$title</title>
  <style type="text/css">
  body {
    //font-family: "MiSans", "MiSans L3", "Plangothic P1", "Plangothic P2", "Monu Hani", "Monu Han2", "Monu Han3", "sans-serif";
    font-family: "TH-Tshyn-P0", "TH-Tshyn-P1", "TH-Tshyn-P2", "KaiXinSongA", "KaiXinSongB", "SimSun", "SimSun-ExtB", "SimSun-ExtG",
                 "SuperHan0ivd", "SuperHan2ivd", "SuperHan3ivd", "serif";
  }

  table {
    font-size: x-large;
    margin: 0 auto;
    overflow-x: auto;
  }

  table, th, td {
    border: 1px solid black;
    border-collapse: collapse;
    padding: 10px;
  }

  .traditional {
    background-color: lightgrey;
  }

  .freq {
    text-align: right;
  }

  .seq,.letter, .code, .root {
    text-align: center;
  }
  </style>
</head>
<body>
<noscript>
Your browser does not support JavaScript or JavaScript has been disabled.
Please enable JavaScript to experience the full functionality of our site.
</noscript>
<div>
  <label for="freq">字集： </label><span id="s_freq"></span>
</div>
<div id="keyboard"></div>
<div id="listing"></div>
<script type="text/javascript">
//<![CDATA[
"use strict";

%s

var page = 0;

function createFreqSelectBox() {
    let select = "<select id='freq' onchange='onChangeFreq(this.value)'>";
    select += `<option value="0">全部</option>`;
    for (let i = 1; i <= max_pages; ++i) {
        select += `<option value="\${i}">前 \${i * page_size} 字</option>`;
    }
    select += "</select>";
    return select;
}

function onChangeFreq(p) {
    page = parseInt(p);
    document.getElementById("listing").innerHTML = createTable();
}

function createTable() {
  let table = `
  <table>
  <caption>字根表</caption>
  <thead>
    <tr><th>序号</th><th>键名</th><th>编码</th><th>字根</th><th>字频</th><th>例字</th><th>备注</th></tr>
  </thead>
  <tbody>`;

  let i = 0;
  let letters = Object.keys(chart_json).sort();

  for (let l of letters) {
    let codes = Object.keys(chart_json[l]).sort();
    let letter_rowspan = 0;
    for (let c of codes) {
        letter_rowspan += Object.keys(chart_json[l][c]).filter(r => chart_json[l][c][r].freq[page] > 0).length;
    }
    let td_l = `<td rowspan="\${letter_rowspan}" class="letter">\${l}</td>`;

    for (let c of codes) {
      let roots = Object.keys(chart_json[l][c]).filter(r => chart_json[l][c][r].freq[page] > 0).sort(
                   (a, b) => chart_json[l][c][b].freq[page] - chart_json[l][c][a].freq[page]);

      let code_rowspan = roots.length;
      let td_c = `<td rowspan="\${code_rowspan}" class="code">\${c}</td>`;

      for (let r of roots) {
        ++i;

        let d = chart_json[l][c][r];
        let clz = d.traditional ? "traditional" : "simplified";

        table += `
    <tr>
      <td class="seq \${clz}">\${i}</td>
      \${td_l}
      \${td_c}
      <td class="root \${clz}"><ruby>\${r}<rp>(</rp><rt>\${d.pinyin}</rt><rp>)</rp></ruby></td>
      <td class="freq \${clz}">\${d.freq[page]}</td>
      <td class="examples \${clz}">\${d.examples.join("")}</td>
      <td class="comment \${clz}">\${d.comment}</td>
    </tr>`;

        td_l = "";
        td_c = "";
      }
    }
  }

  table += `
  </tbody>
  </table>`;

  return table;
}

window.onload = function() {
  document.getElementById("s_freq").innerHTML = createFreqSelectBox();
  onChangeFreq(0);
}
//]]>
</script>
</body>
</html>
END
}
