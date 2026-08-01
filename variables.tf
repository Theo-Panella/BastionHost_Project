# =============  VPC  =============
variable "vpc_configs" {
  type = map(object({
    cidr_block = string
  }))
}

variable "subnets" {
  type = map(object({
    cidr_block = string,
    az         = string,
    ip_publico = optional(bool, false)
    VPC        = string
  }))
}

variable "admin_cidr" {
  type = string
}

variable "ssh_key" {
  type      = string
  sensitive = true
}

# =============  NACLs  =============
locals {
  ACLs = {
    "ACL_subnetA" = {
      subnet_name = "subnetA"
      egress = [
        # ============= Rule for Public connection =============
        { rule_no = 1, protocol = "tcp", action = "allow", cidr_block = var.admin_cidr, from_port = 1024, to_port = 65535 },
        { rule_no = 2, protocol = "tcp", action = "allow", cidr_block = var.subnets["subnetB"].cidr_block, from_port = 22, to_port = 22 },
        { rule_no = 3, protocol = -1, action = "deny", cidr_block = var.subnets["subnetC"].cidr_block, from_port = 0, to_port = 0 }
      ],
      ingress = [
        # ============= Rule for Public connection =============
        { rule_no = 1, protocol = "tcp", action = "allow", cidr_block = var.admin_cidr, from_port = 22, to_port = 22 },
        { rule_no = 2, protocol = "tcp", action = "allow", cidr_block = var.subnets["subnetB"].cidr_block, from_port = 1024, to_port = 65535 },
        { rule_no = 3, protocol = -1, action = "deny", cidr_block = var.subnets["subnetC"].cidr_block, from_port = 0, to_port = 0 }
      ],
    }
    "ACL_subnetB" = {
      subnet_name = "subnetB"
      egress = [
        # ============= Rule for Subnet A connection =============
        { rule_no = 1, protocol = "tcp", action = "allow", cidr_block = var.subnets["subnetA"].cidr_block, from_port = 1024, to_port = 65535 },
        { rule_no = 2, protocol = "tcp", action = "allow", cidr_block = var.subnets["subnetA_VPC2"].cidr_block, from_port = 22, to_port = 22 },
        { rule_no = 3, protocol = -1, action = "deny", cidr_block = var.subnets["subnetC"].cidr_block, from_port = 0, to_port = 0 }
      ],
      ingress = [
        # ============= Rule for Subnet A connection =============
        { rule_no = 1, protocol = "tcp", action = "allow", cidr_block = var.subnets["subnetA"].cidr_block, from_port = 22, to_port = 22 },
        { rule_no = 2, protocol = "tcp", action = "allow", cidr_block = var.subnets["subnetA_VPC2"].cidr_block, from_port = 1024, to_port = 65535 },
        { rule_no = 3, protocol = -1, action = "deny", cidr_block = var.subnets["subnetC"].cidr_block, from_port = 0, to_port = 0 }
      ],
    }
    "ACL_subnetC" = {
      subnet_name = "subnetC"
      egress = [
        # ============= Rule for Public connection =============
        { rule_no = 1, protocol = -1, action = "allow", cidr_block = var.admin_cidr, from_port = 0, to_port = 0 }
      ],
      ingress = [
        # ============= Rule for Public connection =============
        { rule_no = 1, protocol = -1, action = "allow", cidr_block = var.admin_cidr, from_port = 0, to_port = 0 }
      ],
    }
    "subnetA_VPC2" = {
      subnet_name = "subnetA_VPC2"
      egress = [
        # ============= Rule for Public connection =============
        { rule_no = 1, protocol = "tcp", action = "allow", cidr_block = var.subnets["subnetB"].cidr_block, from_port = 1024, to_port = 65535 }
      ],
      ingress = [
        # ============= Rule for Public connection =============
        { rule_no = 1, protocol = "tcp", action = "allow", cidr_block = var.subnets["subnetB"].cidr_block, from_port = 22, to_port = 22 }
      ],
    }
  }
}

# ============= Instances =============
variable "instance_configurations" {
  type = object({
    most_recent   = optional(bool, true)
    instance_type = optional(string, "t3.micro")
  })
}

variable "EC2_instances" {
  type = map(object({
    subnet = string
    sg     = string
  }))
}

locals {
  Security_groups = {
    "Bastion-Invasor" = {
      VPC = "VPC1"
      ingress = [
        { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = [var.admin_cidr] },
        { from_port = 1024, to_port = 65535, protocol = "tcp", cidr_blocks = [var.subnets["subnetB"].cidr_block] }
      ],
      egress = [
        { from_port = 1024, to_port = 65535, protocol = "tcp", cidr_blocks = [var.admin_cidr] },
        { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = [var.subnets["subnetB"].cidr_block] },
      ]
    },
    "Server_1" = {
      VPC = "VPC1"
      ingress = [
        { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = [var.subnets["subnetA"].cidr_block] },
        { from_port = 1024, to_port = 65535, protocol = "tcp", cidr_blocks = [var.subnets["subnetA_VPC2"].cidr_block] }
      ],
      egress = [
        { from_port = 1024, to_port = 65535, protocol = "tcp", cidr_blocks = [var.subnets["subnetA"].cidr_block] },
        { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = [var.subnets["subnetA_VPC2"].cidr_block] }
      ]
    }
    "Server_2" = {
      VPC     = "VPC2"
      ingress = [{ from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = [var.subnets["subnetB"].cidr_block] }],
      egress  = [{ from_port = 1024, to_port = 65535, protocol = "tcp", cidr_blocks = [var.subnets["subnetB"].cidr_block] }]
    }
  }
}
