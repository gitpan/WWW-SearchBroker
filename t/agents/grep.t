print "1..2\n";

use WWW::SearchBroker::Common qw(STAFF_USERNAME AGENT_PATH);

print "ok 1\n";

my $ret = system(AGENT_PATH . "/grep.pl 103 'ok *.t'");
$ret /= 256;
print "not " if $ret;
print "ok 2\n";
