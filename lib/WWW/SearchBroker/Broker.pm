# WWW::SearchBroker::Broker
# Service functions for the broker component of the search broker (SearchBroker)
#
# $Id: Broker.pm,v 1.6 2003/07/03 13:09:52 nate Exp nate $

=head1 NAME

WWW::SearchBroker::Broker - Service functions for broker component of SearchBroker

=head1 SYNOPSIS

	use WWW::SearchBroker::Broker;

	# Create a Broker
	my $broker = new WWW::SearchBroker::Broker(...);

	# Listen for requests and response
	while ($broker->event_loop())
		{ }

	# Service functions (internal only)
	my $sid = $broker->get_sid();
	my $success = agent_request($sid,$agent,$query);
	my $response = $self->sock_agent_request($s,$what);
	my $response = get_response($file_handle);
	my $is_complete = check_for_completion(@a_request);
	my $success = $broker->aggregate_and_return($var,$val,$req);

=head1 DESCRIPTION

Service functions for the broker component of the search broker
(WWW::SearchBroker).

=cut
#
# Expects requests of the form:
#  SEARCH<timeout><where[,where,...]><what[ foo bar]>
#   Conduct a search of the requested agents, where:
#	timeout	= time in seconds to wait for agents to respond
#	where	= names of agents (as per 'LIST' below)
#	what	= search terms (passed exactly to the search engine)
#
#  LIST
#   List the available search agents
#       (no arguments expected/required)
#

package WWW::SearchBroker::Broker;
our $VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

use strict;
use warnings;

###########################################################################
# Imports and globals #####################################################
###########################################################################
# Preloaded methods go here.
use Data::Dumper qw(Dumper);	# for debugging
use IO::Socket;			# for interprocess communications (IPC)
use IO::Select;			# for interprocess communications (IPC)
use Net::hostent;		# for OO version of gethostbyaddr
use Data::Serializer;		# for transceiving data structures over sockets
use Carp;
use List::Misc qw(first_value all_values);
use WWW::SearchBroker::Aggregator_Scorer qw(aggregate);
use WWW::SearchBroker::Common qw(DEBUG_LOW DEBUG_MEDIUM DEBUG_HIGH
	SERVER_PORT AGENT_PORT_MIN AGENT_PORT_MAX
	TEMP_FILE_PATH AGENT_PATH);

###########################################################################
# Globals
use constant DEBUG => DEBUG_MEDIUM;	# Debugging is ON/off
my %agents;
my $obj = Data::Serializer->new();

my $path = AGENT_PATH . '/*pl';
my @AGENT_LIST = `ls $path`;
chomp @AGENT_LIST;
###########################################################################

###########################################################################
# Methods and internal functions ##########################################
###########################################################################

=over 4

=item new(port => $server_port)

Creates a C<WWW::SearchBroker::Broker> broker listening for requests
on $server_port.

=cut

sub new {
	my $proto = shift;
	my $class = ref ($proto) || $proto;

	my %args = @_;

	# Start broker listener
	my $server = IO::Socket::INET->new( Proto     => 'tcp',
					 LocalPort => $args{port} || SERVER_PORT,
					 Listen    => SOMAXCONN,
					 Reuse     => 1);

	die "BROKER: Can't setup server" unless $server;
	carp "[BROKER: Server $0 accepting clients on " . SERVER_PORT . "]" if DEBUG >= DEBUG_LOW;

	# Attach listening handles
	my $handles = new IO::Select();
	$handles->add($server);

	# Unique reference id for each search
	my (%sid, %requests, %fileno_to_sid);

	my $self = {
		_server		=> $server,
		_handles	=> $handles,
		_sid		=> \%sid,
		_requests	=> \%requests,
		_fileno_to_sid	=> \%fileno_to_sid,
		_timeout	=> $args{timeout} || 10,
	};

	bless $self, $class;

	return $self;
}

=item event_loop()

The main deal -- wait for search requestions, farm them out to
required agents.  Returns true unless a 'QUIT' request has been
received, in which case it returns false (and the script running
the broker should finish).

