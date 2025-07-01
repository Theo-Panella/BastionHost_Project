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

  - Then you will see a message like this one
    
          00:00:00 ~ →  ssh -A ec2-user@Bastion_IP_Address
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
         [ec2-user@Bastion_IP_Address ~]$


  - Now connect to the Server_1 / Instance_1 using the private IP address (We use the private IP because we are in the same VPC as the instance, so don't need to use the public IP)
  - It's important to notice that we already made the one single connection with ssh -A, so our Bastion instance already have the SSH pair key to connect in our Server_1
    
        [ec2-user@Bastion_IP_Address ~]$ ssh ec2-user@Server_IP_Address
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
        Last login: Thu may 10 00:00:00 2000 from Your_Bastion_IP
        [ec2-user@Server_IP_Address ~]$

  - if you made it. Congratulations!! 🎉🎉
    You made a jump server connection. Now we can take a step foward and test the instance privace

    ##
    
  - Open another terminal and connect to the invader instance using the same command as Bastion
  - Now that you are alredy connected in all the 

  - Create Security Groupes (Open the Document Sg.md, to see more about the configuration)
  - 
