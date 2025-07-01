# BastionHost_Project
A project simulating a Bastion host (Jumping server) in AWS using EC2 and VPCs

## 📐 Architecture ##
- Two Diferents VPCs (Diferents IPV4 CIDR)
- VPC peering
- Subnets
- ACLs for minimun traffic 
- EC2 Instances 
- Security Groupes


## 🛠️ Technologies and Services ##
- AWS EC2
- AWS VPC
- VPC Peering
- ACLs and Security Groups


## 🔧 Starting ##
- We will start by doing all the configuration of VPC_1 and testing, after it, we create the VPC_2 and configurate for communication with VPC_1
- VPC_1:
  - Create Three Subnets: SubNet_A, SubNet_B, SubNet_C
  - Create an ACL for each Subnet (Open the Document ACL_Subnets_beggining.md to see more about the configuration)
  - Create EC2 instances (Open the Document EC2_Instances.md, to see more about it)
  - Create Security Groupes (Open the Document Sg.md, to see more about the configuration)
  - 
