#!/usr/bin/perl -w
###########################################################################
# WARNING: This executes commands directly as passed -- evil, evil, evil! #
# Should only be used for testing purposes by the actually user, not by   #
# others...                                                               #
###########################################################################
# Typically run from broker.pl as:
#	agents/$agent.pl $sid "$query"
# sid -- search id
# query -- search query
use strict;
use Data::Dumper;
use Data::Serializer;
use Carp;
use WWW::SearchBroker::Common qw(DEBUG DEBUG_HIGH TEMP_FILE_PATH);
use constant COMMAND => 'grep -Hs '; # the grep command to be run

if (scalar @ARGV < 2) {
	warn scalar @ARGV . " arguments presented, two required:";
	warn "Usage: $0 103 search_query\n";
	exit;
}

my ($sid, $what) = @ARGV;
umask(0067); # Initial file perms are 600, indicating not yet finished
my $filename = TEMP_FILE_PATH. "$sid.txt";
warn `pwd`;
carp '[AGENT: ' . COMMAND . "$what >> $filename]\n";
my $obj = Data::Serializer->new();
my $count = 0;
unless (open(QRY, COMMAND . qq{$what|})) {
	die "[AGENT: Couldn't perform $0 query for $what (sid = $sid)]";
}
my ($qn,$filespec) = $what =~ /(.*)\s+([^\s]*)/;
while(<QRY>) {
	my ($file,$desc) = split(/:/, $_, 2);
	my %result = (
		'title' => $file,
		'link' => 'file://' . $file,
		'description' => $desc,
		'relevance' => scalar(split(/\Q$qn/, $desc)),
	);
	print_line($obj->serialize({ $count++ => \%result }) . "\n");
	#print_line(Dumper \%result);
}
close(QRY);
if ($count < 1) {
	my %result = (
		'title' => 'No results found',
		'link' => '',
		'description' => '',
		'relevance' => 0,
	);
	print_line($obj->serialize({ 0 => \%result }) . "\n");
}
sleep(5);			# Simulate slower agents
chmod(0644, $filename);		# Group readable, indicating finished
carp "[AGENT: Completed successfully (saved to $filename)]\n";

sub failed {
	print_line("FAILED!\n");
}

sub print_line {
	my $line = shift;
	if (open(SID_FILE,">>$filename")) {
		print SID_FILE $line;
		close(SID_FILE);
	} else {
		die "[AGENT: Couldn't append to $filename ($!)]";
	}
}