=cut

sub event_loop($) {
	my ($self) = @_;
	my $do_continue = 1;

	carp localtime() . "" if DEBUG >= DEBUG_HIGH;
	my ($s_handles) = IO::Select->select($self->{_handles}, undef, undef, 1);
	for my $hndl (@$s_handles) {
		###########################################################
		### New connection?
		if ($hndl == $self->{_server}) {
			my @w = $hndl->accept();
			$self->{_handles}->add($w[0]);
			my $req_id = $self->get_sid();
			my $hostinfo = gethostbyaddr($w[0]->peeraddr);
			my $who = $hostinfo->name || $w[0]->peerhost;
			$self->{_requests}->{$req_id} = [
				$w[0],
				fileno($w[0]),
				$who,
				time(),
			];
			$self->{_fileno_to_sid}->{$self->{_requests}->{$req_id}[1]} = $req_id;
			carp sprintf("[BROKER: Connect from %s has been allocated SID %s]", $who, $req_id) if DEBUG >= DEBUG_LOW;
			$w[0]->print($obj->serialize({m => "ACK"}) . "\n");
		###########################################################
		### Command on existing connection
		} else {
			if (my $line = <$hndl>) {
				chomp $line;
				carp "[BROKER: Deserializing... ($line)]" if DEBUG >= DEBUG_HIGH;
				my $deserialized = $obj->deserialize($line);
				carp "[BROKER: Parsing " . Dumper($deserialized) . "]" if DEBUG >= DEBUG_MEDIUM;
				#carp Dumper $deserialized if DEBUG;
				if ($deserialized->{query_type} =~ /SEARCH/) {
					my $q = $deserialized->{query};
					push(@{$self->{_requests}->{$self->{_fileno_to_sid}->{fileno($hndl)}}}, $q);
					foreach my $a (all_values($deserialized->{agents})) {
						carp "[BROKER: Searching with '$a']" if DEBUG;
						my $s = $self->get_sid();
						push(@{$self->{_requests}->{$self->{_fileno_to_sid}->{fileno($hndl)}}}, { $s => $a });
						my $ret = agent_request($s,$a,$q);
						if (!defined $ret) {
							carp "[BROKER: Removing failed agent '$a' from search agent set]" if DEBUG >= DEBUG_MEDIUM;
							pop(@{$self->{_requests}->{$self->{_fileno_to_sid}->{fileno($hndl)}}});
							# Make this a fatal error for now:
							$self->aggregate_and_return(timeout => 1, $self->{_requests}->{$self->{_fileno_to_sid}->{fileno($hndl)}});
							croak "[BROKER: Failed agent is fatal error ('$a')";
						}
					}
# Need to work this out later
##					if (scalar @{$self->{_requests}->{$self->{_fileno_to_sid}->{fileno($hndl)}}} == 0) {
##						$self->aggregate_and_return(timeout => 1, $self->{_requests}->{$self->{_fileno_to_sid}->{fileno($hndl)}});
##						carp "[BROKER: No valid searches for " . $self->{_requests}->{$self->{_fileno_to_sid}->{fileno($hndl)}} . ", returning empty result set]" if DEBUG;
##					}
				} elsif ($deserialized->{query_type}  =~ /LIST/) {
					# Needs to be rewritten
					carp "[BROKER: List request received, responding with list of agents]" if DEBUG >= DEBUG_MEDIUM;
					my $sid = $self->get_sid();
#					my @agents = keys %agents;
					my @agents = @AGENT_LIST;
					map { $_ =~ s#.*/## }  @agents;
					print $hndl $obj->serialize({
						'query' => 'LIST',
						'agent' => 'LIST',
						'result_count' => scalar @agents,
						'next_link' => '',
						'timeout' => 0,
						'results' => \@agents,
					}) . "\n";
#					my $i = 0;
#					foreach my $a (@agents) {
#						print $hndl "$sid:" . $i++ . ":$a running on port " . $agents{$a} . "\n";
#					}
				} elsif ($deserialized->{query_type}  =~ /QUIT|EXIT/) {
					carp "[BROKER: Quit request received, completing and exiting]" if DEBUG >= DEBUG_MEDIUM;
					my @agents = ( 'Quitting as per request' );
					print $hndl $obj->serialize({
						'query' => 'QUIT',
						'agent' => 'QUIT',
						'result_count' => '',
						'next_link' => '',
						'timeout' => 0,
						'results' => \@agents,
					}) . "\n";
					$do_continue = 0;
					last;
				} else {
					carp "[BROKER: Invalid request ($line) received]" if DEBUG >= DEBUG_MEDIUM;
					print $hndl "Invalid request: $line\n";
				}
			} else {
				my $fn = fileno($hndl);
				$self->{_handles}->remove($hndl);
				close ($hndl);
				carp "[BROKER: Close from fn=$fn]" if DEBUG >= DEBUG_MEDIUM;
				#printf "[BROKER: Close from %s]\n", $hostinfo->name || $client->peerhost;
			}
		}
	}
	###########################################################
	### Check for completed requests
	my $t = time();
	foreach my $k (keys %{$self->{_requests}}) {
		carp "[BROKER: Checking query $k for completion]" if DEBUG >= DEBUG_HIGH;
		# Skip if this request doesn't have any agents
		next unless scalar @{$self->{_requests}->{$k}} > 5;
		#carp '[BROKER: $k has requests = (' . Dumper(\@{$self->{_requests}->{$k}}) . ')]' if DEBUG >= DEBUG_HIGH; # Trying to catch the heisenbug...
		if (($t - $self->{_requests}->{$k}[3]) > $self->{_timeout}) {
			carp "[BROKER: $k timed out!]" if DEBUG >= DEBUG_MEDIUM;
			# Send on as much as we got
			#warn Dumper $self->{_requests}->{$k};
			$self->aggregate_and_return(timeout => 1, $self->{_requests}->{$k});
			# Delete the entry
			delete $self->{_requests}->{$k};
		} elsif (check_for_completion(@{$self->{_requests}->{$k}})) {
			carp "[BROKER: $k completed, aggregating and returning]" if DEBUG >= DEBUG_MEDIUM;
			$self->aggregate_and_return(timeout => 0, $self->{_requests}->{$k});
			# Delete the entry
			delete $self->{_requests}->{$k};
		}
	}

	return $do_continue;
###	while (<$client>) {
#####     alarm($timeout);
###	} continue {
###		 carp $client "\n." if DEBUG >= DEBUG_MEDIUM;
###		 carp $client "Command? " if DEBUG >= DEBUG_MEDIUM;
###	}
###	close $client;
##  alarm($previous_alarm);
} # end event_loop()
###########################################################################

=item get_sid()

Generate a unique key for this search (search id = sid)

=cut

sub get_sid($) {
	my ($self) = @_;

	my ($t, $s) = (time(), 0);
	while($self->{_sid}->{$t.$s}) {
		$s++;
	}
	$self->{_sid}->{$t.$s}++;
	return $t.$s;
} # end get_sid()
###########################################################################

=item agent_request($sid,$agent,$query)

Run (fork) a query using the specified agent.

=cut

sub agent_request($$$) {
	my ($sid,$agent,$query) = @_;
	carp "[BROKER: Spawning '$agent'-search for '$query', sid = $sid]" if DEBUG >= DEBUG_MEDIUM;

	my $ret;
	if ($ret = fork()) {
		my $execpath = AGENT_PATH . "/$agent.pl";
		if (-X $execpath) {
			exec(qq{$execpath $sid "$query"});
		}
		carp "[BROKER: Couldn't exec agent: $execpath -- file doesn't exist!]" if DEBUG >= DEBUG_LOW;
		return undef;
	}
	return $ret;
} # end agent_request()
###########################################################################

=item sock_agent_request($s,$what)

Run (through socket 's') a query using the specified agent.
[ Now somewhat stale, will need to be rewritten. ]

=cut

sub sock_agent_request($$$) {
	my ($self,$s,$what) = @_;
	my $sid = $self->get_sid();
	carp "Searching with '$s' to find '$what', sid = $sid" if DEBUG >= DEBUG_MEDIUM;

	my $remote = IO::Socket::INET->new(
			    Proto    => "tcp",
			    PeerAddr => "localhost",
			    PeerPort => $agents{$s},
			)
			or die "cannot connect to port at localhost";

	my $r = get_response($remote);
	$r = $r->{m};
	if ($r && $r =~ /ACK/) {
		carp "Ack received." if DEBUG >= DEBUG_MEDIUM;
	} else {
		carp "No ack!" if DEBUG >= DEBUG_MEDIUM;
	}
	print $remote "QUERY<$what>\n";
	$r = get_response($remote);
	close $remote;
	return $r;
} # end sock_agent_request()
###########################################################################

=item get_response($file_handle)

Read an agent response from the specified file handle.  Return it in
deserialized state (i.e. as a perl object).

=cut

sub get_response($) {
	my $file_handle = shift;
	my $res;
	while ( <$file_handle> ) {
		chomp;
		$res = $_;
		last;
	}
	return $obj->deserialize($res);
} # end get_response()
###########################################################################

=item check_for_completion(@a_request)

Review a request object to find out if it has either finished or
run out of time.  A request object currently consists of a simple(?!)
list consisting of filehandle, filehandle number, host, starttime
and child filehandles).

