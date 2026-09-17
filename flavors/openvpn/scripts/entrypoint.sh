#!/bin/bash
# Container entrypoint for the VPN endpoint.
#
# Replaces flavors/vpn_nlb_central/vpnvm_new.sh from cloud-automation, which installed
# OpenVPN onto the host at boot after cloning that repo. Everything needed now ships in
# this image, so a replacement instance cannot be broken by a moved or deleted branch.
#
# Ordering matters. The forwarding rules are in place before OpenVPN starts accepting
# connections, otherwise the first clients to connect get a tunnel that comes up but
# cannot reach anything.
#
# dnsmasq is not managed here. It runs on the host so that split horizon DNS keeps
# working across container restarts and image pulls, and because clients are pushed the
# instance's own address as their resolver. See the vpn_auto module's userdata.
#
# Expected environment, all set by the terraform module:
#   VPN_NLB_NAME       name of the stack, used as the S3 key prefix
#   CLOUD_NAME         server hostname, and the CN easy-rsa issues the server cert for
#   S3_BUCKET          bucket holding the PKI
#   CSOC_VPN_SUBNET    the OpenVPN client network
#   CSOC_VM_SUBNET     network clients need to reach
#   PUSHED_ROUTES      semicolon separated CIDRs pushed to clients
#   CWL_GROUP          CloudWatch Logs group, informational here

set -euo pipefail

OPENVPN_PATH=/etc/openvpn
# Where the scripts actually live in the image. Deliberately outside OPENVPN_PATH,
# because that is a bind mount from the host and would shadow anything shipped under it.
SRC_BIN_PATH=/opt/openvpn/bin
# Where they are exposed once the mount is in place, so the paths baked into
# openvpn.conf and the runbooks keep working.
BIN_PATH="${OPENVPN_PATH}/bin"
TEMPLATE_PATH="${BIN_PATH}/templates"
EASYRSA_PATH="${OPENVPN_PATH}/easy-rsa"
SERVER_CONF="${OPENVPN_PATH}/server/server.conf"

# easy-rsa DN fields. Only used when building a PKI from scratch.
KEY_SIZE=4096
COUNTRY=US
STATE=IL
CITY=Chicago
ORG=CTDS
EMAIL='support@gen3.org'
KEY_EXPIRE=365
PROTO=tcp

log() { echo "=== $* ==="; }

require_env() {
    local missing=0
    for var in "$@"; do
        if [ -z "${!var:-}" ]; then
            echo "required environment variable ${var} is not set" >&2
            missing=1
        fi
    done
    [ "$missing" -eq 0 ] || exit 1
}

require_env VPN_NLB_NAME CLOUD_NAME S3_BUCKET CSOC_VPN_SUBNET

# Where the PKI lives in S3. Defaults to this stack's own bucket and name.
#
# S3_PREFIX_OVERRIDE points it somewhere else, which is how a new stack adopts the CA and
# ta.key of an existing VPN instead of generating its own. Without that, every client
# config already in circulation would fail to validate against a brand new CA.
export S3_PREFIX="${S3_PREFIX_OVERRIDE:-${S3_BUCKET}/${VPN_NLB_NAME}}"

# Everything clients reach: the explicit route list, falling back to the VM subnet
ROUTED_NETWORKS="${PUSHED_ROUTES:-${CSOC_VM_SUBNET:-}}"
ROUTED_NETWORKS="${ROUTED_NETWORKS//;/ }"

# The address we hand clients as their DNS server. Read from instance metadata rather
# than hardcoded, because a replacement instance gets a different private address and
# every client config would otherwise point at one that no longer exists.
discover_private_ip() {
    local token ip
    # IMDSv2 first, fall back to v1 if tokens are not required
    token=$(curl -sf -X PUT "http://169.254.169.254/latest/api/token" \
        -H "X-aws-ec2-metadata-token-ttl-seconds: 300" 2>/dev/null || true)
    if [ -n "$token" ]; then
        ip=$(curl -sf -H "X-aws-ec2-metadata-token: ${token}" \
            "http://169.254.169.254/latest/meta-data/local-ipv4" 2>/dev/null || true)
    else
        ip=$(curl -sf "http://169.254.169.254/latest/meta-data/local-ipv4" 2>/dev/null || true)
    fi
    echo "$ip"
}

