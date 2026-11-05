#!/bin/bash
# Revokes a user's current certificate and issues them a fresh one.
#
# The point of doing it in one script: revoke_user.sh followed by send_email.sh leaves a
# window where the user has no access, and send_email.sh skips anyone already present in
# user_passwd.csv, so it silently does nothing for an existing user. Reissuing by hand
# therefore tends to end with a revoked cert and no replacement.
#
# Use this when a laptop is lost, a cert is expiring, or a client config needs to be
# regenerated (for example to drop comp-lzo).
#
# The old certificate stops working the moment the servers reload the CRL, so tell the
# user before running this.

set -euo pipefail

if [ -e /etc/openvpn/bin/settings.sh ] && [ -z "${VPN_SETTINGS_LOADED:-}" ]; then
    source /etc/openvpn/bin/settings.sh
fi

CLEAR="\033[0m"; BOLD="\033[1m"; GREEN="\033[32m"; YELLOW="\033[33m"; RED="\033[31m"

if [ $# -lt 1 ] || [ -z "${1}" ]; then
    echo "USAGE: $0 <username> [email]"
    exit 1
fi

username="${1}"
email="${2:-${username}@uchicago.edu}"

if [ -n "${PKI_READ_ONLY:-}" ]; then
    echo -e "${RED}This stack adopted its PKI read only; a reissue here would not persist.${CLEAR}" >&2
    echo "Run this on the VPN that owns the PKI." >&2
    exit 1
fi

KEY_PATH="${KEY_PATH:-/etc/openvpn/easy-rsa/pki}"

echo -e "${BOLD}Reissuing ${username}${CLEAR}"

# Revoke first, but only if there is something to revoke. A user whose cert expired
# naturally has nothing in need of revocation.
if [ -f "${KEY_PATH}/issued/${username}.crt" ]; then
    old_serial=$(openssl x509 -in "${KEY_PATH}/issued/${username}.crt" -noout -serial | cut -d= -f2)
    echo "  revoking current certificate, serial ${old_serial}"
    (
        cd "$EASYRSA_PATH"
        EASYRSA_BATCH=1 ./easyrsa revoke "$username"
        EASYRSA_BATCH=1 ./easyrsa gen-crl
    )
    # easyrsa leaves the revoked cert in place; remove it so build-client-full will
    # issue a new one rather than refusing because the name is taken
    rm -f "${KEY_PATH}/issued/${username}.crt" "${KEY_PATH}/private/${username}.key" \
          "${KEY_PATH}/reqs/${username}.req"
    echo -e "  ${GREEN}revoked${CLEAR}"
else
    echo -e "  ${YELLOW}no current certificate, issuing fresh${CLEAR}"
fi

# Clear the old second factor so create_vpn_user.sh / reset_totp_token.sh start clean
sed -i "/^${username},/d" "${USER_PW_FILE:-/etc/openvpn/user_passwd.csv}" 2>/dev/null || true

echo "  issuing new certificate"
/etc/openvpn/bin/create_vpn_user.sh "$username" "$email"

echo "  building client bundle"
/etc/openvpn/bin/make_zips.sh "$username"

echo "  generating a new second factor"
/etc/openvpn/bin/reset_totp_token.sh "$username"

/etc/openvpn/bin/push_to_s3.sh

new_serial=$(openssl x509 -in "${KEY_PATH}/issued/${username}.crt" -noout -serial | cut -d= -f2)
echo
echo -e "${GREEN}Reissued ${username}${CLEAR}"
echo "  new serial: ${new_serial}"
echo
echo -e "${YELLOW}The old certificate is only rejected once each server reloads the CRL.${CLEAR}"
echo -e "${YELLOW}Run reload_crl.sh on every VPN using this PKI.${CLEAR}"
