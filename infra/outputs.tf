output "vpc_id" {
  description = "ID of the lab VPC."
  value       = aws_vpc.lab.id
}

output "public_subnets" {
  description = "Public subnet IDs and CIDR blocks."
  value = {
    subnet_a = {
      id   = aws_subnet.public_a.id
      cidr = aws_subnet.public_a.cidr_block
      az   = aws_subnet.public_a.availability_zone
    }
    subnet_b = {
      id   = aws_subnet.public_b.id
      cidr = aws_subnet.public_b.cidr_block
      az   = aws_subnet.public_b.availability_zone
    }
  }
}

output "bastion_public_ip" {
  description = "Public IPv4 address of the bastion."
  value       = aws_instance.bastion.public_ip
}

output "node_private_ips" {
  description = "Private IP addresses to use when connecting from the bastion."
  value = {
    for name, instance in aws_instance.nodes : name => instance.private_ip
  }
}

output "node_public_ips" {
  description = "Public IP addresses of the nodes. SSH is still restricted to the bastion security group."
  value = {
    for name, instance in aws_instance.nodes : name => instance.public_ip
  }
}

output "ssh_bastion_command" {
  description = "SSH command to connect from your laptop."
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.bastion.public_ip}"
}

output "ssh_node_commands_from_bastion" {
  description = "Run these commands after connecting to the bastion. They use private IPs."
  value = {
    for name, instance in aws_instance.nodes :
    name => "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${instance.private_ip}"
  }
}

output "postgres_nodeport" {
  description = "PostgreSQL NodePort for the administrator laptop when NodePort ingress is enabled."
  value       = 30432
}
