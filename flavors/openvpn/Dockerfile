FROM quay.io/cdis/amazonlinux-base:latest

# Everything the VPN endpoint needs is installed here rather than at instance boot.
# The old setup cloned cloud-automation and installed packages on first start, so a
# replacement instance depended on a git branch still existing and on the package
# mirrors being reachable before it could serve anything.
#
# AL2023 ships only its own repo, no EPEL. The previous bootstrap ran
# "amazon-linux-extras install epel", which is an AL2 command and silently does
# nothing here, then tried to install packages that were never present. easy-rsa is
# installed from its upstream release below, and nginx replaces lighttpd.
#
# curl is deliberately absent: the base image provides curl-minimal, which owns the
# curl binary and conflicts with the full package.
#
# openvpn is pinned to 2.6.12, which is what AL2023 ships. Amazon backports security
# fixes and bumps the package revision, so patching is a rebuild rather than a source
# build we maintain. Upstream is further ahead (2.6.22 on that branch, and 2.7.x) --
# worth revisiting if AL2023 falls behind on something that matters.
RUN dnf update -y && dnf install -y \
      openvpn-2.6.12 \
      openssl \
      iproute \
      iptables-nft \
      iptables-services \
      shadow-utils \
      bind-utils \
      nginx \
      postfix \
      s-nail \
      cronie \
      zip \
      unzip \
      tar \
      gzip \
      rsync \
      wget \
      jq \
      python3 \
      python3-pip \
      awscli-2 \
      gettext \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# easy-rsa is not packaged for AL2023, so take it from upstream. Pinned and checksummed
# rather than pulled latest, so an image rebuild cannot quietly change the PKI tooling.
ARG EASYRSA_VERSION=3.1.7
ARG EASYRSA_SHA256=aaa48fadcbb77511b9c378554ef3eae09f8c7bc149d6f56ba209f1c9bab98c6e
RUN wget -q "https://github.com/OpenVPN/easy-rsa/releases/download/v${EASYRSA_VERSION}/EasyRSA-${EASYRSA_VERSION}.tgz" \
      -O /tmp/easyrsa.tgz \
    && echo "${EASYRSA_SHA256}  /tmp/easyrsa.tgz" | sha256sum -c - \
    && mkdir -p /usr/share/easy-rsa/3 \
    && tar xzf /tmp/easyrsa.tgz -C /usr/share/easy-rsa/3 --strip-components=1 \
    && ln -sf /usr/share/easy-rsa/3/easyrsa /usr/local/bin/easyrsa \
    && rm -f /tmp/easyrsa.tgz

# The openvpn package already creates this user, so pin the ids rather than trying to
# create it again. openvpn drops privileges to this account after startup, and the PKI
# recovered from S3 has to end up owned by it.
RUN groupmod -g 992 openvpn && \
    usermod -u 994 -g 992 -d /etc/openvpn -s /sbin/nologin openvpn && \
    id openvpn

# pyotp and qrcode drive TOTP enrollment, bcrypt hashes the user passwords.
# qrcode needs pillow to write the PNG that gets handed to the user; without it
# reset_totp_token.sh raises ModuleNotFoundError and nobody can enroll MFA.
RUN pip3 install --no-cache-dir pyotp "qrcode[pil]" bcrypt

# Scripts live outside /etc/openvpn on purpose. That path is a bind mount from the
# host at runtime, so anything shipped inside it in the image is shadowed by the host
# directory and disappears, including the entrypoint docker needs to exec.
# entrypoint.sh symlinks these into /etc/openvpn/bin once the mount is in place.
COPY scripts/ /opt/openvpn/bin/

RUN chmod +x /opt/openvpn/bin/*.sh /opt/openvpn/bin/*.py 2>/dev/null || true

# 1194 OpenVPN, 443 the QR code endpoint used for TOTP enrollment
EXPOSE 1194/tcp
EXPOSE 443/tcp

# The entrypoint recovers the PKI, renders the config, brings up DNS and the
# forwarding rules, then execs openvpn
ENTRYPOINT ["/opt/openvpn/bin/entrypoint.sh"]
