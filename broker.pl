#!/usr/bin/perl -w
use lib 'lib';
use WWW::SearchBroker::Broker;

# Create a Broker
my $broker = new WWW::SearchBroker::Broker(
	timeout => 10, # wait up to 10s for responses from agents
);

# Listen for requests and response
while ($broker->event_loop())
	{ }