=cut

sub check_for_completion(@) {
	my @req = @_;
	my $is_complete = 1;
	#carp "[BROKER: Checking agents for completion (" . Dumper(@req). "]" if DEBUG >= DEBUG_HIGH; # Trying to catch the heisenbug
	foreach my $s (splice(@req,5)) {
		#carp Dumper $s if DEBUG >= DEBUG_MEDIUM; # Trying to catch the heisenbug
		my ($srch,$agnt) = each %{$s};
		if (!defined $agnt || !defined $srch) { # How does this happen?  (It's a heisenbug, if I try to dump $s, it's defined, if not, it isn't...)
			carp "[BROKER: Heisenbug found for " . Dumper($s) .
				"(agnt=" . (defined($agnt)?1:0) . ", " .
				"srch=" . (defined($srch)?1:0) . ")!]" if DEBUG >= DEBUG_HIGH;
			$is_complete = 0;
			next;
		}
		carp "[BROKER: Checking agent $agnt for completion ($srch)]" if DEBUG >= DEBUG_HIGH;
		# If the file is group readable, it's finished
		if (my $mode = (stat(TEMP_FILE_PATH . "$srch.txt"))[2]) {
			$mode = sprintf("%04o", $mode & 07777);
			carp "[BROKER: Mode is $mode for $agnt ($srch)]" if DEBUG >= DEBUG_MEDIUM;
			$is_complete = 0 if $mode eq '0600';
		} else {
			carp "[BROKER: No mode (or file doesn't yet exist) => not complete]" if DEBUG >= DEBUG_MEDIUM;
			$is_complete = 0;
		}
	}
	return $is_complete;
} # end check_for_completion()
###########################################################################

