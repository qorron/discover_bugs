#!/usr/bin/perl

# what it does:
# it scans your music and divides the top level directories on a number of sd-cards, so that no card holds more than 9000 files.
# it does no knappsack optimization so that alphabetical order is maintained.
# e.g. a.. to m.. is on card one and n.. to z.. is on card two.
# usage:
# ./divide.pl # does a dry run to see what would have happend.
# ./divide.pl go # or any other true value, actually does all the stuff.

use strict;
use warnings;
use 5.020;
use Data::Dumper;
use File::Path qw(remove_tree);
use File::Slurp qw(slurp);
use File::Spec;
use IPC::Run qw(run);

# you might want to change these

# where your music is
my $mp3_source = '/data/mp3';

# your sd cards and usb sticks need a volume name like "mp3_1", "mp3_2",...
my $destination_prefix = "/media/$ENV{USER}/mp3_";

# filter file, something like:
# + */
# + *.[oO][gG][gG]
# + *.[jJ][pP][gG]
# + *.[wW][mM][aA]
# + *.[mM][pP][3]
# + *.[fF][lL][aA][cC]
# - *
my $filter_file = "$mp3_source/filter";

# only used for development on slow filesystems.
my $index_file = '~/tmp/mp3_index';

my %counter;
my $all;

my $do_it = $ARGV[0];


#my $list = slurp($index_file); # used during development
my $list = `cd '$mp3_source' && find`;
for my $line (split "\n", $list) {
	
	my @names = File::Spec->splitdir($line);
	shift @names;
	next unless @names;
	next unless $line =~ /\.(?:mp3|ogg|flac|wma|wav)$/i; # that is for file counting only, use filter file for filtering out stuff with rsync
	next if $names[0] =~ /^!/; # skip some stuff
	next if $names[0] =~ /^audio books/i;
	# say join ' # ', @names;
	$all++;
	$counter{$names[0]}++
}

say $all;
my @cards = ( [], [], [] );
my %cards;
my $card = 0;
my $sum = 0;
for my $dir ( sort { lc($a) cmp lc($b) } keys %counter ) {
	if ($sum + $counter{$dir} > 9000) {
		$cards{$card} = $sum;
		$card++;
		$sum = 0;
	}
	push @{$cards[$card]}, $dir;
	$sum += $counter{$dir};
}
$cards{$card} = $sum unless exists $cards{$card};
warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\@cards], ['cards']);
warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\%cards], ['cards']);

my @default_args = qw(--prune-empty-dirs --update --delete --delete-before --delete-excluded --progress --recursive --verbose);
push @default_args, "--filter", "merge $filter_file" if -e $filter_file;
push @default_args, '--dry-run' unless $do_it;

my $card_i = 0;
for my $card (@cards) {
	$card_i++;
	my $dest_card = "$destination_prefix$card_i";
	next unless -e $dest_card;
	for my $dir (@$card) {
		my @cmd = ('rsync', @default_args, "$mp3_source/$dir", "$dest_card/");
		my $out;
		say join ' ', @cmd;
		run \@cmd, '', $out;
		say $out // '';
	}
	# delete any directories that have been moved to another card.
	for my $dir (keys %counter) {
		next if grep {$dir eq $_ } @$card;
		my $sd_dir = "$dest_card/$dir";
		next unless -e $sd_dir;
		say "delete $sd_dir";
		remove_tree $sd_dir if $do_it;
	}
}

