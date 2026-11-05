#!/bin/bash
#   Copyright 2017 CDIS
#   Author: Ray Powell rpowell1@uchicago.edu
#
# Revokes a user's certificate and removes their second factor.
#
# Both halves matter. Revoking the cert alone leaves the TOTP entry behind, and removing
# the TOTP entry alone leaves a cert that still validates, so either on its own is an
# incomplete revocation.
#
# After this runs the CRL is regenerated and pushed to S3. Every server using this PKI
# needs to reload it before the revocation takes effect there, which is what
# reload_crl.sh does.

CLEAR="\033[0m"
BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"

echo -e "Entering ${BOLD}$_${CLEAR}"

if [ -e /etc/openvpn/bin/settings.sh ] && [ -z "$VPN_SETTINGS_LOADED" ]
then
    source /etc/openvpn/bin/settings.sh
fi

set -u
set -e

if [ $# -lt 1 ] || [ -z "${1}" ]; then
    echo "USAGE: $0 <username>"
    exit 1
fi

username="${1}"

# Refuse to run against a PKI we only have read access to. Otherwise easyrsa rewrites
# index.txt and crl.pem locally, the push to S3 is skipped, and the revocation quietly
# disappears when the instance is replaced.
if [ -n "${PKI_READ_ONLY:-}" ]; then
    echo -e "${RED}This stack adopted its PKI read only, so a revocation here would not persist.${CLEAR}" >&2
    echo "Run this on the VPN that owns the PKI, or give this stack its own." >&2
    exit 1
fi

if [ ! -f "${KEY_PATH}/issued/${username}.crt" ]; then
    echo -e "${RED}No issued certificate for '${username}'${CLEAR}" >&2
    echo "Issued users:" >&2
    ls "${KEY_PATH}/issued/" 2>/dev/null | sed 's/\.crt$//' | sed 's/^/  /' >&2
    exit 1
fi

serial=$(openssl x509 -in "${KEY_PATH}/issued/${username}.crt" -noout -serial | cut -d= -f2)
echo "revoking ${username}, serial ${serial}"

(
    cd "$EASYRSA_PATH"
    # EASYRSA_BATCH stops easyrsa prompting; without it this hangs when run
    # non-interactively, eg from a runbook or CI
    EASYRSA_BATCH=1 ./easyrsa revoke "$username"
    EASYRSA_BATCH=1 ./easyrsa gen-crl
)

# Confirm the serial actually landed in the CRL rather than trusting the exit code
if openssl crl -in "${KEY_PATH}/crl.pem" -text -noout | grep -qi "$serial"; then
    echo -e "${GREEN}certificate revoked and present in the CRL${CLEAR}"
else
    echo -e "${RED}serial ${serial} is not in the CRL, revocation did not take${CLEAR}" >&2
    exit 1
fi

# Second factor. The old version ignored a failure here, which left the user able to
# authenticate if their cert were ever restored.
if grep -qE "^${username}," "$USER_PW_FILE" 2>/dev/null; then
    sed -i "/^${username},/d" "$USER_PW_FILE"
    if grep -qE "^${username}," "$USER_PW_FILE" 2>/dev/null; then
        echo -e "${RED}failed to remove ${username} from ${USER_PW_FILE}${CLEAR}" >&2
        exit 1
    fi
    echo -e "${GREEN}second factor removed${CLEAR}"
else
    echo -e "${YELLOW}no second factor entry for ${username}${CLEAR}"
fi

# Drop any per-user client config so a reissued cert does not silently inherit it
rm -f "/etc/openvpn/clients.d/${username}" 2>/dev/null || true

/etc/openvpn/bin/push_to_s3.sh

echo
echo -e "${YELLOW}The CRL has changed. Servers using this PKI will not honour the${CLEAR}"
echo -e "${YELLOW}revocation until they reload it: run reload_crl.sh on each.${CLEAR}"
echo -e "Exiting ${BOLD}$_${CLEAR}"
