#!/bin/bash
#   Copyright 2015 CDIS
#   Author: Ray Powell rpowell1@uchicago.edu
#
# Reports the state of every VPN user: active, expiring_soon, expired, revoked or
# disabled, plus whether they still hold a second factor.
#
# Rewritten because the previous version did not work on this platform:
#   - called revoke-full, an easy-rsa 2 script absent from easy-rsa 3, which under
#     "set -e" aborted before printing anything
#   - used tempfile(1), a Debian utility not present here
#   - used date -d, which is GNU only
#   - looked for certs at pki/<user>.crt; easy-rsa 3 puts them in pki/issued/
#   - drove the user list from user_passwd.csv, so anyone holding a valid certificate
#     but no second factor was invisible, which is exactly the state worth spotting
#
# Now it reads the issued certificates and the CRL as the source of truth, and reports
# the second factor separately.

CLEAR="\033[0m"
BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"

if [ -e /etc/openvpn/bin/settings.sh ] && [ -z "${VPN_SETTINGS_LOADED:-}" ]; then
    source /etc/openvpn/bin/settings.sh
fi

set -uo pipefail

cmd="${1:-all}"
case "$cmd" in
    all|active|expiring_soon|expired|revoked|disabled|no_second_factor) ;;
    *)
        echo "USAGE: $0 [all|active|expiring_soon|expired|revoked|disabled|no_second_factor]"
        exit 1
        ;;
esac

KEY_PATH="${KEY_PATH:-/etc/openvpn/easy-rsa/pki}"
ISSUED="${KEY_PATH}/issued"
CRL="${KEY_PATH}/crl.pem"
USER_PW_FILE="${USER_PW_FILE:-/etc/openvpn/user_passwd.csv}"

[ -d "$ISSUED" ] || { echo "no issued certificates at ${ISSUED}" >&2; exit 1; }

# Revoked serials, read straight from the CRL
revoked_serials=""
if [ -f "$CRL" ]; then
    revoked_serials=$(openssl crl -in "$CRL" -text -noout 2>/dev/null \
        | awk '/Serial Number:/ {print toupper($3)}')
    crl_next=$(openssl crl -in "$CRL" -noout -nextupdate 2>/dev/null | cut -d= -f2)
else
    echo "WARNING: no CRL at ${CRL}, revocation state is unknown" >&2
fi

now=$(date -u +%s)
cutoff=$(( now + 86400 * 30 ))

# BSD date on macOS and GNU date on Linux parse openssl's format differently, so try
# both rather than assuming the platform
to_epoch() {
    date -u -d "$1" +%s 2>/dev/null || date -u -j -f "%b %e %T %Y %Z" "$1" +%s 2>/dev/null || echo 0
}

printf "%-24s %-32s %-14s %s\n" "USER" "EMAIL" "STATUS" "2FA"

for crt in "$ISSUED"/*.crt; do
    [ -e "$crt" ] || continue
    user=$(basename "$crt" .crt)

    # Skip the server's own certificate, it is not a user. Matched on the EKU rather
    # than on CLOUD_NAME, because that variable is not always exported into the shell
    # this runs in (eg under docker exec) and the name then leaks into the report as an
    # active user with no second factor.
    if openssl x509 -in "$crt" -noout -ext extendedKeyUsage 2>/dev/null | grep -q "TLS Web Server Authentication"; then
        continue
    fi

    serial=$(openssl x509 -in "$crt" -noout -serial 2>/dev/null | cut -d= -f2 | tr 'a-f' 'A-F')
    email=$(openssl x509 -in "$crt" -noout -subject 2>/dev/null \
        | grep -oE "emailAddress=[^,/]+" | cut -d= -f2)
    email="${email:-none}"

    if [ -n "$revoked_serials" ] && echo "$revoked_serials" | grep -qx "$serial"; then
        status="revoked"
    elif [ -f "/etc/openvpn/clients.d/${user}" ] && grep -q disable "/etc/openvpn/clients.d/${user}" 2>/dev/null; then
        status="disabled"
    else
        notafter=$(openssl x509 -in "$crt" -noout -enddate 2>/dev/null | cut -d= -f2)
        exp=$(to_epoch "$notafter")
        if [ "$exp" -eq 0 ]; then
            status="unknown_expiry"
        elif [ "$exp" -le "$now" ]; then
            status="expired"
        elif [ "$exp" -le "$cutoff" ]; then
            status="expiring_soon"
        else
            status="active"
        fi
    fi

    # A valid cert with no second factor is single factor access, worth surfacing
    if grep -qE "^${user}," "$USER_PW_FILE" 2>/dev/null; then
        twofa="yes"
    else
        twofa="NO"
        [ "$status" = "active" ] && status_note="no_second_factor" || status_note=""
    fi

    if [ "$cmd" = "no_second_factor" ]; then
        [ "$twofa" = "NO" ] && [ "$status" = "active" ] || continue
    elif [ "$cmd" != "all" ] && [ "$status" != "$cmd" ]; then
        continue
    fi

    colour=""
    case "$status" in
        active) colour="$GREEN" ;;
        expiring_soon) colour="$YELLOW" ;;
        expired|revoked) colour="$RED" ;;
    esac
    [ "$twofa" = "NO" ] && [ "$status" = "active" ] && colour="$YELLOW"

    printf "%-24s %-32s ${colour}%-14s${CLEAR} %s\n" "$user" "$email" "$status" "$twofa"
done

if [ "$cmd" = "all" ] && [ -n "${crl_next:-}" ]; then
    echo
    echo "CRL valid until ${crl_next} ($(echo "$revoked_serials" | grep -c . ) revoked)"
    echo "Note: a server only honours revocations after its CRL is reloaded (reload_crl.sh)."
fi
