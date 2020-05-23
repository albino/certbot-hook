#!/usr/bin/env bash

# This script does not need to be changed for certbots DNS challenge.
# Please see the .dedynauth file for authentication information.

(

shopt -s extglob

[[ ! $CERTBOT_AUTH_OUTPUT =~ "$CERTBOT_VALIDATION" ]] && CERTBOT_AUTH_OUTPUT=''

DEDYNAUTH=$(pwd)/.dedynauth

if [ ! -f "$DEDYNAUTH" ]; then
    >&2 echo "File $DEDYNAUTH not found. Please place .dedynauth file in appropriate location."
    exit 1
fi

source "$DEDYNAUTH"

if [ -z "$DEDYN_TOKEN" ]; then
    >&2 echo "Variable \$DEDYN_TOKEN not found. Please set DEDYN_TOKEN=(your dedyn.io token) to your dedyn.io access token in $DEDYNAUTH, e.g."
    >&2 echo ""
    >&2 echo "DEDYN_TOKEN=d41d8cd98f00b204e9800998ecf8427e"
    exit 2
fi

if [ -z "$DEDYN_NAME" ]; then
    >&2 echo "Variable \$DEDYN_NAME not found. Please set DEDYN_NAME=(your dedyn.io name) to your dedyn.io name in $DEDYNAUTH, e.g."
    >&2 echo ""
    >&2 echo "DEDYN_NAME=foobar.dedyn.io"
    exit 3
fi

if [ -z "$CERTBOT_DOMAIN" ]; then
    [ -n "$CERTBOT_AUTH_OUTPUT" ] \
    && >&2 echo "It appears that you are not running this script through certbot (\$CERTBOT_DOMAIN is unset). Please call with: certbot --manual-cleanup-hook=$0" \
    || >&2 echo "It appears that you are not running this script through certbot (\$CERTBOT_DOMAIN is unset). Please call with: certbot --manual-auth-hook=$0"
    exit 4
fi

if [ ! "$(type -P curl)" ]; then
    >&2 echo "Please install curl to use certbot with dedyn.io."
    exit 5
fi

[ -n "$CERTBOT_AUTH_OUTPUT" ] \
&& echo "Deleting challenge ${CERTBOT_VALIDATION} ..." \
|| echo "Setting challenge to ${CERTBOT_VALIDATION} ..."

# Figure out subdomain infix by removing zone name and trailing dot
# foobar.dedyn.io gives "" while a.foobar.dedyn.io gives ".a"
domain=.$CERTBOT_DOMAIN
infix=${domain%.$DEDYN_NAME}

# Remove leading wildcard from infix, if present
# *.foobar.dedyn.io gives "" while *.a.foobar.dedyn.io gives ".a"
infix=${infix#.\*}

args=( \
    '-sSLf' \
    '-H' "Authorization: Token $DEDYN_TOKEN" \
    '-H' 'Accept: application/json' \
    '-H' 'Content-Type: application/json' \
)

# Find minimum_ttl for the domain and use that instead of hardcoding a ttl.
# This allows use on non-dynamic (dedyn.io) domains.
minimum_ttl=$(curl "${args[@]}" -X GET "https://desec.io/api/v1/domains/$DEDYN_NAME/" | tr -d '\n' | grep -o '"minimum_ttl"[[:space:]]*:[[:space:]]*[[:digit:]]*' | grep -o '[[:digit:]]*')

# If the current rrset is empty, we simply publish the new challenge. If
# the current rrset contains records and we have a new challenge, we append
# the new challenge to the current rrset. If for some reason the new
# challenge is already in the rrset, we re-publish the current rrset as-is.
if [ -z "$acme_records" ]; then
	acme_records='"\"'"$CERTBOT_VALIDATION"'\""'
elif [[ ! $acme_records =~ "$CERTBOT_VALIDATION" ]]; then
	acme_records+=',"\"'"$CERTBOT_VALIDATION"'\""'
fi

# set ACME challenge (overwrite if possible, create otherwise)
if [ -n "$CERTBOT_AUTH_OUTPUT" ]; then
	# Delete everything
	curl "${args[@]}" -X PUT -o /dev/null "https://desec.io/api/v1/domains/$DEDYN_NAME/rrsets/@/TXT/" \
	    '-d' '{"type":"TXT", "records":[], "ttl":'"$minimum_ttl"'}'

else
	# Create
	curl "${args[@]}" -X POST -o /dev/null "https://desec.io/api/v1/domains/$DEDYN_NAME/rrsets/" \
	    '-d' '{"type":"TXT", "records":['"$acme_records"'], "ttl":'"$minimum_ttl"'}'
fi

[ -n "$CERTBOT_AUTH_OUTPUT" ] \
|| (echo "Waiting 120s for changes be published."; date; sleep 120)

[ -n "$CERTBOT_AUTH_OUTPUT" ] \
&& echo -e '\e[32mToken deleted. Returning to certbot.\e[0m' \
|| echo -e '\e[32mToken published. Returning to certbot.\e[0m'

)
