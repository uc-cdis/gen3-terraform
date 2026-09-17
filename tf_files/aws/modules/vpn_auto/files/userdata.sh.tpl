MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="BOUNDARY"

--BOUNDARY
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash
# Instance bootstrap for the VPN endpoint.
#
# Split of responsibilities:
#   this script  docker, dnsmasq, the CloudWatch agent, and the systemd units
#   container    OpenVPN itself, the PKI, and the iptables forwarding rules
#
# Nothing is cloned from git here. The previous setup cloned cloud-automation and
# checked out a branch by name, so when that branch was deleted every replacement
# instance began failing at boot.
set -euo pipefail
exec > >(tee /var/log/bootstrapping_script.log) 2>&1

echo "=== bootstrapping ${env_cloud_name} ==="

hostnamectl set-hostname ${env_cloud_name}
echo "127.0.1.1 ${env_cloud_name}" >> /etc/hosts

# AWS drops any packet whose source address is not the instance's own, which breaks
# forwarding for VPN clients. The instance turns the check off for itself at boot, so a
# replacement gets it too; doing this by hand or in terraform would not survive the ASG
# launching a new instance. Same approach squid's userdata uses.
TOKEN=$(curl -sf -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 300" 2>/dev/null || true)
if [ -n "$TOKEN" ]; then
  EC2_INSTANCE_ID=$(curl -sf -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/instance-id)
else
  EC2_INSTANCE_ID=$(curl -sf http://169.254.169.254/latest/meta-data/instance-id)
fi
if [ -n "$EC2_INSTANCE_ID" ]; then
  aws ec2 modify-instance-attribute --no-source-dest-check \
    --instance-id "$EC2_INSTANCE_ID" --region ${region} \
    && echo "source/dest check disabled for $EC2_INSTANCE_ID" \
    || echo "WARNING: could not disable source/dest check, forwarding may fail" >&2
else
  echo "WARNING: could not read instance id from metadata" >&2
fi

dnf update -y
# bind-utils for dig and procps-ng for pkill, both used by update-dnsmasq.sh. Named
# explicitly rather than relied on as transitive dependencies.
dnf install -y docker dnsmasq bind-utils procps-ng amazon-cloudwatch-agent

# OpenVPN forwards between the tun device and the VPC
cat > /etc/sysctl.d/99-openvpn.conf <<'SYSCTL'
net.ipv4.ip_forward = 1
SYSCTL
sysctl --system

systemctl enable --now docker

### CloudWatch agent ########################################################
# The old bootstrap gated this behind a "is this Ubuntu" check and downloaded a .deb,
# so on these Amazon Linux instances it never ran and the log group stayed empty.
cat > /etc/cloudwatch-config.json <<'CWA'
${cloudwatch_config}
CWA

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -c file:/etc/cloudwatch-config.json -s

### Split horizon DNS #######################################################
# dnsmasq lives on the host, not in the container. Clients are pushed this instance's
# private address as their resolver, so DNS has to keep answering across container
# restarts and image pulls.
mkdir -p /etc/dnsmasq.d
touch ${dnsmasq_hosts_file}

# The rpm's own useradd is best effort (it ends in "|| :"), and dnsmasq.conf ships with
# user=dnsmasq, so if that account is missing the daemon refuses to start and split
# horizon DNS never comes up.
getent group dnsmasq >/dev/null || groupadd -r dnsmasq
getent passwd dnsmasq >/dev/null || \
  useradd -r -g dnsmasq -d /var/lib/dnsmasq -s /usr/sbin/nologin \
    -c 'Dnsmasq DHCP and DNS server' dnsmasq

cat > /etc/dnsmasq.conf <<'DNSMASQCONF'
${dnsmasq_conf}
DNSMASQCONF

install -m 0755 /dev/stdin /usr/local/bin/update-dnsmasq.sh <<'UPDATEDNSMASQ'
${update_dnsmasq_script}
UPDATEDNSMASQ

cat > /etc/systemd/system/update-dnsmasq.service <<'DNSSERVICE'
${update_dnsmasq_service}
DNSSERVICE

cat > /etc/systemd/system/update-dnsmasq.timer <<'DNSTIMER'
${update_dnsmasq_timer}
DNSTIMER

systemctl daemon-reload
systemctl enable --now dnsmasq

# Populate the overrides before OpenVPN starts handing out this resolver, otherwise the
# first clients to connect cannot resolve the internal names. Run through systemd rather
# than calling the script directly, so it picks up the same Environment= the timer uses
# instead of running with an empty DNSMASQ_OVERRIDES.
if ! systemctl start update-dnsmasq.service; then
  echo "initial dnsmasq refresh did not fully succeed, the timer will retry" >&2
fi

# Every 5 minutes from here. The old setup ran this once a day from root's crontab, so
# an internal load balancer changing address could leave clients unable to reach it for
# most of a day.
systemctl enable --now update-dnsmasq.timer

### OpenVPN #################################################################
mkdir -p /etc/openvpn

# Run as a systemd unit so docker restarts and instance reboots both come back cleanly.
# The container reapplies the iptables rules on every start, which is what stops a
# reboot from silently breaking routing the way it used to.
cat > /etc/systemd/system/openvpn-container.service <<'UNIT'
[Unit]
Description=OpenVPN server container
After=docker.service network-online.target dnsmasq.service
Requires=docker.service
Wants=network-online.target dnsmasq.service

[Service]
Restart=always
RestartSec=10
TimeoutStartSec=0
ExecStartPre=-/usr/bin/docker rm -f openvpn
ExecStartPre=/usr/bin/docker pull ${vpn_image}
ExecStart=/usr/bin/docker run --rm --name openvpn \
  --network host \
  --cap-add NET_ADMIN \
  --device /dev/net/tun \
  -v /etc/openvpn:/etc/openvpn \
  -e VPN_NLB_NAME=${env_vpn_name} \
  -e CLOUD_NAME=${env_cloud_name} \
  -e CWL_GROUP=${cwl_group} \
  -e CSOC_VPN_SUBNET=${csoc_vpn_subnet} \
  -e CSOC_VM_SUBNET=${csoc_vm_subnet} \
  -e PUSHED_ROUTES='${pushed_routes}' \
  -e S3_PREFIX_OVERRIDE='${s3_prefix_override}' \
  -e CLIENT_CA_MODE=${client_ca_mode} \
  -e ACM_PCA_CA_ARN='${acm_pca_ca_arn}' \
  -e S3_BUCKET=${s3_bucket} \
  -e ACCOUNT_ID=${account_id} \
  -e AWS_DEFAULT_REGION=${region} \
  ${vpn_image}
ExecStop=/usr/bin/docker stop openvpn

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now openvpn-container.service

echo "=== bootstrap complete ==="

--BOUNDARY--
