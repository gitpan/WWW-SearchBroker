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
my $response = $ua->request(GET 'http://newsstore.f2.com.au/apps/newsSearch.ac?ac=search&rs=1&st=dc&ss=AGE&sy=age&sf=all&dt=selectRange&dr=1year&so=relevance&sp=0&rc=10&pb=all_ffx&kw=' . $query);
foreach my $val (split /<p style="margin-top:0px">/, $response->content) {
	my ($title,$link,$description,$relevance);
	if ($val =~ m#<a href="(.*)">(.*)</a>#) {
		$link = $1;
		$title = $2;
	}
	if ($val =~ m#<rl:valueExists value=".*">(.*)<br></rl:valueExists>#) {
		$description = $1;
	}
	next unless defined $link && defined $title && defined $description;
	carp "[AGENT: Found $title: $description ($link)]\n" if DEBUG >= DEBUG_MEDIUM;

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
