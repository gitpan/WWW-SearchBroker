print "1..4\n";

use WWW::SearchBroker::Broker;

print "ok 1\n";

# Create a Broker
my $broker = new WWW::SearchBroker::Broker(
	timeout => 10, # wait up to 10s for responses from agents
);

print "not " unless $broker;
print "ok 2\n";

print "not " unless $broker->event_loop;
print "ok 3\n";

print "not " if undef $broker;
print "ok 4\n";
