# WWW::SearchBroker
# Parallel metasearcher for Internet-based services (WWW, IMAP, LDAP, etc.)
#
# $Id: SearchBroker.pm,v 0.7 2003/07/02 07:40:05 nate Exp nate $

=head1 NAME

WWW::SearchBroker - Parallel metasearcher for Internet-based services (WWW, IMAP, LDAP, etc.)

=head1 SYNOPSIS

	use WWW::SearchBroker::Broker;
	# Create a Broker
	my $broker = new WWW::SearchBroker::Broker(
		timeout => 10, # wait up to 10s for responses from agents
	);
	my $ret = $broker->fork_and_loop();

	use WWW::SearchBroker::Search;
	# Port the broker server is running on
	my $port = 9000;

	# Search query
	my $srch = 'SEARCH<15><a,b,c><foo bar>';

	# Create a search requestor
	my $search = new WWW::SearchBroker::Search(port => $port);

	$search->send_query('SEARCH','perl *pl','grep','grep','grep');
	$search->dump_results();

	# Quit broker
	$search = new WWW::SearchBroker::Search(port => $port);
	$search->send_query('QUIT','','');
	$search->dump_results();

=head1 DESCRIPTION

Parallel metasearcher for Internet-based services (WWW, IMAP, LDAP,
etc.).  See 'Personalised metasearch: Augmenting your brain'
L<http://ausweb.scu.edu.au/aw03/papers/bailey/> for more details.

=cut

package WWW::SearchBroker;
our $VERSION = sprintf("%d.%02d", q$Revision: 0.7 $ =~ /(\d+)\.(\d+)/);

use strict;
use warnings;

###########################################################################

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
