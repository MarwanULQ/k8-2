data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  common_name = replace(var.project_name, "_", "-")

  nodes = {
    master = {
      name   = "master"
      subnet = aws_subnet.public_a.id
    }
    worker1 = {
      name   = "worker-1"
      subnet = aws_subnet.public_a.id
    }
    worker2 = {
      name   = "worker-2"
      subnet = aws_subnet.public_b.id
    }
  }
}

# -------------------------------------------------------------------
# Network: VPC, two public subnets, Internet Gateway and routing
# -------------------------------------------------------------------

resource "aws_vpc" "lab" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.common_name}-vpc"
  }
}

resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id

  tags = {
    Name = "${local.common_name}-igw"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.common_name}-public-subnet-a"
    Tier = "Public"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.common_name}-public-subnet-b"
    Tier = "Public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab.id
  }

  tags = {
    Name = "${local.common_name}-public-rt"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# -------------------------------------------------------------------
# Security groups
# Laptop -> Bastion: TCP/22 from admin_cidr only.
# Bastion -> Nodes: TCP/22 from the bastion security group only.
# -------------------------------------------------------------------

resource "aws_security_group" "bastion" {
  name        = "${local.common_name}-bastion-sg"
  description = "Allow SSH to bastion only from the administrator laptop."
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "SSH from administrator laptop"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.common_name}-bastion-sg"
  }
}

resource "aws_security_group" "nodes" {
  name        = "${local.common_name}-nodes-sg"
  description = "Allow all traffic between Kubernetes nodes and SSH to nodes."
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "Allow all traffic between Kubernetes nodes"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
    description     = "SSH only from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    description = "Allow outbound traffic for OS/package downloads"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.common_name}-nodes-sg"
  }
}

# -------------------------------------------------------------------
# EC2: one bastion + three Kubernetes nodes
# -------------------------------------------------------------------

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${local.common_name}-bastion"
    Role = "bastion"
  }
}

resource "aws_instance" "nodes" {
  for_each = local.nodes

  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = each.value.subnet
  vpc_security_group_ids      = [aws_security_group.nodes.id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${local.common_name}-${each.value.name}"
    Role = each.value.name
  }
}

/*
# -------------------------------------------------------------------
# Kubernetes node ingress. Use each node's private /32 as the source.
# Standalone rules avoid a security-group/instance dependency cycle.
# -------------------------------------------------------------------

resource "aws_security_group_rule" "nodes_api" {
  for_each = local.nodes

  type              = "ingress"
  security_group_id = aws_security_group.nodes.id
  description       = "Kubernetes API from ${each.key} private IP"
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  cidr_blocks       = ["${aws_instance.nodes[each.key].private_ip}/32"]
}

resource "aws_security_group_rule" "nodes_kubelet" {
  for_each = local.nodes

  type              = "ingress"
  security_group_id = aws_security_group.nodes.id
  description       = "Kubelet API from ${each.key} private IP"
  from_port         = 10250
  to_port           = 10250
  protocol          = "tcp"
  cidr_blocks       = ["${aws_instance.nodes[each.key].private_ip}/32"]
}

resource "aws_security_group_rule" "nodes_etcd" {
  for_each = local.nodes

  type              = "ingress"
  security_group_id = aws_security_group.nodes.id
  description       = "etcd from ${each.key} private IP"
  from_port         = 2379
  to_port           = 2380
  protocol          = "tcp"
  cidr_blocks       = ["${aws_instance.nodes[each.key].private_ip}/32"]
}

resource "aws_security_group_rule" "nodes_calico_vxlan" {
  for_each = local.nodes

  type              = "ingress"
  security_group_id = aws_security_group.nodes.id
  description       = "Calico VXLAN from ${each.key} private IP"
  from_port         = 4789
  to_port           = 4789
  protocol          = "udp"
  cidr_blocks       = ["${aws_instance.nodes[each.key].private_ip}/32"]
}

resource "aws_security_group_rule" "nodes_nodeport" {
  for_each = var.enable_nodeport_ingress ? local.nodes : {}

  type              = "ingress"
  security_group_id = aws_security_group.nodes.id
  description       = "NodePort from ${each.key} private IP"
  from_port         = 30000
  to_port           = 32767
  protocol          = "tcp"
  cidr_blocks       = ["${aws_instance.nodes[each.key].private_ip}/32"]
}

resource "aws_security_group_rule" "nodes_nodeport_admin" {
  count = var.enable_nodeport_ingress ? 1 : 0

  type              = "ingress"
  security_group_id = aws_security_group.nodes.id
  description       = "NodePort from administrator laptop"
  from_port         = 30000
  to_port           = 32767
  protocol          = "tcp"
  cidr_blocks       = [var.admin_cidr]
}
*/

# Laptop -> webapp NodePort only.
resource "aws_security_group_rule" "nodes_webapp_nodeport_admin" {
  count = var.enable_nodeport_ingress ? 1 : 0

  type              = "ingress"
  security_group_id = aws_security_group.nodes.id
  description       = "Flask webapp NodePort from administrator laptop"
  from_port         = 30080
  to_port           = 30080
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

# Laptop -> PostgreSQL NodePort only.
resource "aws_security_group_rule" "nodes_postgres_nodeport_admin" {
  count = var.enable_nodeport_ingress ? 1 : 0

  type              = "ingress"
  security_group_id = aws_security_group.nodes.id
  description       = "PostgreSQL NodePort from administrator laptop"
  from_port         = 30432
  to_port           = 30432
  protocol          = "tcp"
  cidr_blocks       = [var.admin_cidr]
}
