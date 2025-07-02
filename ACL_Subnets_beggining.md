## ⚠️ IMPORTANT ⚠️
 - We are talking about ACL (StateLess comunication)
 - See the advice in the end of the document
 - In this case i gave to the ACLs the possibility to pass all the protocols type, but this isn't the most secure way, if you will do a company aplication, try to study the protocols that will be use in this network and specify to use the minimum amount of protocols. Then the network will be more secure and you will be limiting the ways of access from invaders


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

## ‼️ Important to notice ‼️
- The SubNet_C can send and receive packages from SubNet_B, but SubNet_B will not send or receive any of this packages. Because we configurate ACL-SubNet_B to just communicate with SubNet_A


