print "1..11\n";

use WWW::SearchBroker::Broker;

print "ok 1\n";

print "ok 2\n";
## Create a Broker
#my $broker = new WWW::SearchBroker::Broker(
#	timeout => 10, # wait up to 10s for responses from agents
#);
#
#print "not " unless $broker;
#print "ok 2\n";
#
#my $ret = $broker->fork_and_loop();
if (my $ret = fork()) {
	exec("../broker.pl");
}
sleep(2);

print "ok 3\n";

use WWW::SearchBroker::Search;

print "ok 4\n";

# Port the broker server is running on
my $port = 9000;

# Search query
my $srch = 'SEARCH<15><a,b,c><foo bar>';

# Create a search requestor
my $search = new WWW::SearchBroker::Search(port => $port);

print "not " unless $search;
print "ok 5\n";

print "not " unless $search->send_query('SEARCH','perl *pl','grep','grep','grep');
print "ok 6\n";

print "not " unless $search->dump_results();
print "ok 7\n";

# List available agents
my $search = new WWW::SearchBroker::Search(port => $port);
print "not " unless $search->send_query('LIST','','');
print "ok 8\n";

print "not " unless $search->dump_results();
print "ok 9\n";

# Quit broker
my $search = new WWW::SearchBroker::Search(port => $port);
print "not " unless $search->send_query('QUIT','','');
print "ok 10\n";

print "not " unless $search->dump_results();
print "ok 11\n";
