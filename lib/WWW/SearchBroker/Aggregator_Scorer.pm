# WWW::SearchBroker::Aggregator_Scorer
# Results aggregation for WWW::SearchBroker
#
# $Id: Aggregator_Scorer.pm,v 1.4 2003/07/03 13:09:52 nate Exp nate $

=head1 NAME

WWW::SearchBroker::Aggregator_Scorer - Results aggregation for the SearchBroker

=head1 SYNOPSIS

	use WWW::SearchBroker::Aggregator_Scorer;

	my $query = 'foo bar'
	my $result = 'foodumentally barupulous';
	my $search_url = 'http://foo.com/fnord/';
	my $access = 1;
	print "Scoring $query in $result at $search_url with access = $access\n";
	# Score a specific result
	my $score = score($query,$result,$search_url,$access);
	print "\n<<<Score = $score>>>\n";

	# Aggregate (with scoring) a results set
	# Access need to be stored against individual result/results set,
	# not globally across all results.
	$aggregated_results_ref = aggregate($query,$results_ref,$access);

=head1 DESCRIPTION

Aggregates and score results and return a sorted list.  Part of
the the search broker (WWW::SearchBroker).

=head2 EXPORT

score(), aggregate()

=cut

package WWW::SearchBroker::Aggregator_Scorer;
our $VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

use strict;
use warnings;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
require Exporter;
@ISA=qw(Exporter);
@EXPORT=();
@EXPORT_OK=qw(score aggregate);

###########################################################################
# Imports and globals #####################################################
###########################################################################
# Preloaded methods go here.
use Data::Dumper qw(Dumper);	# for debugging
use Date::Manip qw(ParseDate UnixDate DateCalc Date_Init);
# CPANtesters seem to require the following two lines:
eval { Date_Init(); };
Date_Init("TZ=GMT") if $@;
use Data::Serializer;		# for transceiving data structures over sockets
use Carp;

###########################################################################
# Globals
use constant DEBUG_LOW => 1;		# minimal debug info
use constant DEBUG_MEDIUM => 2;		# moderate debug info
use constant DEBUG_HIGH => 3;		# verbose debug info
use constant DEBUG => DEBUG_LOW;	# Debugging is ON/off
my $obj = Data::Serializer->new();

###########################################################################
# Subroutines and internal functions ######################################
###########################################################################

=over 4

=item score($query,$result_hash,$access)

=cut

###########################################################################
# ARGUMENTS:
#  Query -- search query/term
#  Results text -- text returned from original search engine
#  Link -- link text to search result
#  Access type -- 0 = public, 1 = restricted, 2 = private
###########################################################################
# Not a particularly smart scorer, e.g. doesn't handle duplicate
# search terms (i.e. multiple instances of 'foo' in the query).
sub score($$$) {
	my ($query,$result,$access_type) = @_;
	my $score = 0;
	my @bits = split /\s+/, $query;
	my $glob = join('.*?', @bits) || $query;
	croak "[AGGSCORE: Undefined query!]" if !defined $glob;

	carp "[AGGSCORE: Scoring result (" . Dumper($result) . ')]' if DEBUG >= DEBUG_MEDIUM;

	# 3. Personalised results are more interesting than general ones
	if ($access_type == 2) {
		$score += 25;
	}

	if (!defined $result->{'description'}) {
		carp "[AGGSCORE: No description for $result->{'title'}?]" if DEBUG >= DEBUG_LOW;
		$result->{'description'} = '(None)';
	}

	# 1. Exact matches are more interesting than approximate matches
	if ($result->{'description'} =~ /($glob)/s) {
		my $match = $1;
		# 7. Word proximity is an indicator of relevance (i.e. the closer the search terms are to each other, the better)
		carp "[AGGSCORE: Found all terms! ($match) (length=" . length($match) . ')]' if DEBUG >= DEBUG_MEDIUM;
		$score += 100;
	}

	# 4. Titles / link text are better indicators than the rest of the content
	foreach my $bit (@bits) {
		next unless length($bit) > 2; # No short snippets
		# This should probably throw away "?.*", since results URLs are likely to have args matching the query terms...
		if ($result->{'title'} =~ m#\Q$bit\E#) {
			carp "[AGGSCORE: Found in title/href!]" if DEBUG >= DEBUG_MEDIUM;
			$score += 25;
		}
	}

	if ($result->{'description'} =~ /<\s*title|href/) {
		carp "[AGGSCORE: Found in title/href!]" if DEBUG >= DEBUG_MEDIUM;
		$score += 25;
	}

	# 6. More recent articles are more interesting than old ones
	# Check for various date formats
	if ($result->{'description'} =~ m#(\d{1,2}[\-/\s]\d{1,2}[\-/\s]\d{2,4})#) {
		my $date = $1;
		carp "[AGGSCORE: Found date=$1=", ParseDate($1), "=", UnixDate(ParseDate($1),"%s"), "]" if DEBUG >= DEBUG_MEDIUM;
		if (my $result = &DateCalc($date,"today")) {
			my ($wk,$dd) = $result =~ m#[\+\-]0:0:(\d+):(\d+):#;
			carp "[AGGSCORE: Date is $wk weeks and $dd days from now]" if DEBUG >= DEBUG_HIGH;
			if ($wk == 0 && $dd < 5) {
				carp "[AGGSCORE: Within 5 days of today!]" if DEBUG >= DEBUG_MEDIUM;
				$score += 50;
			}
		}
	}

	# 8. URLs with the search term in them are more relevant than those without. 
	foreach my $bit (@bits) {
		next unless length($bit) > 2; # No short snippets
		# This should probably throw away "?.*", since results URLs are likely to have args matching the query terms...
		if ($result->{'link'} =~ m#\Q$bit\E#) {
			carp "[AGGSCORE: Bit in URL! ($bit, $result->{'link'})]" if DEBUG >= DEBUG_MEDIUM;
			$score += 25;
		}
	}

	# 5. Home pages (i.e. URLs ending in a slash, or URLs that are just host names) are more relevant than other pages
	if (my ($host,$rest) = $result->{'link'} =~ m#http://([^/]+/?)(.*)#) {
		carp "[AGGSCORE: ($host)($rest)]" if DEBUG >= DEBUG_MEDIUM;
		if (!defined $rest || $rest eq '') {
			carp "[AGGSCORE: Home page!]" if DEBUG >= DEBUG_MEDIUM;
			$score += 100;
		} elsif ($rest =~ m#/$#) {
			carp "[AGGSCORE: Sub-home page!]" if DEBUG >= DEBUG_MEDIUM;
			$score += 50;
		}
	}

	return $score;
} # end score()
###########################################################################

