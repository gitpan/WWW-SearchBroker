# WWW::SearchBroker
# Parallel metasearcher for Internet-based services (WWW, IMAP, LDAP, etc.)
#
# $Id: SearchBroker.pm,v 0.4 2003/06/30 13:27:12 nate Exp nate $

=head1 NAME

WWW::SearchBroker - Parallel metasearcher for Internet-based services (WWW, IMAP, LDAP, etc.)

=head1 SYNOPSIS

...

=head1 DESCRIPTION

Parallel metasearcher for Internet-based services (WWW, IMAP, LDAP,
etc.).  See 'Personalised metasearch: Augmenting your brain'
L<http://ausweb.scu.edu.au/aw03/papers/bailey/> for more details.

=head1 AUTHOR

Nathan Bailey, E<lt>nate@cpan.orgE<gt>

=head1 SEE ALSO

L<WWW::SearchBroker::Broker>, L<WWW::SearchBroker::Search>,
I<tests/www_searchbroker.pl>.

=cut

package WWW::SearchBroker;
our $VERSION = sprintf("%d.%02d", q$Revision: 0.4 $ =~ /(\d+)\.(\d+)/);

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
