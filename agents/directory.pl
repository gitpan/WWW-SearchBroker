#!/usr/bin/env perl
# Typically run from broker.pl as:
#	agents/$agent.pl $sid "$query" 'username' 'password'
# sid -- search id
# query -- search query
# username -- MDS username
# password -- MDS password (what about passwords with quotes in them?)
use strict;
use Net::LDAP;
use Data::Dumper;
use Data::Serializer;
use Carp;
use WWW::SearchBroker::Common qw(DEBUG DEBUG_LOW DEBUG_MEDIUM DEBUG_HIGH TEMP_FILE_PATH LDAP_SERVER print_line);
use List::Misc qw(first_value all_values);

if (scalar @ARGV != 2 and scalar @ARGV != 4) {
	warn scalar @ARGV . " arguments presented, two or four required:";
	warn "Usage: $0 103 search_query [username password]\n";
	exit;
}
my ($sid,$query,$user,$pass) = @ARGV;
umask(0067); # Initial file perms are 600, indicating not yet finished
my $filename = TEMP_FILE_PATH . "$sid.txt";
my $obj = Data::Serializer->new();

#########################################################################
my $include_schedule = undef;
my $limit = 20;   # maximum number of items returned
my $count;

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
# Search for NAME (cn) or other field
#########################################################################

my ($mesg, $mesgcn, $entry, $filter);
my  $eqkey = ""; my  $eqvalue = "";

if ($query =~ /=/) {
	$filter = "(&(|($query))(objectclass=monashPerson)(|(!(monashpendingdelete=*))(monashgraceperiod=1)))";       # enter a filter key directly
	($eqkey, $eqvalue) = split /=/, $query;
	carp "[AGENT: eqkey=$eqkey]\n" if DEBUG >= DEBUG_MEDIUM;
} else {
	$query = "*$query*"; $query =~ s/ +/*/g;
	$query =~ s/\*\*+/*/g;
	$query =~ s/\*//g if length($query)<3;
	#####################################################################
	# Staff are in two subtrees -- Monash payrolled staff are 'ou=Staff'
	# and associated organizations are 'ou=Associated Organizations'.
	$filter = "(&(|(cn=$query)(ou=$query)(title=$query))(|(ou=Staff)(ou=Associated Organizations))(objectclass=monashPerson)(|(!(monashpendingdelete=*))(monashgraceperiod=1)))";
}

carp "[AGENT: filter=$filter]\n" if DEBUG >= DEBUG_MEDIUM;

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

# Generate the formatted entry
	my $description = '';
	foreach $mail (@mail) {
		if (my $image = get_image($mail)) {
			$description .= (qq(<img src="$image"><br>));
		}
	}

	$description .= ("$title<br>\n")  if $title;
	$description .= ("$ou<br>\n")  if $ou;
	$description .= ("<b><small>Voice:</small></b> $telephonenumber<br>\n")
	      if $telephonenumber;
	$description .= ("<b><small>FAX:</small></b> $facsimiletelephonenumber<br>\n")
	      if $facsimiletelephonenumber;
	$description .= ("<b><small>Location:</small></b> $location<br>\n")
	      if $location;
	if (@mail) {
		$description .= ("<b><small>Email:</small></b>\n");
		foreach $mail (@mail) {
#		 $mail =~ s/(.*)/<a href=\"mailto:$1\">$1<\/a> /;
			$mail =~ s#^(.*)$#<a href=\"/email/sendmail.html?to=$1\">$1</a> #;
			$description .= ($mail);
			}
		$description .= ("<br>\n");
	}

	if (@labeleduri) {
		$description .= ("<b><small>Web:</small></b>\n");
		foreach $labeleduri (@labeleduri) {
			unless ($labeleduri =~ /^http/) {
				$labeleduri = "http://$labeleduri";
			}

				$labeleduri =~ s#^(.*)$#<a href=\"$labeleduri\">$1</a> #;
				$description .= ($labeleduri);
			}
		$description .= ("<br>\n");
	}

	if ($monashgoofeyhandle) {
		$description .= ("<b><small>Goofey:</small></b> ".$monashgoofeyhandle."<br>\n");
	}

	if ($eqkey) {
		$description .= ("<b><small>$eqkey:</small></b> ".$eqvalue."<br>\n");
	}
#	if ($include_schedule && $count == 1) {
#		$m->comp('/resources/yourcal.comp');
#	}
#	if ($edit){
#		$description .= ('<a href="https://mdsadmin.monash.edu.au/cgi-bin/modifymdsdetails">[edit]</a><br>');
#	}
	#print Dumper $result;
	my %result = (
		'title' => "$personaltitle $cn",
		'link' => '', # link
		'description' => $description,
		'relevance' => 0,
	);
	print_line($filename,$obj->serialize({ $count++ => \%result}) . "\n");
} # while

#########################################################################
$ld->unbind;
chmod(0644, $filename); # Group readable, indicating finished
carp "[AGENT: Completed successfully (saved to $filename)]\n" if DEBUG;

sub get_image() {
	return '';
}
