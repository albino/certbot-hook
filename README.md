# deSEC certbot hook modified to work on a domain's zone apex

**You only want to use this if you have set your DNS up such that the ACME token should be created in the zone apex** - for example, as described in [this blog post](https://lgsb2.user.srcf.net/blog/dns-01_cname/).

The original source code can be found [here](https://github.com/desec-utils/certbot-hook).

The original README file can be found in `README.orig`.

## Caveats

This script assumes the zone will be empty when it starts, and empties the zone again when it's finished. Even if this causes it to fail occasionally, it is _probably_ fine, just something to consider.
