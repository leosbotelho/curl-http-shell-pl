package Curl;

use strict;
use Exporter qw(import);
use Pre qw(Fs Us openApplyClose hasErrLike slurp_);
use Arr qw(hasArr toArr hasHash safeExists);

use constant HttpGet     => ('-X', 'GET');
use constant HttpPost    => ('-X', 'POST');
use constant HttpPut     => ('-X', 'PUT');
use constant HttpPatch   => ('-X', 'PATCH');
use constant HttpDelete  => ('-X', 'DELETE');
use constant HttpHead    => ('-X', 'HEAD');
use constant HttpOptions => ('-X', 'OPTIONS');

use constant Writeout => {
  Response => [
    'code'
  ],

  Time => [
    'nameLookup',
    'connect',
    'appConnect',
    'startTransfer',
    'total'
  ],

  Speed => [
    'download',
    'upload'
  ]
};

use constant WriteoutMin => {Response => ['code']};

use constant TransErrHttpResCode => [408, 429, 500, 502, 503, 504];

sub flattenWriteout {
  my $w = shift;
  my @i = ();
  foreach my $w0 (keys %$w) {
    my $w1 = $w->{$w0};
    push @i, map { lcfirst $w0 . '_' . lc $_; } @$w1;
  }
  \@i;
}

use constant WriteoutFlat => flattenWriteout (Writeout);
use constant WriteoutMinFlat => flattenWriteout (WriteoutMin);

our @EXPORT = qw(
  HttpGet
  HttpPost
  HttpPut
  HttpPatch
  HttpDelete
  HttpHead
  HttpOptions
  TransErrHttpResCode
  $compressed
  httpMethod
  httpHeaders
  httpBody_
  httpBody
  Writeout
  WriteoutMin
  WriteoutFlat
  WriteoutMinFlat
  flattenWriteout
  writeout
  parseWriteoutRec
  parseWriteout
  runCurl_arg
  runCurl_
  runCurl
  resCode
  hasAnyHttpResCodeOf
  has200HttpResCode
  hasTransErrHttpResCode
  hasErrLike
);

our $compressed = 0;

sub httpMethod { ('-X', shift) }

sub httpHeaders {
  my $headers = shift;
  my @headersOpt = ();
  foreach my $k (keys %$headers) {
    my $v = $headers->{$k};
    push @headersOpt, ('-H', "$k: $v");
  }
  @headersOpt;
}

sub httpBody_ {
  my ($optName0, $body) = @_;
  $optName0 = '-d' unless $optName0;
  my @bodyOpt = ();
  if (hasHash $body) {
    foreach my $k (keys %$body) {
      my $v = $body->{$k};
      my $optName = $optName0;
      if (hasArr $v) {
        $optName = $v->[0];
        $v = $v->[1];
      }
      push @bodyOpt, ($optName, "$k=$v");
    }
  } else {
    @bodyOpt = ($optName0, $body);
  }
  @bodyOpt;
}
sub httpBody { httpBody_ '', @_; }

sub writeout {
  my ($w, $fs, $us) = @_;
  return () unless @$w;
  $fs = $fs // Fs;
  $us = $us // Us;
  ('-w', $fs . (join $us, map { "%{$_}" } @$w));
}

sub parseWriteoutRec {
  my ($s, $w, $us) = @_;
  $us = $us // Us;

  my @v = split $us, $s;
  return {this => 'parseWriteoutRec'} unless @v == @$w;

  return {that => do {
    my %w = ();
    @w{@$w} = @v;
    $w{response_code} += 0 if exists $w{response_code};
    \%w;
  }};
}

sub parseWriteout {
  my ($s, $w, $fs, $us) = @_;
  $fs = $fs // Fs;

  my $j = rindex $s, $fs;
  return {this => 'parseWriteout'} if $j == -1;

  my $w = parseWriteoutRec substr ($s, $j + 1), $w, $us;
  return $w if exists $w->{this};

  return {that => [substr ($s, 0, $j), $w->{that}]};
}

'
w, o, i, I, D

headers : i or I
body    : !I

  stdout : and !o