=item aggregate($query,$results_ref,$access)

=cut

###########################################################################
# ARGUMENTS:
#  Query -- search query/term
#  Results ref -- Reference to the array of hashes of results
#  Access type -- 0 = public, 1 = restricted, 2 = private
###########################################################################
sub aggregate($$$) {
	my ($query,$all_results,$access) = @_;
	my %return_set;

	carp '[AGGSCORE: A&S for ' . Dumper($all_results) . ']' if DEBUG >= DEBUG_LOW;
	foreach my $result_set (@{$all_results}) {
		my ($agent,$res_list) = each %{$result_set};
		if (!defined $res_list) {
			# We're throwing these away.  We should probably
			# mark/remember them somehow...
			carp "[AGGSCORE: Skipping bogus (empty result set) $agent results]" if DEBUG >= DEBUG_MEDIUM;
			next;
		}
		carp "[AGGSCORE: Scoring $agent results (" . scalar(@{$res_list}) . ')]' if DEBUG >= DEBUG_MEDIUM;
		foreach my $encoded (@{$res_list}) {
			chomp $encoded;
			my $result = $obj->deserialize($encoded);
			carp "[AGGSCORE: Found result (" . Dumper($result) . '), scoring...]' if DEBUG >= DEBUG_MEDIUM;
			my ($k,$v) = each %{$result};
			if ($v->{'title'} eq 'No results found') {
				carp "[AGGSCORE: Skipping 'No results found' ($k)]" if DEBUG >= DEBUG_MEDIUM;
				next;
			}
			my ($current_score) = $v->{'relevance'} =~ /^(\d)/; # Just the first digit, we want it to (usually) be smaller than the calculated score;
			my $calc_score = 0;
			$calc_score = score(quotemeta($query),$v,0);
			$calc_score = $current_score if defined $current_score and $current_score > $calc_score;
			carp "[AGGSCORE: Score=$calc_score]" if DEBUG >= DEBUG_MEDIUM;
			push(@{$return_set{$calc_score}},$v);
		}
	}
	carp '[AGGSCORE: A&S ranks as ' . Dumper(\%return_set) . ']' if DEBUG >= DEBUG_LOW;

	my @ret;
	foreach my $k (sort { $b <=> $a } keys %return_set) {
		foreach my $v (@{$return_set{$k}}) {
			push(@ret,$v);
		}
	}
	return \@ret;
} # end aggregate()
###########################################################################

=back

=head1 SEE ALSO

L<WWW::SearchBroker>, L<WWW::SearchBroker::Search>,
L<WWW::SearchBroker::Broker>, L<WWW::SearchBroker::Common>,
I<tests/www_searchbroker.pl>.

=head1 AUTHOR

Nathan Bailey, E<lt>nate@cpan.orgE<gt>

=cut

1;
__END__
