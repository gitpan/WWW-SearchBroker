# WWW::SearchBroker::Common
# Service functions for all components of the search broker (SearchBroker)
#
# $Id: Common.pm,v 1.3 2003/07/03 13:09:52 nate Exp nate $

=head1 NAME

WWW::SearchBroker::Common - Service functions for all components of SearchBroker

=head1 SYNOPSIS

	use WWW::SearchBroker::Common qw(DEBUG);

=head1 DESCRIPTION

Service functions for all components of the search broker
(WWW::SearchBroker).

=cut

package WWW::SearchBroker::Common;
our $VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw( DEBUG_LOW DEBUG_MEDIUM DEBUG_HIGH DEBUG
	SERVER_PORT AGENT_PORT_MIN AGENT_PORT_MAX
	TEMP_FILE_PATH AGENT_PATH STAFF_USERNAME 
	STUDENT_MAIL_SERVER STAFF_MAIL_SERVER LDAP_SERVER NEWS_SERVER
	print_line failed parse_results remove_results );

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

###########################################################################
# Site-specific config -- you will need to edit these values
use constant STUDENT_MAIL_SERVER => 'staffmail.yourdomain.com';
use constant STAFF_MAIL_SERVER => 'studentmail.yourdomain.com';
use constant STAFF_USERNAME => 'yourname';
use constant LDAP_SERVER => 'directory.yourdomain.com';
use constant NEWS_SERVER => 'newsserver.yourdomain.com';

###########################################################################
# Functions -- these are for search agents only and perhaps should
# be kept elsewhere...

# For printing a line into a results file
sub print_line {
	my ($filename,$line) = @_;
	if (open(SID_FILE,">>$filename")) {
		print SID_FILE $line;
		close(SID_FILE);
	} else {
		die "[COMMON: Couldn't append to $filename ($!)]";
	}
} # print_line()

# For printing a failed search result; not used as yet
sub failed {
	print_line("FAILED!\n");
} # failed()

# For checking results archived to a file
sub parse_results {
	use Data::Serializer;
	use Data::Dumper;
	use Carp;
	my $filename = shift @_;

	my $obj = Data::Serializer->new();
	if (open(SEARCH, TEMP_FILE_PATH . $filename . ".txt")) {
		carp "[COMMON: Found results, reading...]\n" if DEBUG;
		my @data = <SEARCH>;
		close(SEARCH);
		foreach my $d (@data) {
		       chomp $d;
		       carp "[COMMON: " . Dumper($obj->deserialize($d)) . "]" if DEBUG >= DEBUG_MEDIUM;
		}
		carp "[COMMON: Found " . scalar(@data) . " results]" if DEBUG >= DEBUG_LOW;
	} else {
		die "[COMMON: Couldn't open $filename: $!]";
	}
} # parse_results()

# For deleting results archival files
sub remove_results {
	my $filename = shift @_;

	unlink(TEMP_FILE_PATH . $filename . ".txt");
} # remove_results()

=head1 SEE ALSO

L<WWW::SearchBroker>, L<WWW::SearchBroker::Search>,
L<WWW::SearchBroker::Broker>, L<WWW::SearchBroker::Aggregator_Scorer>,
I<tests/www_searchbroker.pl>.

=head1 AUTHOR

Nathan Bailey, E<lt>nate@cpan.orgE<gt>

=cut

1;

__END__
