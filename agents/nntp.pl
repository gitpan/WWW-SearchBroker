#!/usr/bin/env perl
# Typically run from broker.pl as:
#	agents/$agent.pl $sid "$query" 'username' 'password'
# sid -- search id
# query -- search query
# username -- MDS username
# password -- MDS password (what about passwords with quotes in them?)
use strict;
use News::NNTPClient;
use Data::Dumper;
use Data::Serializer;
use Carp;
use WWW::SearchBroker::Common qw(DEBUG DEBUG_LOW DEBUG_MEDIUM DEBUG_HIGH TEMP_FILE_PATH NEWS_SERVER print_line);

if (scalar @ARGV != 2 && scalar @ARGV != 4) {
	warn scalar @ARGV . " arguments presented, two or four required:";
	warn "Usage: $0 103 search_query [username password]\n";
	exit;
}
my ($sid, $what,$user,$pass) = @ARGV;
umask(0067); # Initial file perms are 600, indicating not yet finished
my $filename = TEMP_FILE_PATH . "$sid.txt";
my $c = new News::NNTPClient(NEWS_SERVER) || die "[AGENT: Couldn't connect: $!]";
my $obj = Data::Serializer->new();
if ($user && $user ne '') {
	$c->authinfo($user, $pass) || die "[AGENT: Couldn't auth: $!]";
}

my @fields = qw(numb subj from date mesg refr char line xref);
my (%reference_index, %unresponded_index, %subject_index, $count);
my $newsgroup = 'its.projects.flt.feedback';
my ($first,$last) = $c->group($newsgroup);
carp "[AGENT: Found $first..$last articles, only checking last 50]\n" if DEBUG >= DEBUG_MEDIUM;
$first = $last - 50; # Let's make this a touch quicker!
foreach my $a ($first..$last) {
	my $body = join('', $c->body($a));
	if ($c->code > 400) { # See doc for News::NNTPClient
		if ($c->code == '480') {
			carp "[AGENT: Discussion group requires authentication, giving up...]\n" if DEBUG >= DEBUG_LOW;
			last;
		}
		carp "[AGENT: Error " . $c->code . "(" . $c->message . "), skipping...]\n" if DEBUG >= DEBUG_LOW;
		next;
	}

	if ($body =~ /$what/s) {
		carp "[AGENT: Found $body]\n" if DEBUG >= DEBUG_HIGH;
	}
	$body =~ s/\n/<br>/g;
	if ($body =~ s/^(.{100}).*/$1/) {
		$body .= '...';
	}
	my %result = (
		'title' => $c->xhdr('Subject', $a),
		'link' => '/news/readnews.html?SERVER=' . NEWS_SERVER . '&NEWSGROUP=' . $newsgroup . '&NOPOST=0&ANUM=' . $a,
		'description' => $body,
		'relevance' => '',
	);
	print_line($filename,$obj->serialize({ $count++ => \%result}) . "\n");
	#print_line($filename,Dumper \%result);
}
$c->quit();
chmod(0644, $filename); # Group readable, indicating finished
carp "[AGENT: Completed successfully (saved to $filename)]\n" if DEBUG;