# OpenVPN wants a dotted netmask rather than a prefix length. The old bootstrap used
# sipcalc for this, which is not packaged for AL2023; python's ipaddress is in the
# standard library and gives the same answer.
cidr_to_base_mask() {
    python3 -c '
import ipaddress, sys
try:
    net = ipaddress.ip_network(sys.argv[1], strict=False)
except ValueError as exc:
    sys.exit(f"could not parse {sys.argv[1]}: {exc}")
print(net.network_address, net.netmask)
' "$1"
}

# Turns "10.0.0.0/12;172.16.0.0/12" into openvpn push directives
render_pushed_routes() {
    local routes="$1" out="" net parsed
    IFS=';' read -ra entries <<< "$routes"
    for net in "${entries[@]}"; do
        [ -z "$net" ] && continue
        if ! parsed=$(cidr_to_base_mask "$net"); then
            echo "skipping unparseable route ${net}" >&2
            continue
        fi
        out+="push \"route ${parsed}\""$'\n'
    done
    printf '%s' "$out"
}

# The host bind mount is empty on a fresh instance, so publish the image's scripts into
# it. Done every start so an image upgrade replaces them rather than leaving whatever the
# previous version wrote on the host volume.
publish_scripts() {
    log "publishing scripts into ${BIN_PATH}"
    mkdir -p "$BIN_PATH"
    # --delete so files removed from the image do not linger on the host volume
    if command -v rsync >/dev/null 2>&1; then
        rsync -a --delete "${SRC_BIN_PATH}/" "${BIN_PATH}/"
    else
        rm -rf "${BIN_PATH:?}"/*
        cp -a "${SRC_BIN_PATH}/." "${BIN_PATH}/"
    fi
    chmod +x "${BIN_PATH}"/*.sh "${BIN_PATH}"/*.py 2>/dev/null || true
    # Older runbooks refer to this path
    ln -sfn "$BIN_PATH" "${OPENVPN_PATH}/openvpn_management_scripts"
}

setup_directories() {
    log "preparing directories"
    mkdir -p "${OPENVPN_PATH}/server"
    mkdir -p "${OPENVPN_PATH}/clients.d/tmp"
    mkdir -p "${OPENVPN_PATH}/environments"
    mkdir -p "${OPENVPN_PATH}/client-restrictions"
    mkdir -p "${EASYRSA_PATH}"
    mkdir -p /var/www/qrcode
    touch "${OPENVPN_PATH}/user_passwd.csv"

    # openvpn drops privileges after start, so it needs to own what it writes
    chown -R openvpn:openvpn "${EASYRSA_PATH}" "${OPENVPN_PATH}/user_passwd.csv" \
        "${OPENVPN_PATH}/clients.d/tmp" 2>/dev/null || true
    chmod 775 "${OPENVPN_PATH}/clients.d" "${OPENVPN_PATH}/clients.d/tmp"
    chmod 750 /var/www/qrcode
}

# The client generation scripts write into these, and they live under pki/ so they have
# to be created after the PKI exists. build_pki clears pki/ wholesale, so creating them
# in setup_directories would not survive a fresh build.
setup_pki_output_dirs() {
    local key_dir="${EASYRSA_PATH}/pki"
    mkdir -p "${key_dir}/ovpn_files"
    mkdir -p "${key_dir}/ovpn_files_seperated"
    mkdir -p "${key_dir}/ovpn_files_systemd"
    mkdir -p "${key_dir}/ovpn_files_resolvconf"
    mkdir -p "${key_dir}/user_certs"
    # openvpn drops to this user, and the scripts run as root but write here
    chown -R openvpn:openvpn "$EASYRSA_PATH" 2>/dev/null || true
    # Older runbooks expect this symlink at the openvpn root
    ln -sfn easy-rsa/pki/ovpn_files "${OPENVPN_PATH}/ovpn_files" 2>/dev/null || true
}

install_settings() {
    log "rendering settings.sh"
    local settings="${BIN_PATH}/settings.sh"
    sed -e "s|#FQDN#|${CLOUD_NAME}|g" \
        -e "s|#EMAIL#|${EMAIL}|g" \
        -e "s|#CLOUD_NAME#|${VPN_NLB_NAME}|g" \
        "${TEMPLATE_PATH}/settings.sh.template" > "$settings"

    # Persist the runtime environment here too. Every management script sources this
    # file, but `docker exec` does not inherit what the entrypoint exported, so an
    # operator running create_vpn_user.sh or send_email.sh by hand would otherwise
    # have no S3_PREFIX and fail.
    cat >> "$settings" <<SETTINGS

# Written by entrypoint.sh so scripts run via docker exec see the same values
export S3_PREFIX='${S3_PREFIX}'
export S3BUCKET='${S3_PREFIX}'
export VPN_NLB_NAME='${VPN_NLB_NAME}'
export AWS_DEFAULT_REGION='${AWS_DEFAULT_REGION:-us-east-1}'
SETTINGS
}

install_easyrsa_vars() {
    log "rendering easy-rsa vars"
    sed -e "s|#EASY_RSA_DIR#|${EASYRSA_PATH}|g" \
        -e "s|#EXTHOST#|${CLOUD_NAME}|g" \
        -e "s|#KEY_SIZE#|${KEY_SIZE}|g" \
        -e "s|#COUNTRY#|${COUNTRY}|g" \
        -e "s|#STATE#|${STATE}|g" \
        -e "s|#CITY#|${CITY}|g" \
        -e "s|#ORG#|${ORG}|g" \
        -e "s|#EMAIL#|${EMAIL}|g" \
        -e "s|#OU#|${VPN_NLB_NAME}|g" \
        -e "s|#KEY_NAME#|${VPN_NLB_NAME}-OpenVPN|g" \
        -e "s|#KEY_EXPIRE#|${KEY_EXPIRE}|g" \
        "${TEMPLATE_PATH}/vars.template" > "${EASYRSA_PATH}/vars"
}

# Everything openvpn.conf references. A PKI missing any of these is not usable, and
# openvpn exits at startup rather than starting degraded.
pki_required_files() {
    # No dh.pem: openvpn.conf uses "dh none" with ECDH
    cat <<FILES
${EASYRSA_PATH}/pki/ca.crt
${EASYRSA_PATH}/pki/ta.key
${EASYRSA_PATH}/pki/crl.pem
${EASYRSA_PATH}/pki/issued/${CLOUD_NAME}.crt
${EASYRSA_PATH}/pki/private/${CLOUD_NAME}.key
FILES
}

pki_missing_files() {
    local f
    while read -r f; do
        [ -s "$f" ] || echo "  missing: $f"
    done < <(pki_required_files)
}

pki_is_complete() {
    local f
    while read -r f; do
        [ -s "$f" ] || return 1
    done < <(pki_required_files)
    return 0
}

build_pki() {
    log "building a new PKI, this takes a while"
    # Clear any partial state, otherwise easyrsa init-pki prompts or refuses
    rm -rf "${EASYRSA_PATH}/pki"
    cd "$EASYRSA_PATH"
    /usr/share/easy-rsa/3/easyrsa init-pki
    /usr/share/easy-rsa/3/easyrsa build-ca nopass
    # No gen-dh: openvpn.conf uses "dh none" with ECDH, and generating 4096 bit DH
    # parameters added several minutes to every fresh build for no benefit
    /usr/share/easy-rsa/3/easyrsa gen-crl
    /usr/share/easy-rsa/3/easyrsa build-server-full "$CLOUD_NAME" nopass
    openvpn --genkey secret "${EASYRSA_PATH}/pki/ta.key"
    log "PKI built"
}

# Self signed cert for the QR code endpoint
ensure_server_pem() {
    if [ ! -e /root/server.pem ]; then
        log "generating the QR webserver certificate"
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -subj "/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=CDIS/CN=${CLOUD_NAME}" \
            -keyout /root/cert.key -out /root/cert.pem
        cat /root/cert.key /root/cert.pem > /root/server.pem
    fi
}

# Trust anchor for client certificates.
#
# easyrsa  the CA this container generates. Clients get certs from create_vpn_user.sh.
# acmpca   the CTDS AWS INTERNAL ROOT CA. Clients present the mTLS cert already deployed
#          to their laptop, which Viscosity reads from the macOS Keychain, so there is no
#          CA for us to run and no cert distribution to do.
#
# Either way the second factor is unchanged: auth-user-pass-verify still runs, so a cert
# alone does not get you on.
setup_client_ca() {
    if [ "${CLIENT_CA_MODE:-easyrsa}" != "acmpca" ]; then
        CLIENT_CA_PATH="${EASYRSA_PATH}/pki/ca.crt"
        log "client CA: easy-rsa (${CLIENT_CA_PATH})"
        return 0
    fi

    : "${ACM_PCA_CA_ARN:?CLIENT_CA_MODE=acmpca requires ACM_PCA_CA_ARN}"
    CLIENT_CA_PATH="${OPENVPN_PATH}/client-ca.pem"

    log "client CA: ACM-PCA ${ACM_PCA_CA_ARN}"
    if aws acm-pca get-certificate-authority-certificate \
            --certificate-authority-arn "$ACM_PCA_CA_ARN" \
            --query Certificate --output text > "${CLIENT_CA_PATH}.new" 2>/dev/null \
       && openssl x509 -in "${CLIENT_CA_PATH}.new" -noout -subject >/dev/null 2>&1; then
        mv "${CLIENT_CA_PATH}.new" "$CLIENT_CA_PATH"
        log "fetched: $(openssl x509 -in "$CLIENT_CA_PATH" -noout -subject)"
    else
        rm -f "${CLIENT_CA_PATH}.new"
        # Keep serving with the copy we already have rather than dropping every client
        # because the API call failed
        if [ -s "$CLIENT_CA_PATH" ]; then
            echo "could not refresh the CA, keeping the existing copy" >&2
        else
            echo "could not fetch the CA from ACM-PCA and have no cached copy" >&2
            exit 1
        fi
    fi
}

configure_openvpn() {
    log "rendering openvpn.conf"

    local vpn_parsed vpn_base vpn_mask routes push_dns private_ip
    if ! vpn_parsed=$(cidr_to_base_mask "$CSOC_VPN_SUBNET"); then
        echo "could not parse CSOC_VPN_SUBNET=${CSOC_VPN_SUBNET}" >&2
        exit 1
    fi
    vpn_base=${vpn_parsed% *}
    vpn_mask=${vpn_parsed#* }

    routes=$(render_pushed_routes "${PUSHED_ROUTES:-${CSOC_VM_SUBNET:-}}")

    private_ip="$(discover_private_ip)"
    if [ -n "$private_ip" ]; then
        # dnsmasq on this instance answers for the split horizon names
        push_dns="push \"dhcp-option DNS ${private_ip}\""
        log "pushing DNS ${private_ip} to clients"
    else
        # Without this clients get no resolver and internal names fail. Better to
        # fail the start than to hand out a tunnel that half works.
        echo "could not read local-ipv4 from instance metadata" >&2
        exit 1
    fi

    # Placeholders are replaced via files so multi line values and slashes in
    # CIDRs do not have to be escaped into a sed expression
    # Each directive has to land on its own line, so make sure both files end in a
    # newline before sed appends them
    local routes_file dns_file
    routes_file=$(mktemp); dns_file=$(mktemp)
    printf '%s' "$routes" | sed -e '$a\' > "$routes_file"
    printf '%s\n' "$push_dns" > "$dns_file"

    # Revocation. easy-rsa gives us one CRL covering every cert it issued, so
    # crl-verify works directly.
    #
    # ACM-PCA is configured with PARTITIONED CRLs: each certificate points at its own
    # partition file, and openvpn's crl-verify takes a single file and will not follow
    # those pointers. Enabling it with one partition would reject every client whose
    # cert belongs to a different one. Left off until that is solved properly, so
    # revoking a laptop currently means removing it from the second factor rather than
    # relying on the CRL.
    local crl_line
    if [ "${CLIENT_CA_MODE:-easyrsa}" = "acmpca" ]; then
        crl_line="# crl-verify intentionally not set, see CLIENT_CA_MODE=acmpca notes"
        if [ -n "${ACM_PCA_CRL_PATH:-}" ] && [ -s "${ACM_PCA_CRL_PATH}" ]; then
            crl_line="crl-verify ${ACM_PCA_CRL_PATH}"
        fi
    else
        crl_line="crl-verify ${EASYRSA_PATH}/pki/crl.pem"
    fi

    sed -e "s|#FQDN#|${CLOUD_NAME}|g" \
        -e "s|#PROTO#|${PROTO}|g" \
        -e "s|#CA_PATH#|${CLIENT_CA_PATH}|g" \
        -e "s|#CRL_VERIFY#|${crl_line}|g" \
        -e "s|#VPN_SUBNET_BASE#|${vpn_base}|g" \
        -e "s|#VPN_SUBNET_MASK#|${vpn_mask}|g" \
        -e "/#PUSHED_ROUTES#/r ${routes_file}" -e "/#PUSHED_ROUTES#/d" \
        -e "/#PUSHED_DNS#/r ${dns_file}" -e "/#PUSHED_DNS#/d" \
        "${TEMPLATE_PATH}/openvpn.conf.template" > "$SERVER_CONF"

    rm -f "$routes_file" "$dns_file"
}

apply_network_rules() {
    log "applying forwarding rules"
    local nettweaks="${BIN_PATH}/network_tweaks.sh"

    sed -e "s|#VPN_SUBNET#|${CSOC_VPN_SUBNET}|g" \
        -e "s|#ROUTED_NETWORKS#|${ROUTED_NETWORKS}|g" \
        -e "s|#PROTO#|${PROTO}|g" \
        "${TEMPLATE_PATH}/network_tweaks.sh.template" > "$nettweaks"

    chmod +x "$nettweaks"
    "$nettweaks"
}

# Serves the TOTP enrollment QR codes over https. lighttpd is not packaged for
# AL2023, so this is nginx now; it reads the same self signed pem and serves the
# same /var/www/qrcode directory, so create_ovpn.sh did not have to change.
configure_webserver() {
    log "configuring the QR webserver"

    mkdir -p /etc/nginx/certs
    if [ -e /root/server.pem ]; then
        install -m 600 /root/server.pem /etc/nginx/certs/server.pem
    fi

    cp "${TEMPLATE_PATH}/nginx.conf.template" /etc/nginx/nginx.conf
    chown -R openvpn:openvpn /var/www/qrcode 2>/dev/null || true

    if nginx -t 2>/dev/null; then
        nginx || echo "nginx did not start, QR enrollment will be unavailable" >&2
    else
        echo "nginx config rejected, QR enrollment will be unavailable" >&2
    fi
}

install_cron() {
    # Housekeeping: expire old QR codes and zips, alert on certs nearing expiry
    cp "${TEMPLATE_PATH}/cron.template" /etc/cron.d/openvpn
    chmod 0644 /etc/cron.d/openvpn
    crond 2>/dev/null || true
}

main() {
    log "starting ${VPN_NLB_NAME} (${CLOUD_NAME})"

    publish_scripts
    setup_directories
    install_settings

    # Adopt the existing PKI if there is one. Only build a new CA when there is not,
    # otherwise every client config already issued would stop validating.
    "${BIN_PATH}/recover_from_s3.sh" || true

    install_easyrsa_vars

    if pki_is_complete; then
        log "recovered an existing PKI from s3://${S3_PREFIX}"
        # Adopting another VPN's PKI is read only. Pushing back would let this stack
        # overwrite the live VPN's CA, user database or ipp.txt, so nothing is written
        # to a prefix we do not own.
        if [ -n "${S3_PREFIX_OVERRIDE:-}" ]; then
            log "adopted PKI is read only, this stack will not push back to it"
            export PKI_READ_ONLY=1
        fi
    else
        # Checked against every file openvpn.conf references, not just ca.crt. A
        # half populated easy-rsa directory left on the host volume by an earlier
        # failed start would otherwise look like a valid PKI, and openvpn dies at
        # startup on the first missing file.
        log "no complete PKI found, building one"
        build_pki
        ensure_server_pem
        "${BIN_PATH}/push_to_s3.sh" || \
            echo "could not push the new PKI to s3, it exists only on this instance" >&2
    fi

    # Refuse to hand off to openvpn with a PKI we know is incomplete
    if ! pki_is_complete; then
        echo "PKI is still incomplete after setup, refusing to start:" >&2
        pki_missing_files >&2
        exit 1
    fi

    setup_pki_output_dirs
    setup_client_ca

    ensure_server_pem

    # Routing is in place before openvpn accepts anyone, otherwise the first clients
    # to connect get a tunnel that comes up but cannot reach anything.
    # dnsmasq is the host's responsibility, see the terraform module's userdata.
    apply_network_rules

    configure_openvpn
    configure_webserver
    install_cron

    log "handing off to openvpn"
    exec openvpn --config "$SERVER_CONF" --cd "$OPENVPN_PATH"
}

main "$@"
