#!/usr/bin/env perl
# Typically run from broker.pl as:
#	agents/$agent.pl $sid "$query" 'username' 'password'
# sid -- search id
# query -- search query
# username -- MDS username
# password -- MDS password (what about passwords with quotes in them?)
use strict;
use LWP::UserAgent;
use Data::Dumper;
use Data::Serializer;
use Carp;
use WWW::SearchBroker::Common qw(DEBUG DEBUG_LOW DEBUG_MEDIUM DEBUG_HIGH TEMP_FILE_PATH print_line);
use List::Misc qw(first_value all_values);

if (scalar @ARGV != 2) {
	warn scalar @ARGV . " arguments presented, two required:";
	warn "Usage: $0 103 search_query\n";
	exit;
}
my ($sid,$query) = @ARGV;
umask(0067); # Initial file perms are 600, indicating not yet finished
my $filename = TEMP_FILE_PATH . "$sid.txt";
my $obj = Data::Serializer->new();

my $include_schedule = undef;
my $limit = 20;   # maximum number of items returned
my $count;

my $ua = LWP::UserAgent->new(env_proxy => 1);
use HTTP::Cookies;
use HTTP::Request::Common;
my $cookie_jar = HTTP::Cookies->new(autosave => 1, ignore_discard => 1);
$ua->cookie_jar($cookie_jar);
# pubsel=DHS is HeraldSun, Melb; =AUS is The Australian/Weekend Australian
# Does indexkey matter?
# If it does, should post to 'http://www.newstext.com.au/pages/fpw.asp' with
# args: 'pubsel=AUS&SrchText=portal&SortOrder=desc&SortField=Date&DateFrom=&DateTo=&ResultCount=20&ResultMaxDocs=20&datetype=1m?'
# then submit the following page with its hidden args
#my $response = $ua->request(GET 'http://www.newstext.com.au/pages/ssam.asp?source=newstext&SortOrder=desc&SortField=Date&Site=ALL&indexkey=376B19073465724951E210&summreqd=yes&ResultMaxDocs=20&ResultCount=20&pubsel=DHS&SrchText=monash+university&datetype=1m&DateFrom=&DateTo=');
my $response = $ua->request(GET 'http://www.newstext.com.au/pages/ssam.asp?source=newstext&SortOrder=desc&SortField=Date&Site=ALL&indexkey=1B242648912212984350&summreqd=yes&ResultMaxDocs=20&ResultCount=20&pubsel=AUS&SrchText=' . $query . '&datetype=1m&DateFrom=&DateTo=');
foreach my $val (split /<td class=lgbg width=500>/, $response->content) {
	my ($title,$link,$description,$relevance);
	if ($val =~ m#<a href="(.*?)" target="_self">\s*(.*?)\s*</a>#sm) {
		$link = $1;
		$title = $2;
	}
	if ($val =~ m#<font class=ResHdr>(.*)</font>.*<font class=ResLdr>(.*)</font>#sm) {
		$description = $1 . $2;
		$description =~ s/\s+/ /g;
	}
	next unless defined $link && defined $title && defined $description;
	carp "[AGENT: Found $title, $description, $link]" if DEBUG >= DEBUG_MEDIUM;

	my %result = (
		'title' => $title,
		'link' => $link,
		'description' => $description,
		'relevance' => 0, # should count stars...
	);
	print_line($filename,$obj->serialize({ $count++ => \%result}) . "\n");
} # foreach

#########################################################################
chmod(0644, $filename); # Group readable, indicating finished
carp "[AGENT: Completed successfully (saved to $filename)]\n" if DEBUG;
