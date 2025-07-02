## ⚠️ IMPORTANT ⚠️
 - We are talking about ACL (StateLess comunication)
 - When you saw about all the ACLs Notice the SubNet_C can send and receive packages from SubNet_B, but SubNet_B will not send or receive any of this packages. Because we configurate ACL-SubNet_B to just communicate with SubNet_A



## 🖧 ACL-SubNet_A:

- Input rules:
    
    - Your own gateway IP Address (We use this to connect in our Bastion host)
    - Subnet_B IPV4 CIDR (We are saying SubNet_A can receive packages from SubNet_B)
    
- Output rules:
    
    - Your own gateway IP Address (We use this to connect in our Bastion host)
    - Subnet_B IPV4 CIDR (We are saying Subnet_A can send packages to SubNet_B)
   


## 🖧 ACL-SubNet_B:

- Input rules:
    
    - Subnet_A IPV4 CIDR (We are saying Subnet_B can receive packages from SubNet_A)
    
- Output rules:
    
    - Subnet_A IPV4 CIDR (We are saying Subnet_B can send packages to SubNet_A)



## 🖧 ACL-SubNet_C:

- Input rules:
    
    - Your own gateway IP Address (We use this to connect in our ACL with some privacy)
    - Subnet_B IPV4 CIDR (We are saying SubNet_C can receive packages from SubNet_B)

    
- Output rules:
    
    - Your own gateway IP Address (We use this to connect in our ACL with some privacy)
    - Subnet_B IPV4 CIDR (We are saying Subnet_C can send packages to SubNet_B)
    
