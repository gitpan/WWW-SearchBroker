# WWW::SearchBroker::Search
# Object/methods for the search client component of the search broker (SearchBroker)
#
# $Id: Search.pm,v 1.5 2003/07/03 13:09:52 nate Exp nate $

=head1 NAME

WWW::SearchBroker::Search - Search client component of the SearchBroker

=head1 SYNOPSIS

	use WWW::SearchBroker::Search;

	# Port the broker server is running on
	my $port = 9000;

	# Create a search requestor
	my $search = new WWW::SearchBroker::Search(port => $port);

	# Query
	my $srch = 'SEARCH<15><a,b,c><foo bar>';

	# Send query
	$search->send_query();

	# Print results
	$search->dump_results();

=head1 DESCRIPTION

Service functions for the search component of the search broker
(WWW::SearchBroker).

=cut
###########################################################################
# Sends requests of the form:
#  SEARCH<timeout><where[,where,...]><what[ foo bar]>
#   Conduct a search of the requested agents, where:
#	timeout	= time in seconds to wait for agents to respond
#	where	= names of agents (as per 'LIST' below)
#	what	= search terms (passed exactly to the search engine)
#
#  LIST
#   List the available search agents
#       (no arguments expected/required)
###########################################################################

package WWW::SearchBroker::Search;
our $VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

use strict;
use warnings;

###########################################################################
# Imports and globals #####################################################
###########################################################################
# Preloaded methods go here.
use Data::Dumper qw(Dumper);	# for debugging
use IO::Socket;			# for interprocess communications (IPC)
use IO::Select;			# for interprocess communications (IPC)
use Data::Serializer;		# for transceiving data structures over sockets
use Carp;
use List::Misc qw(first_value all_values);
use WWW::SearchBroker::Common qw(DEBUG_LOW DEBUG_MEDIUM DEBUG_HIGH
	SERVER_PORT AGENT_PORT_MIN AGENT_PORT_MAX
	TEMP_FILE_PATH AGENT_PATH);

###########################################################################
# Globals
use constant DEBUG => DEBUG_LOW;	# Debugging is ON/off
my $obj = Data::Serializer->new();
###########################################################################

###########################################################################
# Methods and internal functions ##########################################
###########################################################################

=over 4

=item new(port => $server_port)

Creates a C<WWW::SearchBroker::Search> searcher that makes requests
to a C<WWW::SearchBroker::Broker> broker on $server_port.

=cut

sub new {
	my $proto = shift;
	my $class = ref ($proto) || $proto;

	my %args = @_;

	# Connect to broker listener
	carp "[QUERY: Creating new search object]" if DEBUG;
	my $remote = IO::Socket::INET->new(
			    Proto    => "tcp",
			    PeerAddr => "localhost",
			    PeerPort => $args{port},
			);
	die "QUERY: Can't connect to broker on $args{port}" unless $remote;
	carp "[QUERY: Connected to broker]" if DEBUG;

	my $self = {
		_remote		=> $remote,
	};

	bless $self, $class;

	return $self;
}

=item send_query()

Send the specified query to the broker for execution.

=cut

sub send_query {
	my ($self,$query_type,$query,@agents) = @_;
	carp '[QUERY: Send request ' . join(', ', @_) . ']' if DEBUG >= DEBUG_HIGH;

	print { $self->{_remote} } $obj->serialize({
			query_type => $query_type,
			query => $query,
			agents => \@agents,
	});
	print { $self->{_remote} } "\n";
	carp "[QUERY: Sent '$query_type' query to broker]" if DEBUG;
	my $r = $self->get_response();
	$r = $r->{m};
	carp "[QUERY: Got initial response to query -- ACK?]" if DEBUG;
	if ($r && $r =~ /ACK/) {
		carp "[QUERY: Ack received]" if DEBUG;
	} else {
		carp "[QUERY: No ack!]" if DEBUG;
	}
} # end send_query()
###########################################################################

=item get_results()

Read the aggregated results back from the broker.

=cut

sub get_results {
} # end get_results()
###########################################################################

=item dump_results()

Dump the result set to stdout/stderr.

=cut

sub dump_results {
	my ($self) = @_;

	my @results_list;
	my $result_set = $self->get_response();
	if (!defined $result_set) {
		carp "[QUERY: No results (broken socket?)]" if DEBUG >= DEBUG_LOW;
		return undef;
	}

	carp "[QUERY: Response received: " . Dumper($result_set) . "]" if DEBUG;
	if ($result_set->{'query'} eq 'LIST') {
		return @{$result_set->{'results'}};
	}

	carp "[QUERY: Result set: " . Dumper($result_set->{'results'}) . "]" if DEBUG;
	return [ 'No results found' ] if (!@{$result_set->{'results'}});
	return @{$result_set->{'results'}};
} # end dump_results()
###########################################################################

=item get_response($file_handle)

Read an agent response from the specified file handle.  Return it in
deserialized state (i.e. as a perl object).

=cut

sub get_response {
	my ($self) = @_;

	my $res;
	#while ( <$self->{_remote}> ) { # What's wrong with this?
	while ( readline(*{$self->{_remote}}) ) {
		chomp;
		carp "[QUERY: get_response: Read ($_)]" if DEBUG >= DEBUG_MEDIUM;
		return $obj->deserialize($_);
	}
	carp "[QUERY: Unexpected closure of socket]" if DEBUG;
	return undef;
} # end get_response()
###########################################################################

=back

=cut

# Clean up login if user_agent wasn't explicilty logged out
sub DESTROY {
	my $self = shift;
	if ($self->{_remote}) {
		$self->{_remote}->close();
	}
}

=head1 SEE ALSO

L<WWW::SearchBroker>, L<WWW::SearchBroker::Broker>,
L<WWW::SearchBroker::Common>, L<WWW::SearchBroker::Aggregator_Scorer>,
I<tests/www_searchbroker.pl>.

=head1 AUTHOR

Nathan Bailey, E<lt>nate@cpan.orgE<gt>

=cut

1;

__END__
