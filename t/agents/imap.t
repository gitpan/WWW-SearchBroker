print "1..2\n";

use WWW::SearchBroker::Common qw(AGENT_PATH STAFF_USERNAME);

print "ok 1\n";

my $pass = `cat ~/.cred`; # Text file containing your password (chmod 600)
chomp $pass;
my $ret = system(AGENT_PATH . "/imap.pl 103 portal " . STAFF_USERNAME . " " . $pass);
$ret /= 256;
print "not " if $ret;
print "ok 2\n";
