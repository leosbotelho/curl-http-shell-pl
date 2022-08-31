> Could - a part of - http comms be viably built on top of `curl` cli?

Maybe; this sketch is a poke at it.

_And perhaps next-gen [`--libcurl`](https://curl.se/docs/manpage.html#--libcurl) or [Platypus](https://metacpan.org/pod/FFI::Platypus) `libcurl`, for what needs to go beyond it._

<br>

eg:
```
use Curl qw(HttpPost HttpPut runCurl httpHeaders httpBody);
use Curl::Json qw(runCurlJson httpBody);

my @headersOpt0 = httpHeaders {'User-Agent' => ''};
my @headersOpt1 = httpHeaders {'Content-Type' => 'application/json'};

my @bodyOpt = Curl::httpBody {foo => 'bar'};

runCurl [HttpPost, 'https://httpbin.org/post',
    @headersOpt0, @bodyOpt];

my $jsonBodyOpt = (Curl::Json::httpBody {fee => 'foe'})->{that};

runCurlJson [HttpPut, 'https://httpbin.org/put',
  @headersOpt0, @headersOpt1, @$jsonBodyOpt];
```
