use 5.010;
use strict;
use warnings;
use utf8;

package Neo4j::Driver::Net::HTTP::REST;
# ABSTRACT: HTTP agent adapter for REST::Client


use Carp qw(croak);
our @CARP_NOT = qw(Neo4j::Driver::Net::HTTP);
use Scalar::Util qw(blessed);

use JSON::MaybeXS 1.003003 qw();
use REST::Client 134;


our $JSON_CODER;
BEGIN { $JSON_CODER = sub {
	return JSON::MaybeXS->new(utf8 => 1, allow_nonref => 0);
}}

my $CONTENT_TYPE = 'application/json';


# Initialise the object. May or may not establish a network connection.
# May access driver config options using the config() method only.
sub new {
	my ($class, $driver) = @_;
	
	my $self = bless {
		json_coder => $JSON_CODER->(),
	}, $class;
	
	my $uri = $driver->config('uri');
	if (my $auth = $driver->config('auth')) {
		croak "Only HTTP Basic Authentication is supported" if $auth->{scheme} ne 'basic';
		$uri = $uri->clone;
		$uri->userinfo( $auth->{principal} . ':' . $auth->{credentials} );
	}
	
	my $client = REST::Client->new({
		host => "$uri",
		timeout => $driver->config('timeout'),
		follow => 1,
	});
	if ($uri->scheme eq 'https') {
		$client->setCa( my $trust_ca = $driver->config('trust_ca') );
		croak "TLS CA file '$trust_ca' doesn't exist (or is not a plain file)" if defined $trust_ca && ! -f $trust_ca;  # REST::Client 273 doesn't support symbolic links
		my $unencrypted = defined $driver->config('encrypted') && ! $driver->config('encrypted');
		croak "HTTPS does not support unencrypted communication; use HTTP" if $unencrypted;
	}
	else {
		croak "HTTP does not support encrypted communication; use HTTPS" if $driver->config('encrypted');
	}
	$client->addHeader('Content-Type', $CONTENT_TYPE);
	$client->addHeader('X-Stream', 'true');
	$self->{client} = $client;
	
	$driver->{client_factory}->($self) if $driver->{client_factory};  # used for testing
	
	return $self;
}


# Return a list of result handler modules to be used to parse
# Neo4j statement results delivered through this module.
# The module names returned will be used in preference to the
# result handlers built into the driver.
sub result_handlers {
}


# Return a JSON:XS-compatible coder object (for result parsers).
# The coder object must offer the methods encode() and decode().
# For boolean handling, encode() must accept the values \1 and \0
# and decode() should produce JSON::PP::true and JSON::PP::false.
sub json_coder {
	my ($self) = @_;
	return $self->{json_coder};
}


# Return server base URL as string or URI object (for ServerInfo).
# At least scheme, host, and port must be included.
sub uri {
	my ($self) = @_;
	return $self->{client}->getHost();
}


# Return the HTTP version (e. g. "HTTP/1.1") from the last response,
# or just "HTTP" if the version can't be determined.
# May block until the response headers have been fully received.
sub protocol {
	my ($self) = @_;
	
	if ( blessed $self->{client}->{_res} && $self->{client}->{_res}->can('protocol') ) {
		return $self->{client}->{_res}->protocol;
	}
	else {
		return 'HTTP';
	}
}


# Return the HTTP Date header from the last response.
# If the server doesn't have a clock, the header will be missing;
# in this case, the value returned must be either the empty string or
# (optionally) the current time in non-obsolete RFC5322:3.3 format.
# May block until the response headers have been fully received.
sub date_header {
	my ($self) = @_;
	return $self->{client}->responseHeader('Date') // '';
}


# Return the HTTP reason phrase (eg "Not Found").
# If unavailable, the empty string is returned instead.
# May block until the response headers have been fully received.
sub http_reason {
	my ($self) = @_;
	my $client = $self->{client};
	return '' unless blessed $client->{_res} && $client->{_res}->can('message');
	return $client->{_res}->message;
}


# Return a hashref with the following entries, representing
# headers and status of the last response:
# - content_type  (eg "application/json")
# - location      (URI reference)
# - status        (eg "404")
# - success       (truthy for 2xx status)
# All of these must exist and be defined scalars.
# Unavailable values must use the empty string.
# Blocks until the response headers have been fully received.
sub http_header {
	my ($self) = @_;
	my $client = $self->{client};
	my $headers = {};
	$headers->{content_type} = $client->responseHeader('Content-Type') // '';
	$headers->{location} = $client->responseHeader('Location') // '';
	$headers->{status} = $client->responseCode() // '';
	$headers->{success} = $headers->{status} =~ m/^2[0-9][0-9]$/;
	return $headers;
}


# Return the next Jolt event from the response to the last network
# request. When there are no further Jolt events, this method
# returns an undefined value. If the response hasn't been fully
# received at the time this method is called and the internal
# response buffer does not contain at least one event, this method
# will block until at least one event is available. The result of
# calling this method is undefined if the response is not in Jolt
# format or if fetch_all() has already been called for the same
# request.
sub fetch_event {
	my ($self) = @_;
	
	# Note: Parsers that are conformant to RFC 7464 (json-seq) cannot
	# parse Jolt because Neo4j 4.2 uses LF instead of RS as separator.
	# We try to support both Neo4j and the spec by removing any RS.
	if ( ! defined $self->{buffer} ) {
		my $response = $self->fetch_all;
		$response =~ tr/\x1e//d;
		$self->{buffer} = [split m/\n/, $response];
	}
	return shift @{$self->{buffer}};
}


# Block until the response to the last network request has been fully
# received, then return the entire content of the response buffer.
# This method is idempotent, but the result of calling this method
# after fetch_event() has already been called for the same request
# is undefined.
sub fetch_all {
	my ($self) = @_;
	
	return $self->{client}->responseContent();
}


# Start an HTTP request on the network and keep a reference to that
# request. May or may not block until the response has been received.
sub request {
	my ($self, $method, $url, $json, $accept) = @_;
	
	$self->{buffer} = undef;
	
	# The ordering of the $json hash's keys is significant: Neo4j
	# requires 'statements' to be the first member in the JSON object.
	# Luckily, in recent versions of Neo4j, it is also the only member.
	
	$json = $self->{json_coder}->encode($json) if $json;
	$self->{client}->request( $method, "$url", $json, {Accept => $accept} );
}


1;

__END__

=head1 DESCRIPTION

The L<Neo4j::Driver::Net::HTTP::REST> package is not part of the
public L<Neo4j::Driver> API.

=cut
