# BastionHost_Project
This is a practical showcase of VPC peering project simulating a Bastion host (Jumping server) in AWS using EC2 and VPCs
Open NetworkFlowChart.jpg to see the project idea

## ⚠️IMPORTANT ADVICES⚠️
- Some configurations **aren't recommended** to use in company productions (Eg: Use the same SSH key for every instance and configurete Sgs in 0.0.0.0/0 routes), these things are just for educational purpouse
- I want to improve this project a lot more in the future, using Terraform and Github actions (pipeline), so be connected with me on my linkedin, to don't miss this updates
- **https://www.linkedin.com/in/theo-panella-b079a4201**


## 📐 Architecture ##
- Two Diferents VPCs (Diferents IPV4 CIDR)
- VPC peering
- route tables
- Subnets
- ACLs for minimum traffic 
- EC2 Instances 
- Security Groups


## 🛠️ Technologies and Services ##
- AWS EC2
- AWS VPC
- VPC Peering
- ACLs and Security Groups

## 🔧 Configuration ##
- let’s start by doing all the configuration of VPC_1 and testing, after it, create the VPC_2 and configure for communication with VPC_1
- VPC_1:
  - Create Three Subnets: SubNet_A, SubNet_B, SubNet_C in VPC 1
  - Create an ACL for each Subnet (Open the Document ACL_Subnets.md to see more about it)
  - Create EC2 instances (Open the Document EC2_Instances.md, to see more about the details)

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
  - It's important to notice that we already made the agent foward connection with ssh -A, so our Bastion instance already have the SSH pair key to connect in our Server_1 and Server_1 will have the same key to connect in other instances in the same VPC
    
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
    You made a jump server connection. Now we can take a step further and test the instance privacy

    ##
    
  - Open another terminal and connect to the invader instance using the same command as Bastion
  - Now that you are alredy connected in all the instances, try to connect in Server_1 by ssh

          00:00:00 ~ →  ssh -A ec2-user@Invader_IP_Address
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
         [ec2-user@Invader_IP_Address ~]$ ssh ec2-user@Server_IP_Address
 
    - If every thing runs ok, the terminal will give you nothing about it, more especifically the terminal will be running in a loop trying to connect and beeing refused by the ACL on SubNet_B
    - And if this happen to you... Congratulations again, you made a secure enviromment using just ACLs 🎉🎉
    - But let's supose that you want to be sure about the results. If you fell insecure about it try to connect in the Server_2 (Instance_2) using the Bastion, and then with the Invader instance, you will use the same methods but with differents IP address
    
  - Now let's go back in the configuration and do the last part, that is the Security Groups (see the document Sg.md for configuration details)
  - I recommend to create the Sgs (Security groups) because is an extra security layer, and if you want, you can specify what instance can connect to another and what type of protocol can pass the Sg. But if this isn't the case, you can move on
  - But this is a recommendation, the main purpose of the project is already done, after this part we will start the VPC_2 configuration and the VPC peering

- VPC_2:
  - Create one Subnet: SubNet_A
  - Create an ACL for this Subnet (Open the Document ACL_Subnets.md to see more about it)
  - Create EC2 instance (Open the Document EC2_Instances.md, to see more about the details)
  - Configurate the VPC peering (Open the Document VPC_peering.md, to see more details)
 
  ## 📝 Testing ##
  - Open your terminal
  - In the Server_1, try to connect in the Server_1 from VPC_2 by ssh (Observation: The SSH agent ins't capable to pass the VPC peering, so we need to copy the SSH file.pem to the Server_1 or Server_2 instance)
  - Open another terminal
  - Use cat file.pem, and copy the private key

          00:00:00 ~/Downloads →  cat file.pem 
        -----BEGIN RSA PRIVATE KEY-----
              ADASDASDASDASDASDASD
              ADASDASDASDASDASDASD
              ADASDASDASDASDASDASD
              ADASDASDASDASDASDASD
        -----END RSA PRIVATE KEY-----

    - After copy, go to Server_1 (VPC_1), create an id_rsa file in .ssh directory and paste the SSH key on the new id_rsa file

           [ec2-user@Server_IP_Address ~]$ cd .ssh
      
           [ec2-user@Server_IP_Address .ssh]$ nano id_rsa

           [ec2-user@Server_IP_Address .ssh]$ cd ..


    - Now connect to Server_1 (VPC_2) from Server_1 (VPC_1)
    
           [ec2-user@Server_IP_Address ~]$ ssh -A ec2-user@Server_VPC2_IP_Address

    - Then you will see

          [ec2-user@Server_IP_Address ~]$ ssh ec2-user@Server_IP_Address
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
          [ec2-user@Server_VPC2_IP_Address ~]$
      
## 🏁 FINISHED




          
