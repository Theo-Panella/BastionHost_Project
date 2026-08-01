admin_cidr = "0.0.0.0/0"

vpc_configs = {
  "VPC1" = {
    cidr_block = "192.168.0.0/24"
  }
  "VPC2" = {
    cidr_block = "172.18.0.0/24"
  }
}

subnets = {
  "subnetA" = {
    cidr_block = "192.168.0.0/26",
    az         = "us-west-2a",
    ip_publico = true,
    VPC        = "VPC1"
  }
  "subnetB" = {
    cidr_block = "192.168.0.64/26",
    az         = "us-west-2a",
    ip_publico = false,
    VPC        = "VPC1"
  }
  "subnetC" = {
    cidr_block = "192.168.0.128/26",
    az         = "us-west-2a",
    ip_publico = true,
    VPC        = "VPC1"
  }
  "subnetA_VPC2" = {
    cidr_block = "172.18.0.0/26",
    az         = "us-west-2a",
    ip_publico = false,
    VPC        = "VPC2"
  }
}

instance_configurations = {
  most_recent   = true
  instance_type = "t3.micro"
}

EC2_instances = {
  "Bastion" = {
    subnet = "subnetA"
    sg     = "Bastion-Invasor"
  }
  "Invasor" = {
    subnet = "subnetC"
    sg     = "Bastion-Invasor"
  }
  "Server_1" = {
    subnet = "subnetB"
    sg     = "Server_1"
  }
  "Server_2" = {
    subnet = "subnetA_VPC2"
    sg     = "Server_2"
  }
}