=item aggregate_and_return($var,$val,$req)

Consolidate the data generated by agent sub-queries and return it
to the original requestor.

=cut

sub aggregate_and_return($$$$) {
	my ($self,$var,$val,$req) = @_;

	# A horrible way to parse a named argument...
	my $timeout = ($var eq 'timeout' && $val == 1);
	carp '[BROKER: A&R for ' . Dumper($req) . ']' if DEBUG >= DEBUG_MEDIUM;
	my (@r_list,@a_list);
	foreach my $s (splice(@{$req},5)) {
		carp '[BROKER: A&R, agent ' . Dumper($s) . ']' if DEBUG >= DEBUG_MEDIUM;
		my ($s,$a) = each %{$s};
		push(@a_list, $a); # Remember which agents we used
		carp "[BROKER: Checking for results from $a ($s)]" if DEBUG >= DEBUG_MEDIUM;
		if (open(SEARCH, TEMP_FILE_PATH . "$s.txt")) {
			carp "[BROKER: Found results for $a, reading...]" if DEBUG >= DEBUG_MEDIUM;
			my @data = <SEARCH>;
			close(SEARCH);
#foreach my $d (@data) {
#	chomp $d;
#	carp Dumper $obj->deserialize($d) if DEBUG >= DEBUG_MEDIUM;
#}
			push(@r_list, { $a => \@data });
		} else {
			# Should test what happens when this happens...
			push(@r_list, { $a => undef });
			carp "[BROKER: No results for $a!]" if DEBUG >= DEBUG_MEDIUM;
		}
	}
	if (@r_list) {
		carp '[BROKER: Result set = ' . Dumper(@r_list) . ']' if DEBUG >= DEBUG_HIGH;
		my $ref = aggregate($req->[4],\@r_list,0);
		carp '[BROKER: Aggregate result set = ' . Dumper($ref) . ']' if DEBUG >= DEBUG_MEDIUM;
		carp '[BROKER: Returning ' . scalar(@{$ref}) . ' results (aggregated)]' if DEBUG >= DEBUG_LOW;
		$req->[0]->print($obj->serialize({
			'query' => $req->[4],
			'agent' => join(', ', @a_list),
			'result_count' => scalar(@{$ref}),
			'next_link' => "next",
			'timeout' => $timeout,
			'results' => $ref,
		}) . "\n");
	} else {
		carp '[BROKER: Returning no results (result set empty)]' if DEBUG >= DEBUG_LOW;
		$req->[0]->print($obj->serialize({
			'query' => $req->[4],
			'agent' => $req->[5],
			'result_count' => 0,
			'next_link' => 0,
			'timeout' => $timeout,
		}) . "\n");
	}
	carp "[BROKER: Completed request for '$req->[4]', closing connection]" if DEBUG >= DEBUG_LOW;
	# Close down the socket
	$self->{_handles}->remove($req->[0]);
	close($req->[0]);
	# return 1 on success, undef on failure
} # end aggregate_and_return()
###########################################################################

