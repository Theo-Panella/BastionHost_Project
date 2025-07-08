## ⚠️ IMPORTANT ⚠️

- We are talking about Security Groups (StateFull comunication)
- This one is more simple to configurate because Sg use the Statefull method
- In this case i gave to the Sg the possibility to pass all the Protocols type and all ports, but this isn't the most secure way, if you will do a company application, try to **research the protocols that will be use in this network and specify to use the minimum amount of protocols**. Then the network will be more secure and you will be limiting the ways of access from invaders

## 🌐 VPC 1 — Base_to_Bastion, Bastion_to_Servers, Invader

### 🛡️ Sg Base_to_Bastion

- Input Rules:
    -  Your own gateway IP Address

- Output Rules:
    - Instance_1 private IPv4 from VPC 1
    - Instance_2 private IPv4 from VPC 1
      
### 🗄️ Sg Bastion_to_Servers

- Input Rules:
    - The Bastion IP (Now we can use the private IP)

- Output Rules:
    - Instance_1 private IPv4 from VPC 2 (if you didn't do the VPC 2 just leave 0.0.0.0/0)

### 👨🏻‍💻 Sg Invader

- Input rules:
    -  Your own gateway IP Address

- Output Rules:
    - 0.0.0.0/0
      
## 🌐 VPC 2 — Server_VPC2

### 🗄️ Sg Server_VPC2

- Input Rules:
    - Instance_1 private IPv4 from VPC 1
    - Instance_2 private IPv4 from VPC 1

- Output Rules:
    - 0.0.0.0/0 (General comunication)
