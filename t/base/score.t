print "1..101\n";

use WWW::SearchBroker::Aggregator_Scorer qw(score);

print "ok 1\n";

my @search_terms = ('foo', 'bar', 'foo bar', 'foo bar fnord');
my @search_words = ('foodumentally', 'barupulous', '5/15/2002', 'foonatomy', 'barokaly!', 'fnordmaker', '5/15/2003');
my @search_urls = ('http://foo.com/fnord/', 'http://bar.com/?foo=bar', 'http://fnord.org/foo/bar.html');

foreach my $i (1..100) {
	my $query = build_phrase(@search_terms);
	my $result = build_phrase(@search_words);
	my $search_url = $search_urls[int(rand(scalar @search_urls))];
	my $access = int(rand(3));
	print "[SCORE_TEST: Scoring $query in $result at $search_url with access = $access]\n";
	my %result = (
		'title' => $result,
		'link' => $search_url,
		'description' => $result,
		'relevance' => 0,
	);

	my $score = score($query,\%result,$access);
	print "\n[SCORE_TEST: <<<Score = $score>>>]\n";

	print "not " if !defined $score;
	print "ok " . ($i + 1) . "\n";
}

sub build_phrase {
	my $term_count = int(rand(scalar @_)) + 1;
	my $phrase = $_[int(rand(scalar @_))];
	for my $t (2..$term_count) {
		$phrase .= ' ' . $_[int(rand(scalar @_))];
	}
	return $phrase;
}
