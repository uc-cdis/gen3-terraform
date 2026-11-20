#!/bin/bash

CLEAR="\033[0m"
BLINK="\033[5m"
BOLD="\033[1m"
UNDERLINE="\033[4m"
REVERSED="\033[7m"
GREEN="\033[32m"
CYAN="\033[36m"
YELLOW="\033[33m"
MAGENTA="\033[35m"
WHITE="\033[37m"
RED="\033[31m"

echo -e "Entering ${BOLD}$_${CLEAR}"

if [ "${1}" == "" ]
then
    echo "USAGE: $0 path_to_csv"
    echo -e "CSV FORMAT:\n\t\tfull_name_1, email1\n\t\tfull_name2,email2"
    exit 1
fi

FILENAME=${1}
if [ ! -e "$1" ]
then
    echo -e "ERROR: ${RED}${FILENAME}${CLEAR} does not exist" >&2
    exit 1
fi

# /etc/openvpn is bind mounted, so this script is also reachable from a shell on the
# instance itself, where it half works: the cert and zip get made, then
# reset_totp_token.sh dies because the host python has no pyotp, and the user is sent a
# config with no QR code and no second factor. Re-run inside the container instead.
# The CSV usually sits on the host (eg /root), out of the container's view, so it is
# passed over stdin rather than by path.
if [ ! -e /.dockerenv ]
then
    echo -e "${YELLOW}not inside the openvpn container, re-running there${CLEAR}" >&2
    exec docker exec -i openvpn /etc/openvpn/bin/send_email.sh /dev/stdin < "${FILENAME}"
fi

if [ -e /etc/profile.d/99-proxy.sh ]
then
    source /etc/profile.d/99-proxy.sh
    echo -e "${YELLOW}using proxy${CLEAR}"
fi

if [ -e /etc/openvpn/bin/settings.sh ] && [ -z "$VPN_SETTINGS_LOADED" ]
then
    source /etc/openvpn/bin/settings.sh
fi

# Has to come after settings.sh is sourced, that is where S3_PREFIX is defined.
# entrypoint.sh writes it there so scripts run by hand via docker exec see the same
# values the container started with. The old copy hardcoded a WHICHVPN placeholder that
# was sed replaced at install time, so the file on the box never matched the one in git.
export S3BUCKET="${S3_PREFIX:?S3_PREFIX is not set, run this inside the openvpn container}"

set -e
set -u
set -o pipefail


create_vpn_user() {
    $VPN_BIN_ROOT/create_vpn_user.sh "$vpn_username" "$vpn_email"
}
create_vpn_zip() {
    $VPN_BIN_ROOT/make_zips.sh "$vpn_username"
}
set_vpn_totp_secret() {
    # Without pipefail a failed reset was masked by tail's exit status, and the letter
    # went out with an empty QR code link.
    vpn_totp_qrcode=$( $VPN_BIN_ROOT/reset_totp_token.sh "$vpn_username" | tail -n1 ) || true
    if [[ "$vpn_totp_qrcode" != https://* ]]
    then
        echo -e "${RED}no QR code URL for ${vpn_username}${CLEAR}; the user has a cert but no second factor." >&2
        echo "Fix with: $VPN_BIN_ROOT/reset_totp_token.sh ${vpn_username}" >&2
        return 1
    fi
}
vpn_user_exists() {
    grep -E "^$vpn_username," ${VPN_USER_CSV} &>/dev/null
    return $?
}

send_welcome_letter_png() {
    #export VPN_CREDS_URL=${vpn_creds_url}
    export VPN_CREDS_URL=${vpn_totp_qrcode}

    # do some garbage collection
    aws s3 rm --recursive "s3://${S3BUCKET}/userzips/$(date +%Y/%m -d '40 days ago')/"
    local s3Path="s3://${S3BUCKET}/userzips/$(date +%Y/%m)/${vpn_username}_$(date +%Y%m%d%H%M%S).zip"
    local signedUrl
    aws s3 cp --sse AES256 "$TEMP_ROOT/$vpn_username.zip" "$s3Path" || return 1
    signedUrl="$(aws s3 presign "$s3Path" --expires-in "$((60*60*48))")"
    echo -e "\nSend the following as an OTP to $vpn_email\n------------------\n"
    ( cat "$VPN_BIN_ROOT/templates/creds_template.txt" | SIGNED_URL="$signedUrl" envsubst )
}


while read line
do
    #Unset variable to prevent oops
    unset vpn_username
    unset vpn_email
    unset vpn_password
    unset vpn_creds_url

    #Send the current user to stderr incase we abort to error
    echo "$line" 1>&2

    #CSV should only have two fields
    vpn_username=$(echo $line | cut -f1 -d"," | tr -dc '[:alnum:]\n\r' | tr '[:upper:]' '[:lower:]' )
    vpn_email=$(echo $line | cut -f2 -d",")

    #Skip the header
    if [ "$vpn_username" == "Name" ] || [ "$vpn_email" == "E-mail" ]
    then
        continue
    fi

    if vpn_user_exists
    then
        echo -e "${YELLOW}${vpn_username}${CLEAR} exists skipping"
        continue
    fi

    create_vpn_user
    create_vpn_zip
    set_vpn_totp_secret
    send_welcome_letter_png

done < ${FILENAME}
echo -e "Exiting ${BOLD}$_${CLEAR}"
