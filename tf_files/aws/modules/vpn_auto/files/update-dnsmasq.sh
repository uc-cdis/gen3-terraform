#!/bin/bash
# Keeps split horizon DNS current.
#
# Some hostnames resolve to an internet facing load balancer publicly, but VPN clients
# need the internal one instead. dnsmasq answers those names from /etc/dnsmasq.hosts,
# and this script keeps that file pointing at the internal load balancer's current
# addresses. Internal ALB addresses change when the load balancer is recreated or
# scaled, so this has to be rechecked rather than written once.
#
# Previous version of this script lived only on the instance, never in git, hardcoded a
# single hostname/load balancer pair, and ran once a day from root's crontab. That meant
# a whole day of clients failing to reach the service after an address change, and
# nothing to redeploy from when the instance was replaced.
#
# Installed to the host by the vpn_auto module's userdata and run by
# update-dnsmasq.timer every five minutes. Mappings come from DNSMASQ_OVERRIDES,
# semicolon separated, baked into the service unit by terraform:
#   host=internal-lb-dns-name;other=other-lb-dns-name

set -euo pipefail

HOSTS_FILE="${DNSMASQ_HOSTS_FILE:-/etc/dnsmasq.hosts}"
OVERRIDES="${DNSMASQ_OVERRIDES:-}"

if [ -z "$OVERRIDES" ]; then
    echo "no DNSMASQ_OVERRIDES set, nothing to do"
    exit 0
fi

# Build the file we want, then compare. dnsmasq only gets reloaded if something moved,
# so the timer can run often without causing a DNS blip on every tick.
tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

resolved_any=0
failed_any=0

IFS=';' read -ra pairs <<< "$OVERRIDES"
for pair in "${pairs[@]}"; do
    [ -z "$pair" ] && continue

    hostname="${pair%%=*}"
    target="${pair#*=}"

    if [ -z "$hostname" ] || [ -z "$target" ] || [ "$hostname" = "$target" ]; then
        echo "skipping malformed mapping: ${pair}" >&2
        failed_any=1
        continue
    fi

    # A records only. An internal ALB publishes one per availability zone and
    # dnsmasq will round robin whatever we give it.
    ip_addresses=$(dig +short "$target" A | grep -E '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' || true)

    if [ -z "$ip_addresses" ]; then
        echo "could not resolve ${target} for ${hostname}" >&2
        failed_any=1
        continue
    fi

    while read -r ip; do
        [ -z "$ip" ] && continue
        echo "${ip} ${hostname}" >> "$tmp_file"
        resolved_any=1
    done <<< "$ip_addresses"
done

# Never publish an empty file. If every lookup failed, leaving the previous
# addresses in place is better than removing all of them: stale entries may still
# work, no entries definitely will not.
if [ "$resolved_any" -eq 0 ]; then
    echo "nothing resolved, leaving ${HOSTS_FILE} as it is" >&2
    exit 1
fi

sort -o "$tmp_file" "$tmp_file"

if [ -f "$HOSTS_FILE" ] && cmp -s "$tmp_file" "$HOSTS_FILE"; then
    echo "${HOSTS_FILE} already current"
    exit 0
fi

# Atomic, so dnsmasq never reads a partially written file
install -m 0644 "$tmp_file" "$HOSTS_FILE"
echo "updated ${HOSTS_FILE}:"
sed 's/^/  /' "$HOSTS_FILE"

# The old version gave up with "please start it manually" if dnsmasq was not
# running, which on a fresh instance is always. Start it instead.
if systemctl is-active --quiet dnsmasq; then
    # SIGHUP makes dnsmasq reread the hosts file in place. Sent directly rather than
    # via systemctl reload, because the unit AL2023 ships defines no ExecReload, so a
    # reload would fail and force a full restart. A restart briefly answers nothing,
    # which connected clients see as a DNS failure.
    if pkill -HUP -x dnsmasq; then
        echo "signalled dnsmasq to reread ${HOSTS_FILE}"
    else
        systemctl restart dnsmasq
        echo "restarted dnsmasq"
    fi
else
    systemctl enable --now dnsmasq
    echo "started dnsmasq"
fi

exit $failed_any
