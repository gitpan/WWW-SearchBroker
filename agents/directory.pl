#!/usr/bin/perl -w
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
use WWW::SearchBroker::Common qw(DEBUG DEBUG_HIGH TEMP_FILE_PATH LDAP_SERVER);
use List::Misc qw(first_value all_values);

if (scalar @ARGV < 4) {
	warn scalar @ARGV . " arguments presented, four required:";
	warn "Usage: $0 103 search_query username password\n";
	exit;
}
my ($sid,$query,$user,$pass) = @ARGV;
umask(0067); # Initial file perms are 600, indicating not yet finished
my $filename = TEMP_FILE_PATH . "$sid.txt";
my $obj = Data::Serializer->new();

my $include_schedule = undef;
my $limit = 200;   # maximum number of items returned
my $count;

#########################################################################
# Open all the LDAP stuff
#########################################################################

# we need to use the module
use Net::LDAP;

# we open a new instance of this object (connects to LDAP_SERVER)
my $ld = Net::LDAP->new(LDAP_SERVER);

# check if we got a connection
if (!$ld) {
  die 'ldap_open failed!';
}

# bind anonymously
if (!$ld->bind) {
  $ld->unbind;
  die 'ldap bind failed!';
}

#########################################################################
# Search for NAME or Phone Number
#########################################################################

my ($mesg, $mesgcn, $entry, $filter);
my  $eqkey = ""; my  $eqvalue = "";

if ($query =~ /=/) {
	$filter = "(&(|($query))(objectclass=monashPerson)(|(!(monashpendingdelete=*))(monashgraceperiod=1)))";       # enter a filter key directly
	($eqkey, $eqvalue) = split /=/, $query;
	print("<!--eqkey=$eqkey-->\n");
} else {
	$query = "*$query*"; $query =~ s/ +/*/g;
	$query =~ s/\*\*+/*/g;
	$query =~ s/\*//g if length($query)<3;
	#####################################################################
	# Staff are in two subtrees -- Monash payrolled staff are 'ou=Staff'
	# and associated organizations are 'ou=Associated Organizations'.
	$filter = "(&(|(cn=$query)(ou=$query)(title=$query))(|(ou=Staff)(ou=Associated Organizations))(objectclass=monashPerson)(|(!(monashpendingdelete=*))(monashgraceperiod=1)))";
}

print("<!--filter=$filter-->\n");

$mesg = $ld->search
          (
          sizelimit => $limit,       # Limit number of entries returned
          base   => "o=Monash University, c=au",
          filter => $filter
          );

$count = $mesg->count;

# return DN's as HASH references

my %entries = %{$mesg->as_struct()};
my ($k, $buf);
my ($personaltitle,$cn,$ou,$title,$telephonenumber,$facsimiletelephonenumber);
my ($buildingname,$roomnumber,$l,@mail,$mail,@labeleduri,$labeleduri);
my ($monashgoofeyhandle);

# Sort %entries by Surname and Given Name

my @sorted = sort {
        first_value($a->{'sn'}) cmp first_value($b->{'sn'}) ||
        first_value($a->{'givenname'})
          cmp first_value($b->{'givenname'})
        } (values %entries);

# Display %entries

foreach my $value (@sorted) {
	$personaltitle = join(', ', all_values($value->{'personaltitle'}));
	$cn = join(', ', all_values($value->{'cn'}));
	$ou = join(', ', all_values($value->{'ou'}));
	$title = join(', ', all_values($value->{'title'}));
	$telephonenumber = join(', ', all_values($value->{'telephonenumber'}));
	$facsimiletelephonenumber =
	      join(', ', all_values($value->{'facsimiletelephonenumber'}));
	$buildingname = join(', ', all_values($value->{'buildingname'}));
	$roomnumber = join(', ', all_values($value->{'roomnumber'}));
	$l = join(', ', all_values($value->{'l'}));
	@mail = all_values($value->{'mail'});
	@labeleduri = all_values($value->{'labeleduri'});
	$monashgoofeyhandle =
	      join(', ', all_values($value->{'monashgoofeyhandle'}));
	$eqvalue = join(', ', all_values($value->{$eqkey}));

# Try to make ou= a nicer format

	$ou =~ s/Staff(, )?//; $ou =~ s/(, )?$//;

# Format location information

	my $location = $buildingname."-".$roomnumber.", ".$l;
	$location =~ s/-,//;

# Display the formatted entry
	# print( "<b><big>$personaltitle $cn</big></b><br>" );
	foreach $mail (@mail) {
		if (my $image = get_image('/interactive/directory/its_staff.comp', email => lc($mail))) {
			print(qq(<img src="$image"><br>));
		}
	}

	print("$title<br>\n")  if $title;
	print("$ou<br>\n")  if $ou;
	print("<b><small>Voice:</small></b> $telephonenumber<br>\n")
	      if $telephonenumber;
	print("<b><small>FAX:</small></b> $facsimiletelephonenumber<br>\n")
	      if $facsimiletelephonenumber;
	print("<b><small>Location:</small></b> $location<br>\n")
	      if $location;
	if (@mail) {
		print("<b><small>Email:</small></b>\n");
		foreach $mail (@mail) {
#		 $mail =~ s/(.*)/<a href=\"mailto:$1\">$1<\/a> /;
			$mail =~ s#^(.*)$#<a href=\"/email/sendmail.html?to=$1\">$1</a> #;
			print($mail);
			}
		print("<br>\n");
	}

	if (@labeleduri) {
		print("<b><small>Web:</small></b>\n");
		foreach $labeleduri (@labeleduri)
			{
			unless ($labeleduri =~ /^http/)
			{
				$labeleduri = "http://$labeleduri";
				carp "fixing mds shortcomings in staff directory search...";
			}

				$labeleduri =~ s#^(.*)$#<a href=\"$labeleduri\">$1</a> #;
				print($labeleduri);
			}
		print("<br>\n");
	}

	if ($monashgoofeyhandle) {
		print("<b><small>Goofey:</small></b> ".$monashgoofeyhandle."<br>\n");
	}

	if ($eqkey) {
		print("<b><small>$eqkey:</small></b> ".$eqvalue."<br>\n");
	}
#	if ($include_schedule && $count == 1) {
#		$m->comp('/resources/yourcal.comp');
#	}
#	if ($edit){
#		print('<a href="https://mdsadmin.monash.edu.au/cgi-bin/modifymdsdetails">[edit]</a><br>');
#	}
	#print Dumper $result;
	my %result = (
		'title' => $cn,
		'link' => '', # link
		'description' => $mail,
		'relevance' => 0,
	);
	print_line($obj->serialize({ $count++ => \%result}) . "\n");
} # while

#########################################################################
# Display a prefilled search window and the search results count
#########################################################################

my $entry_txt = "entry"; if ($count != 1) {$entry_txt = "entries";}
my $entry_cnt = $count;
if ($count == 0) {$entry_cnt = "no";}
if ($count >= $limit) {$entry_cnt = "a maximum of $limit";}

#########################################################################
# Clean up
#########################################################################

$ld->unbind;
chmod(0644, $filename); # Group readable, indicating finished
my $pwd = `pwd`;
chomp $pwd;
carp "[AGENT: Completed successfully (saved to $pwd/$filename)]\n" if DEBUG;

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

sub get_image {
	return '';
}
