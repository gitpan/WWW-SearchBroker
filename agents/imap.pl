#!/usr/bin/env perl
# Typically run from broker.pl as:
#	agents/$agent.pl $sid "$query" 'username' 'password'
# sid -- search id
# query -- search query
# username -- MDS username
# password -- MDS password (what about passwords with quotes in them?)
use strict;
use Mail::IMAPClient;
use Data::Dumper;
use Data::Serializer;
use Carp;
use WWW::SearchBroker::Common qw(DEBUG DEBUG_HIGH TEMP_FILE_PATH STAFF_MAIL_SERVER STUDENT_MAIL_SERVER print_line);

if (scalar @ARGV < 2) {
	warn scalar @ARGV . " arguments presented, two required:";
	warn "Usage: $0 103 search_query\n";
	exit;
}
my ($sid, $what,$user,$pass) = @ARGV;
umask(0067); # Initial file perms are 600, indicating not yet finished
my $filename = TEMP_FILE_PATH . "$sid.txt";
my $server = STAFF_MAIL_SERVER;
$server = STUDENT_MAIL_SERVER if $user =~ /\d$/; # UGLY!!! # Can't access student email from non-portal
my $imap = Mail::IMAPClient->new( Server => $server,
		#Debug => 1,
		Uid => 1,
		User   => $user,
		Password => $pass) || die "[AGENT: Couldn't connect no imap server/invalid credentials]";
my $obj = Data::Serializer->new();
my $count = 0;
foreach my $folder ('INBOX', 'Sent') {
	# TEXT for BODY and all HEADERs
	carp "[AGENT: imap SEARCH UNDELETED BODY $what >> $filename (folder=$folder)]\n" if DEBUG;
	$imap->examine($folder) || die "[AGENT: Folder $folder doesn't exist!]";
	carp "[AGENT: $folder has " . $imap->message_count($folder) . " messages, searching for '$what']\n" if DEBUG;
	my @uids = $imap->search(qq/UNDELETED BODY "$ARGV[1]"/);
	carp "[AGENT: Found $#uids matching message(s) in $folder, scanning...]\n" if DEBUG;
	foreach my $i (@uids) {
		my $headers = $imap->parse_headers($i,"Date","From","Subject","To","Cc");
		#carp "[AGENT: " . Dumper($headers) . "]\n" if DEBUG;
		my $from = join(',', @{$headers->{From}});
		if ($folder eq '"Sent"') {
			$from = join(',', @{$headers->{'To'}});
		}
		if ($from =~ /([\^)]+)/) {
			$from = $1;
		} elsif ($from =~ /(.*)<[^>]+>(.*)/) {
			$from = $1.$2;
		}
		# For new imapeg filters
		#print "\n".$header{"From"},$header{"To"},$header{"Subject"}."\n";
		$from =~ s/^\s+//;
		$from =~ s/\s+$//;
		$from = substr($from,0,19);
		my $date = join('', @{$headers->{"Date"}});
		$date =~ s/.,//; # no comma, two letter days
		$date =~ s/:\d{2}\s[\+-]?\d{4}//; # no seconds/GMT
		$date =~ s/.\s\d{4}//; # no year
		$date =~ s/\s{2,}/ /; # one space only
		$date =~ s/(\d)\s(\w)/$1\/$2/;
		my $subj = '';
		$subj = substr(join('', @{$headers->{"Subject"}}),0,34) if defined $headers->{"Subject"};
		carp "[AGENT: " . sprintf("\%5d \%s \%-19s \%1d\%s \%-14s \%-34s\n", $i, " ", $from, "0", "k", $date, $subj) . "]\n" if DEBUG > DEBUG_HIGH;
		my %result = (
			'title' => $subj,
			'link' => "/email/?folder=$folder" . '&action=Read&id=' . $i,
			'description' => $from,
			'relevance' => '',
		);
		print_line($filename,$obj->serialize({ $count++ => \%result}) . "\n");
		#print_line($filename,Dumper \%result);
	}
}
$imap->disconnect();
chmod(0644, $filename); # Group readable, indicating finished
carp "[AGENT: Completed successfully (saved to $filename)]\n" if DEBUG;
