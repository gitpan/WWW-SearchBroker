print "1..4\n";

use WWW::SearchBroker::Common qw(AGENT_PATH STAFF_USERNAME parse_results remove_results);
my $magic_number = '103';

print "ok 1\n";

my $pass = `cat ~/.cred`; # Text file containing your password (chmod 600)
chomp $pass;
my $ret = system(AGENT_PATH . "/nntp.pl $magic_number portal " . STAFF_USERNAME . " " . $pass);
$ret /= 256;
print "not " if $ret;
print "ok 2\n";

print "not " unless parse_results($magic_number);
print "ok 3\n";

print "not " unless remove_results($magic_number);
print "ok 4\n";
