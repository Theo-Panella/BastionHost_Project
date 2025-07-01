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


## 🔧 Configuration ##
- We will start by doing all the configuration of VPC_1 and testing, after it, we create the VPC_2 and configurate for communication with VPC_1
- VPC_1:
  - Create Three Subnets: SubNet_A, SubNet_B, SubNet_C
  - Create an ACL for each Subnet (Open the Document ACL_Subnets_beggining.md to see more about it)
  - Create EC2 instances (Open the Document EC2_Instances.md, to see more about it)

  ## 📝 Testing ##
  - Open your terminal
  - Connect in the Bastion instance using:
    
         ssh -A username@Instance_IP_Address

  - Now  we are connected
    
          01:52:50 ~ →  ssh -A ec2-user@IP_Address
           ,     #_
            ~\_  ####_        Amazon Linux 2023
           ~~  \_#####\
           ~~     \###|
           ~~       \#/ ___   https://aws.amazon.com/linux/amazon-linux-2023
             ~~       V~' '->
             ~~~         /
               ~~._.   _/
                  _/ _/
                _/m/'
         Last login: Thu may 10 00:00:00 2000 from Your_Gateway_IP
         [ec2-user@I_P_Address ~]$

    
  - Open another terminal and connect to the invader instance using the same comand
    

  - Create Security Groupes (Open the Document Sg.md, to see more about the configuration)
  - 
