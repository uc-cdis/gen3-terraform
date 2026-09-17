# TL;DR

Brings up an OpenVPN endpoint as an autoscaling group behind a network load balancer.
OpenVPN runs from a container image whose source lives in
[`flavors/openvpn`](../../../../flavors/openvpn), so the instance itself is disposable.

This replaces `vpn_nlb_central_csoc`, which installed OpenVPN onto the host at boot by
cloning cloud-automation and running a bootstrap script.

## 1. QuickStart

```bash
terraform init
terraform apply -var-file=config.tfvars
```

## 2. Table of contents

- [3. Overview](#3-overview)
- [4. IP schema](#4-ip-schema)
- [5. Variables](#5-variables)
- [6. Outputs](#6-outputs)
- [7. Operating notes](#7-operating-notes)

## 3. Overview

The module creates, per environment:

- Per-AZ public subnets carved out of `vpn_server_subnet` as `/28`s
- An internet facing NLB with listeners on 1194 (OpenVPN), 443 (TOTP QR codes) and 22 (ssh)
- A launch template running AL2023, plus an ASG of one instance
- An S3 bucket holding the PKI, versioned and encrypted
- An IAM role granting CloudWatch Logs, that bucket, and Session Manager
- A Route53 CNAME pointing `env_vpn_name` at the NLB

Nothing is cloned from git at boot, so a deleted branch cannot break a replacement
instance. Responsibilities are split between the instance and the container:

| | Owns |
|---|---|
| userdata, on the host | docker, dnsmasq and its refresh timer, the CloudWatch agent, the `openvpn-container` unit |
| the container | OpenVPN, the PKI, the iptables forwarding rules |

dnsmasq deliberately runs on the host rather than in the container. Clients are pushed
the instance's own address as their resolver, so DNS has to keep answering across
container restarts and image pulls.

### Why the instances are disposable

The PKI is pushed to S3 on first boot. A replacement instance recovers it rather than
generating a fresh CA, so existing client configs keep working. Two things previously
prevented a clean replacement and are handled by the container:

- The DNS server pushed to clients is read from instance metadata at start, rather
  than being hardcoded to one instance's private address
- The iptables forwarding and masquerade rules are reapplied on every container start,
  so they survive a reboot or a docker restart

## 4. IP schema

Both environments live in `vpc-e2b51d99`.

| | csoc-dev-openvpn | csoc-prod-openvpn |
|---|---|---|
| `vpn_server_subnet` (the instances) | `10.128.15.0/25` | `10.128.15.128/25` |
| `csoc_vpn_subnet` (VPN clients) | `192.168.4.0/24` | `192.168.6.0/24` |
| `csoc_vm_subnet` (reachable network, ssh source) | `10.128.7.0/24` | `10.128.0.0/20` |
| `cwl_group_name` | `planx_dev_openvpn_log_group` | `planx_prod_openvpn_log_group` |

`vpn_server_subnet` gets split into six `/28`s, one per AZ, via `cidrsubnet(cidr, 3, index)`.

### Deploying green alongside blue

These values are deliberately clear of the stacks already in the account, so this module
can be applied while the current VPN keeps serving traffic:

| Stack | Names | Server subnet | Client subnet | State |
|---|---|---|---|---|
| original | `csoc-*-vpn` | `10.128.5.0/25`, `10.128.5.128/25` | — | ASGs at 0, bucket and role still present |
| current | `csoc-*-vpn-2024` | `10.128.6.0/25`, `10.128.6.128/25` | `192.168.3.0/24`, `192.168.5.0/24` | serving traffic |
| this module | `csoc-*-openvpn` | `10.128.15.0/25`, `10.128.15.128/25` | `192.168.4.0/24`, `192.168.6.0/24` | green |

`10.128.15.0/24` was the only fully free `/24` remaining in the VPC. Cut over by pointing
DNS at the new NLB once the new stack is verified, then retire the old one.

## 5. Variables

### 5.1 Required

| Name | Description | Type |
|------|-------------|:----:|
| env_vpn_name | Names most resources, matches the FQDN prefix, ie `csoc-dev-vpn-2024` | string |
| env_cloud_name | Server hostname and easy-rsa OU, ie `planx-dev-vpn-2024` | string |
| env_vpc_id | VPC to deploy into | string |
| vpn_server_subnet | CIDR carved into per-AZ /28s for the instances | string |
| csoc_vpn_subnet | The OpenVPN client network | string |
| csoc_vm_subnet | Network clients need to reach, and the only CIDR allowed to ssh in | string |
| env_pub_subnet_routetable_id | Route table giving the subnets public access | string |
| csoc_planx_dns_zone_id | Route53 zone for the VPN CNAME | string |
| ssh_key_name | EC2 key pair name | string |
| cwl_group_name | CloudWatch Logs group for instance logs | string |

### 5.2 Optional

| Name | Description | Type | Default |
|------|-------------|:----:|:-----:|
| pushed_routes | Routes pushed to clients | list | `["10.128.0.0/12", "172.16.0.0/12"]` |
| dnsmasq_overrides | hostname to internal LB DNS name, for split horizon DNS | map | `{}` |
| vpn_instance_type | Instance type | string | `m6i.large` |
| vpn_instance_drive_size | Root volume size in GB | number | `30` |
| vpn_availability_zones | AZs to use, empty means all available | list | `[]` |
| ami_account_id | Account owning the AMI | string | `137112412989` |
| image_name_search_criteria | AMI name filter | string | `al2023-ami-2023*-x86_64` |
| ssm_parameter_name | Pin an AMI id, skips the lookup | string | `""` |
| vpn_image_tag | Tag of `quay.io/cdis/openvpn` to run | string | `master` |
| organization_name | Tagging | string | `Basic Services` |
| enable_deletion_protection | Deletion protection on the NLB. Off for throwaway stacks, or destroy cannot release the subnets | bool | `true` |
| cluster_desired_capacity | Desired instances | number | `1` |
| cluster_min_size | Minimum instances | number | `1` |
| cluster_max_size | Maximum instances | number | `2` |

### Split horizon DNS

While connected, some hostnames must resolve to an internal load balancer rather than
the public one. Set `dnsmasq_overrides`:

```hcl
dnsmasq_overrides = {
  "monitoring.planx-pla.net" = "internal-k8s-monitori-grafanai-b1234ccd6c-1110695366.us-east-1.elb.amazonaws.com"
}
```

Adding another service behind an internal load balancer is a tfvars change, not a
script change. The module renders `/etc/dnsmasq.conf` and installs
`update-dnsmasq.sh` on a systemd timer that resolves each internal load balancer and
writes its current addresses to `/etc/dnsmasq.hosts`.

Internal ALB addresses move when the load balancer is recreated or scaled, so this is
rechecked every five minutes. The previous setup ran the equivalent once a day from
root's crontab, which left a whole day where clients could not reach a service whose
addresses had changed.

To check what is currently being served:

```bash
cat /etc/dnsmasq.hosts
systemctl list-timers update-dnsmasq.timer
journalctl -u update-dnsmasq.service --since -1h
```

## 6. Outputs

| Name | Description |
|------|-------------|
| vpn_nlb_dns_name | DNS name of the NLB |
| vpn_fqdn | The CNAME clients connect to |
| vpn_s3_bucket_name | Bucket holding the PKI |
| vpn_asg_name | ASG name |
| vpn_security_group_id | Inbound security group id |
| vpn_log_group_name | CloudWatch Logs group name |

## 7. Operating notes

### Getting onto a VPN instance

ssh is restricted to `csoc_vm_subnet`. From anywhere else use Session Manager:

```bash
aws ssm start-session --target <instance-id>
```

### User management

The management scripts ship in the container:

```bash
docker exec -it openvpn /etc/openvpn/bin/create_vpn_user.sh <username>
docker exec -it openvpn /etc/openvpn/bin/revoke_user.sh <username>
docker exec -it openvpn /etc/openvpn/bin/user_status.sh
```

### Removing a stack

Everything here is deletable, but ordering matters and one flag gets in the way.

`enable_deletion_protection` defaults to `true` on the NLB, so `terraform destroy` fails
until it is turned off. Set `enable_deletion_protection = false`, apply that one change,
then destroy:

```bash
terraform apply -var enable_deletion_protection=false
terraform destroy
```

The subnets are the last thing to go and will refuse to delete while anything still
holds an ENI in them. Terraform handles its own resources in the right order, but check
for strays first if the subnets do not release:

```bash
aws ec2 describe-network-interfaces \
  --filters "Name=subnet-id,Values=<subnet-id>" \
  --query "NetworkInterfaces[].{IP:PrivateIpAddress,Desc:Description}"
```

This is worth checking before assuming an old range is reusable. The subnets from the
original `csoc-*-vpn` stacks look free, but four of the twelve host an unrelated NLB and
EFS mount targets, so neither of those `/25`s can be reclaimed as a block.

The S3 bucket is versioned, so a `destroy` leaves it if it still has objects. That is
deliberate: it holds the CA, and losing it invalidates every client config.

### Replacing an instance

Terminate it and let the ASG bring up a replacement. It recovers the PKI from S3, so
client configs continue to work. Verify afterwards that the pushed DNS address matches
the new instance:

```bash
docker exec openvpn grep 'dhcp-option DNS' /etc/openvpn/server/server.conf
```
