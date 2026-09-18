# openvpn

Source for the `quay.io/cdis/openvpn` image, deployed by the
[`vpn_auto`](../../tf_files/aws/modules/vpn_auto) module.

This lives here rather than in `uc-cdis/openvpn` so the scripts are readable alongside
the terraform that deploys them, and because that repo is private. It is the single
source: the image is built from this directory, and `uc-cdis/openvpn` keeps only its
CI pointing back here.

## What this replaces

OpenVPN used to be installed onto the instance at boot. Userdata cloned
cloud-automation, checked out a branch by name, and ran
`flavors/vpn_nlb_central/vpnvm_new.sh`, which yum installed OpenVPN and built the PKI.

That made instances effectively unreplaceable. The branch it pinned
(`feat/openvpn-update`) no longer exists, so replacements had already begun failing at
boot. Everything ships in the image now, and nothing is cloned at runtime.

## Responsibilities

| | Owns |
|---|---|
| this image | OpenVPN, the PKI, the client management scripts, the iptables forwarding rules, the QR code webserver |
| the module's userdata | docker, dnsmasq and its refresh timer, the CloudWatch agent |

dnsmasq runs on the host, not in here. Clients are pushed the instance's own address as
their resolver, so split horizon DNS has to keep answering across container restarts and
image pulls.

## Entrypoint

`scripts/entrypoint.sh` runs on every container start:

1. Recover the PKI from S3. A replacement instance adopts the existing CA, so client
   configs already in circulation keep validating. A new CA is only built when the
   bucket is empty, and is pushed straight back up.
2. Render `openvpn.conf`. Routes come from `PUSHED_ROUTES`; the DNS server pushed to
   clients is this instance's private address, read from instance metadata. Hardcoding
   it is what previously broke replacement, since clients kept being handed a resolver
   that no longer existed.
3. Apply the iptables forward and masquerade rules, then `exec openvpn`.

Steps 2 and 3 finish before OpenVPN accepts connections. Getting that order wrong leaves
the first clients to connect with a tunnel that comes up but cannot route.

## Environment

Set by the terraform module.

| Variable | Description |
|---|---|
| `VPN_NLB_NAME` | Stack name, used as the S3 key prefix |
| `CLOUD_NAME` | Server hostname, and the CN easy-rsa issues the server cert for |
| `S3_BUCKET` | Bucket holding the PKI |
| `CSOC_VPN_SUBNET` | The OpenVPN client network |
| `CSOC_VM_SUBNET` | Network clients need to reach |
| `PUSHED_ROUTES` | Semicolon separated CIDRs pushed to clients |
| `AWS_DEFAULT_REGION` | Region for the S3 calls |

## Building locally

```bash
docker build --platform linux/amd64 -t openvpn:local .
```

## User management

```bash
docker exec -it openvpn /etc/openvpn/bin/create_vpn_user.sh <username>
docker exec -it openvpn /etc/openvpn/bin/revoke_user.sh <username>
docker exec -it openvpn /etc/openvpn/bin/reset_totp_token.sh <username>
docker exec -it openvpn /etc/openvpn/bin/user_status.sh
```

Changes are pushed back to S3 by `push_to_s3.sh` so they survive instance replacement.

## Notes on the port from cloud-automation

Behaviour changed in a few places, deliberately. Several of these were latent breakages
rather than choices, found by building against AL2023 instead of trusting the old script:

- **nginx replaces lighttpd**, which is not packaged for AL2023. It serves the same
  `/var/www/qrcode` over the same self signed pem, but https only and with directory
  listing off. The old config also served those QR codes unencrypted on port 80, and a
  QR code encodes the user's TOTP secret.
- **`awscli` was missing from the image entirely**, which would have failed PKI recovery
  on first boot and generated a fresh CA, invalidating every client config in
  circulation.
- **easy-rsa comes from its upstream release**, pinned and checksummed. AL2023 has no
  EPEL, and the old bootstrap ran `amazon-linux-extras install epel` — an AL2 command
  that silently does nothing here — before installing packages that were never present.
- **`sipcalc` dropped** for python's `ipaddress` for CIDR to netmask conversion, also
  not packaged for AL2023.
- **`comp-lzo` removed** and the cipher moved to `AES-256-GCM`. Compressing before
  encrypting leaks plaintext length (VORACLE); upstream disabled it by default in 2.5.
- **`network_tweaks.sh` runs on every start** and is idempotent, rather than being
  applied once by hand. Anything that flushed iptables previously broke routing for
  every connected client until someone noticed and reran it.
- **S3 scripts read `S3_PREFIX` from the environment** instead of having a `WHICHVPN`
  placeholder patched in at install time, which left the copy on disk different from the
  copy in git.
- `recover_from_s3.sh` copied `cert.key` over both `/root/cert.key` and `/root/cert.pem`,
  so the recovered `cert.pem` was actually a private key. Fixed.