=item fork_and_loop()

For tests (e.g. t/base/search.t).

=cut

###########################################################################
sub fork_and_loop($) {
	my ($self) = @_;

	carp '[BROKER: Forking infinite loop]' if DEBUG >= DEBUG_MEDIUM;
	my $ret;
	if ($ret = fork()) {
		carp "[BROKER: Parent returning (child PID=$ret)]" if DEBUG >= DEBUG_MEDIUM;
		# perldoc -f fork tells us to reopen to /dev/null, will this work?
		close($self->{_server});
		$self->DESTROY;
		return $ret;
	}
	carp '[BROKER: Child looping]' if DEBUG >= DEBUG_MEDIUM;
	while ($self->event_loop())
		{ }
	return undef;
} # end fork_and_loop()
###########################################################################

=back

=cut

# Clean up login if user_agent wasn't explicilty logged out
sub DESTROY {
	my $self = shift;
	carp "[BROKER: Server $0 destroyed]" if DEBUG >= DEBUG_LOW;
#	if ($self->{_server}) {
#	}
}

=head1 BUGS

This module has only been tested on the Monash network using Monash
Internet services.  Since it builds off other CPAN modules, it is
expected that the module will work across a variety of standards-based
environments but this has not been demonstrated.  The author welcomes
feedback (especially patches!) for any assumptions made that don't
comply with different environments.

=head1 SEE ALSO

L<WWW::SearchBroker>, L<WWW::SearchBroker::Search>,
L<WWW::SearchBroker::Common>, L<WWW::SearchBroker::Aggregator_Scorer>,
I<tests/www_searchbroker.pl>.

=head1 AUTHOR

Nathan Bailey, E<lt>nate@cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2002-2003 Nathan Bailey.  All rights reserved.  This module
is free software; you can redistribute it and/or modify it under the
terms of the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any later
version.

=cut

1;

__END__
