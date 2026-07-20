# =============  VPC  =============
variable "vpc_configs" {
  default = {
    VPC1 = {cidr_block = "192.168.0.0/24"}
    VPC2 = {cidr_block = "172.18.0.0/24"}
  }
}


# =============  Subnets  =============
variable "subnets" {
  default = {
    "subnetA" = {cidr_block = "192.168.0.0/26" , az = "us-west-2a", ip_publico = true, VPC = "VPC1"}
    "subnetB" = {cidr_block = "192.168.0.64/26", az = "us-west-2a", ip_publico = false, VPC = "VPC1"}
    "subnetC" = {cidr_block = "192.168.0.128/26", az = "us-west-2a", ip_publico = true, VPC = "VPC1"}
    "subnetA_VPC2" = {cidr_block = "172.18.0.0/26", az = "us-west-2a", ip_publico = false, VPC = "VPC2"}
  }
}

# =============  NACLs  =============
locals { 
  ACLs = {
      "ACL_subnetA" = {
        subnet_name = "subnetA"
        egress = [ 
          # ============= Rule for Public connection =============
          {rule_no = 1, protocol = -1, action = "allow", cidr_block = "0.0.0.0/0", from_port = 0, to_port = 0}
        ],
        ingress = [
          # ============= Rule for Public connection =============
          {rule_no = 1, protocol = -1, action = "allow", cidr_block = "0.0.0.0/0", from_port = 0, to_port = 0}
        ]
      }
      "ACL_subnetB" = {
        subnet_name = "subnetB"
        egress = [ 
          # ============= Rule for Subnet A connection =============
          {rule_no = 1, protocol  = -1, action = "allow", cidr_block = var.subnets["subnetA"].cidr_block, from_port = 0, to_port = 0},
          {rule_no = 2, protocol  = -1, action = "deny", cidr_block = var.subnets["subnetC"].cidr_block, from_port = 0, to_port = 0} 
        ],
        ingress = [
          # ============= Rule for Subnet A connection =============
          {rule_no = 1, protocol  = -1, action = "allow", cidr_block = var.subnets["subnetA"].cidr_block, from_port = 0, to_port = 0},
          {rule_no = 2, protocol  = -1, action = "deny", cidr_block = var.subnets["subnetC"].cidr_block, from_port = 0, to_port = 0} 
        ]
      }
      "ACL_subnetC" = {
        subnet_name = "subnetC"
        egress = [ 
          # ============= Rule for Public connection =============
          {rule_no = 1, protocol  = -1, action = "allow", cidr_block = "0.0.0.0/0", from_port = 0, to_port = 0} 
        ],
        ingress = [
          # ============= Rule for Public connection =============
          {rule_no = 1, protocol  = -1, action = "allow", cidr_block = "0.0.0.0/0", from_port = 0, to_port = 0}
        ]
      }
  }  
}


# ============= Instances =============
variable "instance_configurations" {
  default = {
    most_recent = true, instance_type = "t3.micro"
  }
}

variable "EC2_instances" {
    default = {
        "Bastion" = {subnet = "subnetA" , sg="Bastion-Invasor"}
        "Invasor" = {subnet = "subnetC" , sg="Bastion-Invasor"}
        "Server_1" = {subnet = "subnetB", sg="Server_1"}
        # He will go to VPC 2 in the next commits "Server_2" = {subnet = "subnetB", sg = "Servers", cidr_blocks = ["0.0.0.0/0"]}
    }
}

locals {
  Security_groups = {
        "Bastion-Invasor" = { 
          ingress = [ {from_port = 0, to_port = 0, protocol = -1, cidr_blocks = ["0.0.0.0/0"] } ],
          egress = [ {from_port = 0, to_port = 0, protocol = -1, cidr_blocks = ["0.0.0.0/0"] }]
          },
        "Server_1" = { 
          ingress = [ {from_port = 0, to_port = 0, protocol = -1, cidr_blocks = [var.subnets["subnetA"].cidr_block] } ],
          egress = [ {from_port = 0, to_port = 0, protocol = -1, cidr_blocks = [var.subnets["subnetA"].cidr_block] }]
          }
    }
  }
