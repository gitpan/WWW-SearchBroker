print "1..2\n";

use WWW::SearchBroker::Common qw(AGENT_PATH);

print "ok 1\n";

my $ret = system(AGENT_PATH . "/monash_web.pl 103 'john smith'");
$ret /= 256;
print "not " if $ret;
print "ok 2\n";
