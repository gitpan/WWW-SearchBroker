#!/usr/local/bin/perl -w
# Typically run from broker.pl as:
#	agents/$agent.pl $sid "$query"
# sid -- search id
# query -- search query
use strict;
use LWP::UserAgent;
use HTML::TreeBuilder;
use Data::Dumper;
use Data::Serializer;
use Carp;
use WWW::SearchBroker::Common qw(DEBUG DEBUG_HIGH TEMP_FILE_PATH STAFF_MAIL_SERVER STUDENT_MAIL_SERVER);

if (scalar @ARGV < 2) {
	warn scalar @ARGV . " arguments presented, two required:";
	warn "Usage: $0 103 search_query\n";
	exit;
}
my ($sid, $what,$user,$pass) = @ARGV;
umask(0067); # Initial file perms are 600, indicating not yet finished
my $filename = TEMP_FILE_PATH . "$sid.txt";
my $search_url = 'http://ultraseek.its.monash.edu.au/query.html?qt=' . $what;
my $useragent = LWP::UserAgent->new();
my $request   = HTTP::Request->new(
	'GET',
	$search_url,
);
my $response  = $useragent->request($request);
my $obj = Data::Serializer->new();

my $tree = HTML::TreeBuilder->new();

$tree->parse($response->content());
$tree->eof();

my @tables = $tree->find_by_tag_name('table');
my $num_results = 0;
my $count = 0;

foreach my $table (@tables) {
	if ($table->as_text() =~ /(\d+).*?results.*?found/) {
		$num_results = $1;
	}
	
	if ($table->as_text() =~ /Similar$/ && $table->as_text() !~ /^\d+%/) {
		my $title_node = $table->look_down(_tag => 'b');
		my $url_tag    = $title_node->look_down(_tag => 'a');
		my ($desc,$relevance) = $table->as_HTML() =~ /<br>(.*?)<br>.*?(\d+%)<\/td>/;
		my %result = (
			'title' => $title_node->as_text(),
			'link' => $url_tag->attr('href'),
			'description' => $desc,
			'relevance' => $relevance,
		);
		print_line($obj->serialize({ $count++ => \%result}) . "\n");
	}
}
chmod(0644, $filename); # Group readable, indicating finished
carp "[AGENT: Completed successfully (saved to $filename)]\n" if DEBUG;

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
