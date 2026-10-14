variable "name_prefix" {
  type        = string
  description = "Name prefix for the launch template"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
}

variable "image_id" {
  type        = string
  description = "AMI ID to launch"
}

variable "key_name" {
  type        = string
  description = "SSH key pair name; null or empty string disables key injection"
  default     = null
}

variable "iam_instance_profile_name" {
  type        = string
  description = "Name of the IAM instance profile to attach"
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security group IDs to attach to the primary network interface"
}

variable "associate_public_ip_address" {
  type        = bool
  description = "Whether to associate a public IP on the primary network interface"
  default     = false
}

variable "user_data" {
  type        = string
  description = "Raw (unencoded) user data script; the module base64-encodes it"
  sensitive   = true
}

variable "volume_size" {
  type        = number
  description = "Root EBS volume size in GiB"
  default     = 30
}

variable "name_tag" {
  type        = string
  description = "Value for the Name tag on launched instances; empty string omits tag_specifications"
  default     = ""
}

variable "extra_tags" {
  type        = map(string)
  description = "Additional tags merged into tag_specifications alongside Name"
  default     = {}
}
