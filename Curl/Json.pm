package Curl::Json;

use strict;
use Exporter qw(import);
use Arr qw(hasHash safeExists);
use Curl qw(runCurl hasErrLike);
use Json qw(encodeJson decodeJson);

our @EXPORT = qw(
  viewJson_
  resJson_
  resJson
  runCurlJsonHi
  runCurlJson_
  runCurlJson
  httpBody_
  httpBody
);

sub viewJson_ {
  if (safeExists $_[0], qw(that json)) {
    return $_[0]->{that}{json};
  }
  return;
}

sub resJson_ {
  my $a = shift;
  if (safeExists $a, qw(that body)) {
    return decodeJson $a->{that}{body};
  }
  return;
}

sub resJson {
  my $a = shift;
  Curl::hasErrLike ($a) ? undef : resJson_ $a;
}

sub runCurlJsonHi {
  my $p = shift;
  my $a = runCurl @_;
  unless ($p->($a)) {
    my $json = resJson_ $a;
    if (defined $json) {
      if (exists $json->{this}) {
        $a->{this}{decodeJson} = $json->{this};
      } else {
        $a->{that}{json} = $json->{that};
      }
    }
  }
  $a;
}

sub runCurlJson_ {
  runCurlJsonHi (sub { 0; }, @_);
}

sub runCurlJson {
  runCurlJsonHi (\&Curl::hasErrLike, @_);
}

sub httpBody_ {
  my ($optName0, $body) = @_;
  my $bodyOpt;
  if (hasHash $body) {
    $bodyOpt = encodeJson $body;
    if (exists $bodyOpt->{this}) {
      return {this => $bodyOpt->{this}};
    }
  } else {
    $bodyOpt = {that => $body};
  }
  return {that => [$optName0 ? $optName0 : '-d', $bodyOpt->{that}]};
}
sub httpBody { httpBody_ '', @_; }

1;
