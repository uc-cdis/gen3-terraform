#!/bin/bash
# Backs the PKI and user database up to S3.
#
# This is what makes the instances disposable: a replacement recovers the CA and
# client certs from here instead of generating a new CA, which would invalidate
# every client config in circulation.
#
# S3_PREFIX is set by entrypoint.sh from the S3_BUCKET/VPN_NLB_NAME env vars. The
# previous version had a WHICHVPN placeholder that was sed replaced at install
# time, which meant the copy on disk differed from the copy in git.

set -uo pipefail

if [ -z "${S3_PREFIX:-}" ]; then
    echo "S3_PREFIX is not set, refusing to guess where to push" >&2
    exit 1
fi

# Set when this stack adopted another VPN's PKI. Pushing would overwrite the live
# VPN's CA and user database, so refuse rather than risk it.
if [ -n "${PKI_READ_ONLY:-}" ]; then
    echo "PKI at s3://${S3_PREFIX} was adopted read only, not pushing" >&2
    exit 0
fi

if [ -d /etc/openvpn/easy-rsa/ ]; then
    aws s3 sync /etc/openvpn/easy-rsa/ "s3://${S3_PREFIX}/easy-rsa/"
else
    echo "directory /etc/openvpn/easy-rsa/ does not exist"
fi

for F in /etc/openvpn/user_passwd.csv /root/*.pem /root/*.key /etc/openvpn/ipp.txt /root/*.csv; do
    if [ -e "$F" ]; then
        aws s3 cp "$F" "s3://${S3_PREFIX}/"
    else
        echo "file $F does not exist"
    fi
done
