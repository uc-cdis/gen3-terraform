# Example values for the dev VPN. Prod equivalents are in comments beside each entry.
# Both environments live in the same VPC, they differ only by the CIDRs below.
#
# These names are deliberately distinct from the stacks already in the account
# (csoc-*-vpn from the original build, csoc-*-vpn-2024 currently serving traffic)
# so this can be stood up green alongside them and cut over once verified.

# Names most resources, and is the prefix of the Route53 CNAME
env_vpn_name = "csoc-dev-openvpn"
# prod: "csoc-prod-openvpn"

# Hostname given to the instance, and the OU/CN easy-rsa builds the server cert with
env_cloud_name = "planx-dev-openvpn"
# prod: "planx-prod-openvpn"

env_vpc_id = "vpc-e2b51d99"

# Carved into six /28s, one per AZ, for the instances themselves.
# 10.128.15.0/24 was the only fully free /24 left in the VPC (10.128.0.0/20), so the
# green stack lives there rather than reusing the /25s the current stacks occupy.
vpn_server_subnet = "10.128.15.0/25"
# prod: "10.128.15.128/25"

# Addresses handed out to connected VPN clients. Distinct from the ranges the existing
# stacks hand out (192.168.3.0/24 dev, 192.168.5.0/24 prod) so both can run at once.
csoc_vpn_subnet = "192.168.4.0/24"
# prod: "192.168.6.0/24"

# Network clients need to reach. Also the only CIDR allowed to ssh to the instances
csoc_vm_subnet = "10.128.7.0/24"
# prod: "10.128.0.0/20"

# Route table that gives the VPN subnets public access
env_pub_subnet_routetable_id = "rtb-1cb66860"

csoc_planx_dns_zone_id = "ZG153R4AYDHHK"

ssh_key_name = "qureshi@uchicago.edu"

cwl_group_name = "planx_dev_openvpn_log_group"
# prod: "planx_prod_openvpn_log_group"

# Routes pushed to clients. These match what prod pushes today, deliberately broad.
# Narrow them once we have audited what is actually reachable.
pushed_routes = ["10.128.0.0/12", "172.16.0.0/12"]

# Split horizon DNS. While on the VPN these names must resolve to the internal load
# balancer rather than the public one. Add an entry per service.
dnsmasq_overrides = {
  "monitoring.planx-pla.net" = "internal-k8s-monitori-grafanai-b1234ccd6c-1110695366.us-east-1.elb.amazonaws.com"
}

# Tag of quay.io/cdis/openvpn to run. Pin to a branch tag while testing.
vpn_image_tag = "main"

vpn_instance_type = "m5.xlarge"

organization_name = "Basic Services"
