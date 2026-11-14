variable "aws_region" {
  description = "AWS region in which to deploy the lab."
  type        = string
}

variable "aws_profile" {
  description = "Local AWS CLI profile used by Terraform."
  type        = string
}

variable "project_name" {
  description = "Prefix used for resource names and tags."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the bastion and all Kubernetes nodes."
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "Name of an existing EC2 key pair in the selected AWS region."
  type        = string
}

variable "admin_cidr" {
  description = "Your laptop's public IPv4 address in CIDR notation, e.g. 203.0.113.10/32. Only this address can SSH to the bastion."
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_cidr, 0)) && can(regex("/32$", var.admin_cidr))
    error_message = "admin_cidr must be a single IPv4 address with /32, for example 203.0.113.10/32."
  }
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB for each EC2 instance."
  type        = number
  default     = 20
}

variable "enable_nodeport_ingress" {
  description = "Allow TCP NodePort traffic from Kubernetes node private IPs."
  type        = bool
  default     = true
}
