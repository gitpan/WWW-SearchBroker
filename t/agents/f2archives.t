print "1..4\n";

use WWW::SearchBroker::Common qw(AGENT_PATH parse_results remove_results);
my $magic_number = '103';

print "ok 1\n";

my $ret = system(AGENT_PATH . "/f2archives.pl $magic_number 'portal'");
$ret /= 256;
print "not " if $ret;
print "ok 2\n";

print "not " unless parse_results($magic_number);
print "ok 3\n";

print "not " unless remove_results($magic_number);
print "ok 4\n";
