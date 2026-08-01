provider "aws" {
  region = "us-west-2"
}

# ============= AMI =============
data "aws_ami" "linux" {
  most_recent = var.instance_configurations.most_recent
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"] # Amazon Linux 2023
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ============= Security Groups =============
resource "aws_security_group" "sgs" {
  for_each = local.Security_groups
  vpc_id   = aws_vpc.VPCs[each.value.VPC].id
  name     = each.key

  dynamic "ingress" {
    for_each = each.value.ingress
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }
  dynamic "egress" {
    for_each = each.value.egress
    content {
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }
}


# ============= Instances configs =============
resource "aws_instance" "instances" {

  for_each               = var.EC2_instances
  ami                    = data.aws_ami.linux.id
  instance_type          = var.instance_configurations.instance_type
  subnet_id              = aws_subnet.subnets[each.value.subnet].id
  vpc_security_group_ids = [aws_security_group.sgs[each.value.sg].id]
  key_name               = aws_key_pair.key_connection.key_name

  tags = {
    Name = each.key
  }
}

# ============= Chave SSH para conexão =============
resource "aws_key_pair" "key_connection" {
  key_name   = "SSH Key"
  public_key = file(".ssh/terraform-key.pub")
}