';
sub outProfile {
  my $p = '';
  my $h = sub { index ($p, $_[0]) == -1; };

  foreach my $s (@{$_[0]}) {
    $p .= 'w' if $h->('w') and ($s eq '-w' or $s eq '--write-out'   );
    $p .= 'o' if $h->('o') and ($s eq '-o' or $s eq '--output'      );
    $p .= 'i' if $h->('i') and ($s eq '-i' or $s eq '--include'     );
    $p .= 'I' if $h->('I') and ($s eq '-I' or $s eq '--head'        );
    $p .= 'D' if $h->('D') and ($s eq '-D' or $s eq '--dump-header' );
  }
  $p;
}

sub runCurl_arg {
  my ($opt0, $warg, $outp, $f,
      $parseWriteout, $parseHttpResponse) = @_;

  $opt0 = toArr $opt0;

  if (defined $warg) {
    $warg = [$warg] if @$warg and !hasArr $warg->[0];
  } else {
    $warg = [WriteoutMinFlat];
  }

  $outp = outProfile $opt0 unless defined $outp;

  my $opt = [@$opt0];

  if (@$warg) {
    push @$opt, writeout ($warg->[0]);
    $outp .= 'w';
  }

  push @$opt, '--compressed' if $compressed;

  $f = \&slurp_ unless $f;

  $parseWriteout = $parseWriteout // 1;
  $parseHttpResponse = $parseHttpResponse // 1;

  ($opt, $warg, $outp, $f,
   $parseWriteout, $parseHttpResponse);
}

sub runCurl_ {
  my ($opt, $f) = @_;
  openApplyClose $f, '-|', 'curl', '-s', @$opt;
}

sub runCurl {
  my ($opt, $warg, $outp, $f);
  my ($parseWriteout, $parseHttpResponse);

  my @arg;

  if (hasHash $_[0]) {
    @arg =
      @{$_[0]}{
        'opt', 'warg', 'outp', 'f',
        'parseWriteout', 'parseHttpResponse'
      };
  } else {
    @arg = @_;
  }

  ($opt, $warg, $outp, $f,
   $parseWriteout, $parseHttpResponse) = runCurl_arg @arg;

  my $a = runCurl_ $opt, $f;

  return $a unless $parseWriteout or $parseHttpResponse;

=notice
exists $a->{this} is allowed - under this cond
=cut
  if (exists $a->{that} and exists $a->{exitcode} and $a->{exitcode} != 23) {
    if ($parseWriteout and index ($outp, 'w') != -1) {
      my $w = parseWriteout $a->{that}, @$warg;
      if (exists $w->{this}) {
        $a->{this}{$w->{this}} = '';

        return $a;
      } else {
        $a->{that} = $w->{that}[0];
        $a->{writeout} = $w->{that}[1];
      }
    }

    if ($parseHttpResponse and index ($outp, 'o') == -1) {
      my $hasBody = index ($outp, 'I') == -1;
      if (index ($outp, 'i') != -1 or index ($outp, 'I') != -1) {
        my $d = "\r\n" x 2;
        my @u = split $d, $a->{that}, 2;
        if (@u != 2) {
          $a->{this}{parseHttpResponse} = '';

          return $a;
        }
        $a->{that} = {headersRaw => $u[0] . $d};
        $a->{that}{body} = $u[1] if $hasBody;
      } elsif ($hasBody) {
        $a->{that} = {body => $a->{that}};
      }
    }
  }

  $a;
}

sub resCode {
  my $y = shift;
  safeExists ($y, qw(writeout response_code)) ?
    $y->{writeout}{response_code} : 0;
}

sub hasAnyHttpResCodeOf {
  my ($xs, $y) = @_;
  my $c = resCode $y;
  return 0 if !$c;
  foreach my $x (@$xs) {
    return 1 if $c == $x;
  }
  0;
}

sub has200HttpResCode {
  resCode ($_[0]) == 200;
}

sub hasTransErrHttpResCode {
  hasAnyHttpResCodeOf TransErrHttpResCode, $_[0];
}

sub hasErrLike {
  Pre::hasErrLike $_[0] or !(has200HttpResCode $_[0]);
}

1;
