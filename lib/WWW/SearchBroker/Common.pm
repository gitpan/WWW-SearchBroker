# WWW::SearchBroker::Common
# Service functions for all components of the search broker (SearchBroker)
#
# $Id: Common.pm,v 1.1 2003/06/29 14:42:59 nate Exp nate $

=head1 NAME

WWW::SearchBroker::Common - Service functions for all components of SearchBroker

=head1 SYNOPSIS

	use WWW::SearchBroker::Common qw(DEBUG);

=head1 DESCRIPTION

Service functions for all components of the search broker
(WWW::SearchBroker).

=head1 AUTHOR

Nathan Bailey, E<lt>nate@cpan.orgE<gt>

=head1 SEE ALSO

L<WWW::SearchBroker>, L<WWW::SearchBroker::Search>,
I<tests/www_searchbroker.pl>.

=cut

package WWW::SearchBroker::Common;
our $VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw( DEBUG_LOW DEBUG_MEDIUM DEBUG_HIGH DEBUG
	SERVER_PORT AGENT_PORT_MIN AGENT_PORT_MAX
	TEMP_FILE_PATH AGENT_PATH
	STUDENT_MAIL_SERVER STAFF_MAIL_SERVER STAFF_USERNAME LDAP_SERVER );

use strict;
use warnings;

###########################################################################
# Globals
use constant DEBUG_LOW => 1;		# minimal debug info
use constant DEBUG_MEDIUM => 2;		# moderate debug info
use constant DEBUG_HIGH => 3;		# verbose debug info
use constant DEBUG => DEBUG_MEDIUM;	# Debugging is ON/off
use constant TEMP_FILE_PATH => '/tmp/';	# Temporary files (will be sockets)
use constant AGENT_PATH => '../agents';	# Agents path (needs a better way to be done)

###########################################################################
# Broker config -- should be factored out into a config file?
use constant SERVER_PORT => 9000;	# pick something not in use
use constant AGENT_PORT_MIN => 9001;	# pick something not in use
use constant AGENT_PORT_MAX => 9099;	# pick something not in use
###########################################################################

################################################################# CHANGE
# These values will need to be changed for imap/ldap to work	# CHANGE
use constant STUDENT_MAIL_SERVER => 'staffmail.domain.com';	# CHANGE
use constant STAFF_MAIL_SERVER => 'studentmail.domain.com';	# CHANGE
use constant STAFF_USERNAME => 'myname';			# CHANGE
use constant LDAP_SERVER => 'directory.domain.com';		# CHANGE

1;

__END__
