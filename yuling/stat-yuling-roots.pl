#!/usr/bin/env perl

# https://perldoc.perl.org/perluniintro#Perl's-Unicode-Support  v5.28
# https://perldoc.perl.org/feature#The-'signatures'-feature     v5.36
# https://perldoc.perl.org/perlunicook#℞-0:-Standard-preamble   v5.36

use v5.36;                              # or later to get "unicode_strings" feature, plus strict and warnings
use utf8;                               # so literals and identifiers can be in UTF-8
use warnings qw(FATAL utf8);            # fatalize encoding glitches
use open     qw(:std :encoding(UTF-8)); # undeclared streams in UTF-8
use Encode   qw(decode);
@ARGV = map { decode('UTF-8', $_, Encode::FB_CROAK) } @ARGV;

use Getopt::Long;
use autodie;

my $zigen_file = "zigen-ling.csv";
my $chaifen_file = "chaifen.csv";
my $freq_file = "../简体字频表-2.5b.txt";

GetOptions(
	"zigen=s", \$zigen_file,
	"chaifen=s", \$chaifen_file,
	"freq=s", \$freq_file) or die "Error in options\n";

my $roots = read_csv($zigen_file, 1);
my $chaifen = read_csv($chaifen_file, 1);
my $freqs = read_csv($freq_file);

{
	my $num_roots = 0;
	my $num_roots2 = 0;
	my $num_roots3 = 0;
	my $num_nosound = 0;
	my %codes;
	my %comments;

	while (my ($k, $v) = each %$roots) {
		$codes{$v->[1]} = 1;

		if ($v->[2] && $v->[2] =~ /(🈤\S+)/) {
			$comments{$1}++;
		}

		$num_roots++;
		if (length($v->[1]) == 2) {
			$num_roots2++;
			$num_nosound++ if $v->[1] =~ /o$/;
		} else {
			$num_roots3++;
		}
	}

	printf "%6d : %s\n",  $num_roots,   	  "总字根数";
	printf "%6d : %s\n",  scalar keys %codes, "归并字根组数";
	printf "%6d : %s\n",  $num_roots2,  	  "两码字根数";
	printf "%6d : %s\n",  $num_roots3,  	  "三码字根数";
	printf "%6d : %s\n",  $num_nosound,       "无音字根数";

	for (sort keys %comments) {
		printf "%6d : %s\n", $comments{$_}, $_;
	}

	print "\n";
}

{
	my $skips = 0;
	my $noskips = 0;
	my $skip_freqs = 0.0;
	my $noskip_freqs = 0.0;

	while (my ($k, $v) = each %$chaifen) {
		next if length($v->[1]) < 4;
		next if $k !~ /^\p{Han}$/;

		my $r1 = substr($v->[1], 0, 1);
		my $n = length($roots->{$r1}[1]);

		if ($n == 2) {
			$noskips++;
			$noskip_freqs += $freqs->{$k}[1] if exists $freqs->{$k};
		} else {
			$skips++;
			$skip_freqs += $freqs->{$k}[1] if exists $freqs->{$k};
		}
	}

	printf "%2.2f%% : %s\n", 100.0 * $skip_freqs/($skip_freqs + $noskip_freqs), "四根字跳根字频比例";
	printf "%2.2f%% : %s\n", 100.0 * $noskip_freqs/($skip_freqs + $noskip_freqs), "四根字不跳根字频比例";
	print "\n";
	printf "%2.2f%% : %s\n", 100.0 * $skips/($skips + $noskips), "四根字跳根字数比例";
	printf "%2.2f%% : %s\n", 100.0 * $noskips/($skips + $noskips), "四根字不跳根字数比例";
}


######################################################################
sub read_csv($file, $skip_header = 0) {
	my %h;

	open my $fh, "<", $file;
	while (<$fh>) {
		next if $. == 1 && $skip_header;

		chomp;
		my @a = split /[,\t]/;
		next unless @a >= 2;

		$h{$a[0]} = \@a;
	}
	close $fh;

	return \%h;
}
