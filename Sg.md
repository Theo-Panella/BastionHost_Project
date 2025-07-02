## ⚠️ IMPORTANT ⚠️

- We are talking about Security Groups (StateFull comunication)
- This one is more simple to configurate because Sg use the Statefull method
- In this case i gave to the Sg the possibility to pass all the Protocols type, but this isn't the most secure way, if you will do a company application, try to search the protocols that will be use in this network and specify to use the minimum amount of protocols. Then the network will be more secure and you will be limiting the ways of access from invaders

## 🛡️ Sg Base_to_Bastion

- Input Rules:
    - Your own gateway IP Address

- Output Rules:
    - 0.0.0.0/0 (General comunication)

## 🗄️ Sg Bastion_to_Servers

- Input Rules:
    - The Bastion IP (Now we can use the private IP)

- Output Rules:
  - 0.0.0.0/0

## 👨🏻‍💻 Sg Invader

- Input rules:
    -  Your own gateway IP Address

- Output Rules:
    - 0.0.0.0/0
