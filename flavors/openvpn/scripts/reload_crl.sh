#!/bin/bash
# Pulls the current CRL from S3 and makes the running server honour it.
#
# Why this exists: openvpn reads crl-verify when a client connects, but it caches the
# file. A revocation performed on one server, or a CRL regenerated on another, does not
# take effect here until the file on disk is refreshed. Without this step a revoked
# user keeps connecting to any server that has not restarted, which looks like the
# revocation silently failed.
#
# Safe to run on a cron or timer. It only restarts openvpn when the CRL actually
# changed, so already-connected users are not disturbed for nothing.

set -euo pipefail

if [ -e /etc/openvpn/bin/settings.sh ] && [ -z "${VPN_SETTINGS_LOADED:-}" ]; then
    source /etc/openvpn/bin/settings.sh
fi

CRL_PATH="${KEY_PATH:-/etc/openvpn/easy-rsa/pki}/crl.pem"
: "${S3_PREFIX:?S3_PREFIX is not set, run this inside the openvpn container}"

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

if ! aws s3 cp "s3://${S3_PREFIX}/easy-rsa/crl.pem" "$tmp" >/dev/null 2>&1; then
    # Older layouts keep it under pki/
    if ! aws s3 cp "s3://${S3_PREFIX}/easy-rsa/pki/crl.pem" "$tmp" >/dev/null 2>&1; then
        echo "could not fetch the CRL from s3://${S3_PREFIX}" >&2
        exit 1
    fi
fi

# A malformed or expired CRL is worse than a stale one: openvpn refuses every client
# when crl-verify points at a CRL it cannot parse or that has passed nextUpdate.
if ! openssl crl -in "$tmp" -noout >/dev/null 2>&1; then
    echo "fetched CRL does not parse, keeping the existing one" >&2
    exit 1
fi

next=$(openssl crl -in "$tmp" -noout -nextupdate 2>/dev/null | cut -d= -f2)
if [ -n "$next" ]; then
    if [ "$(date -u +%s)" -ge "$(date -u -d "$next" +%s 2>/dev/null || echo 0)" ]; then
        echo "fetched CRL expired at ${next}, refusing to install it" >&2
        echo "openvpn would reject every client. Regenerate it with: easyrsa gen-crl" >&2
        exit 1
    fi
fi

if [ -f "$CRL_PATH" ] && cmp -s "$tmp" "$CRL_PATH"; then
    echo "CRL already current ($(openssl crl -in "$CRL_PATH" -text -noout | grep -c 'Serial Number:') revoked)"
    exit 0
fi

install -m 0644 "$tmp" "$CRL_PATH"
count=$(openssl crl -in "$CRL_PATH" -text -noout | grep -c 'Serial Number:')
echo "installed updated CRL, ${count} revoked certificates, valid until ${next}"

# openvpn rereads crl-verify on SIGHUP, which also drops current sessions. That is the
# point when revoking: a revoked user holding an open tunnel should be disconnected.
if pgrep -x openvpn >/dev/null 2>&1; then
    pkill -HUP -x openvpn
    echo "signalled openvpn to reload; connected clients will reconnect"
else
    echo "openvpn is not running here, nothing to signal" >&2
fi
