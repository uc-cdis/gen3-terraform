#!/bin/bash
# Restores the PKI and user database from S3.
#
# Runs on every container start. If the bucket has a PKI the instance adopts it, so a
# replacement serves the same CA and existing client configs keep working. If the
# bucket is empty this is a no-op and entrypoint.sh builds a fresh PKI instead.
#
# Individual copies are allowed to fail because a partially populated bucket is a
# legitimate state, eg ipp.txt only appears once a client has connected.

set -uo pipefail

if [ -z "${S3_PREFIX:-}" ]; then
    echo "S3_PREFIX is not set, refusing to guess where to recover from" >&2
    exit 1
fi

aws s3 sync "s3://${S3_PREFIX}/easy-rsa/" /etc/openvpn/easy-rsa/ || true

# easyrsa needs its scripts executable, but not the config or vars files
for i in /etc/openvpn/easy-rsa/*; do
    [[ $i = *".cnf" || $i = *"/vars" ]] || chmod a+x "$i"
done

aws s3 cp "s3://${S3_PREFIX}/user_passwd.csv" /etc/openvpn/user_passwd.csv || true
aws s3 cp "s3://${S3_PREFIX}/server.pem" /root/server.pem || true
aws s3 cp "s3://${S3_PREFIX}/ipp.txt" /etc/openvpn/ipp.txt || true
aws s3 cp "s3://${S3_PREFIX}/cert.key" /root/cert.key || true
aws s3 cp "s3://${S3_PREFIX}/cert.pem" /root/cert.pem || true
aws s3 cp "s3://${S3_PREFIX}/" /root --recursive \
    --exclude "*" --include "*.csv" --exclude "user_passwd.csv" || true
