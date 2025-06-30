# BastionHost_Project
A project simulating a Bastion host (Jumping server) in AWS using EC2

-- 📐 Architecture --
1- Two Diferents VPCs (Diferents IPV4 CIDR)
2- VPC peering
3- Subnets
4- ACLs for minimun traffic 
5- EC2 machines 
6- Security Groupes

##

-- 🛠️ Technologies and Services --
1- AWS EC2
2- AWS VPC
3- VPC Peering
4- ACLs and Security Groups

##

-- 🔧 Starting --
1- Create Two diferents VPCs (VPC_1 and VPC_2 both with diferents CIDR);
  1.2- VPC_1:
    Create Three Subnets: SubNet_A, SubNet_B, SubNet_C;
    Create an ACL for each Subnet (Open the Document ACL_Subnets_beggining.md to see more about the begging configuration)
    Create EC2 instances (Open the Document EC2_Instances.md, to see more about it)
    Create Security Groupes (Open the Document Sg.md, to see more about the configuration)
  1.3- 
