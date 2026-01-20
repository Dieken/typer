#!/usr/bin/env perl

use v5.36;                              # or later to get "unicode_strings" feature, plus strict and warnings
use utf8;                               # so literals and identifiers can be in UTF-8
use warnings qw(FATAL utf8);            # fatalize encoding glitches
use open     qw(:std :encoding(UTF-8)); # undeclared streams in UTF-8
use Encode   qw(decode);
@ARGV = map { decode('UTF-8', $_, Encode::FB_CROAK) } @ARGV;

use Getopt::Long;
use autodie;


my $roots_file = 'roots.tsv';
my $rhymes_file = 'ling-rhymes.txt';
my $title = '灵明输入法字根口诀';

GetOptions(
    'roots=s'  => \$roots_file,
    'rhymes=s' => \$rhymes_file,
    'title=s'  => \$title,
) or die "Error in command line arguments\n";

my %roots;
{
    open my $fh, '<', $roots_file;
    while (<$fh>) {
        chomp;
        my @a = split /\t/;
        $roots{$a[0]} = \@a;
    }
    close $fh;
}

my %rhymes;
{
    open my $fh, '<', $rhymes_file;
    while (<$fh>) {
        chomp;
        my @a = split /\s+/, $_;
        $rhymes{$a[0]} = \@a;
    }
    close $fh;
}

print_html_header();
print_root_chart();
print_root_list();
print_html_footer();

#########################################################################
sub htmlize_dama($dama) {
    return "<td class='dama'>$dama</td>\n";
}

sub htmlize_rhyme($rhyme_ref) {
    my $html = "<td>\n";
    my @a = @$rhyme_ref;

    for my $rhyme (@a[1..$#a]) {
        $html .= "<span class='rhyme'>";
        for my $char (split //, $rhyme) {
            if (exists $roots{$char}) {
                my $info = $roots{$char};
                my $code = $info->[1];
                my $dama = uc(substr($code, 0, 1));
                die "Inconsistent dama($a[0]) for root $char($code) in rhyme '$rhyme'\n" if $dama ne $a[0];
                my $comment = $info->[2] // '<no comment>';
                my $class;
                if ($comment =~ /不取/ || $char eq '儿') {  # '儿' 省略了零声母的特殊辅音 J
                    $class = "class='no-sheng-mu-root'";
                } elsif ($comment =~ /無讀音/) {
                    $class = "class='no-sound-root'";
                } elsif ($comment =~ /歸併|no comment/ || ($comment =~ /(.)本字/ && exists $roots{$1} && $roots{$1}->[1] eq $code)) {
                    $class = "class='unified-root'";
                } elsif (length($code) == 2) {
                    $class = "class='two-letter-root'";
                } else {
                    $class = "";
                }
                $html .= "<ruby $class title='$comment'>$char<rp>(</rp><rt>$code</rt><rp>)</rp></ruby>";
            } else {
                if ($char eq '(') {
                    $html .= "<span class='cluster'>";
                } elsif ($char eq ')') {
                    $html .= "</span>";
                } else {
                    die "Unknown character '$char' in rhyme '$rhyme'\n";
                }
            }
        }
        $html .= "</span>\n";
    }
    $html .= "</td>\n";

    return $html;
}

sub print_html_header() {
    print << "HTML_HEADER";
<!DOCTYPE html>
<html lang="zh">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$title</title>
    <style>
        \@font-face {
            font-family: 'Yuniversus';
            src: url('https://shurufa.app/Yuniversus.woff') format('woff');
        }
        body {
            font-family: 'Yuniversus', serif;
            font-size: larger;
        }
        table {
            margin: 20px auto;
        }
        table, th, td {
            border: 1px solid #ddd;
            border-collapse: collapse;
            padding: 10px;
        }
        th { background-color: #f2f2f2; }
        #root_chart td {
            max-width: 11rem;
            min-width: 2rem;
            vertical-align: top;
            line-height: 2.0;
        }
        caption { margin-bottom: 10px; }
        rt { font-family: monospace; }
        .dama { text-align: center; }
        .rhyme { margin-right: 1rem; }
        .no-sheng-mu-root { color: red; }
        .no-sound-root { color: gray; }
        .unified-root { background-color: yellow; }
        .two-letter-root { color: blue; }
        .cluster { padding-bottom: 3px; border-bottom: 2px dotted gray; }
    </style>
</head>
<body>
<p>注意：从<a href="https://shurufa.app">宇浩输入法官网</a>加载 Yuniversus 字体可能较慢，请稍候！</p>
HTML_HEADER
}

sub print_html_footer() {
    print << "HTML_FOOTER";
<p>
样式说明：
<ol>
<li><span class='no-sheng-mu-root'>红色</span>：不取声母字根</li>
<li><span class='no-sound-root'>灰色</span>：无读音字根</li>
<li><span class='unified-root'>黄色背景</span>：归并字根</li>
<li><span class='two-letter-root'>蓝色</span>：其它双编字根</li>
<li><span class='cluster'>下划线</span>：按字根拼音朗读口诀时省略的字根</li>
</ol>
</p>
</body>
</html>
HTML_FOOTER
}

sub print_root_list() {
    print << "END";
<div id="root_list">
<table>
    <caption>$title</caption>
    <thead>
    <tr>
        <th>大码</th>
        <th>口诀</th>
    </tr>
    </thead>
    <tbody>
END

    for my $dama (sort keys %rhymes) {
        my $rhyme_ref = $rhymes{$dama};
        print "    <tr>\n";
        print "        ", htmlize_dama($dama);
        print "        ", htmlize_rhyme($rhyme_ref);
        print "    </tr>\n";
    }

    print << "END";
</tbody>
</table>
</div>
END
}

sub print_root_chart() {
    my @keyboards = (
        "QWERTYUIOP",
        "ASDFGHJKL",
        "ZXCVBNM"
    );

    for my $row (@keyboards) {
        print << "END";
<div id="root_chart">
<table>
    <thead>
    <tr>
END

        for my $key (split //, $row) {
            my $html = htmlize_dama($key);
            $html =~ s/<td/<th/g;
            print "        $html";
        }

        print << "END";
    </tr>
    </thead>
    <tbody>
    <tr>
END
        for my $key (split //, $row) {
            print "        ", exists $rhymes{$key} ? htmlize_rhyme($rhymes{$key}) : "<td></td>\n";
        }

        print << "END";
    </tr>
    </tbody>
</table>
</div>
END
    }
}
