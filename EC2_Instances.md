## 🐧 Instance OS
- I prefer using Amazon Linux, but feel free to do it however you think is best
- It's more commun to use Amazon Linux or Ubuntu

## 🔑 Create a SSH pair key for login
- Use or create your SSH and download it (normaly when you create, it will download automatically)
- When it download follow the normal steps using: "chmod 400 file.pem" to make it more secure for read

## 🍬 Tip
- Use "ssh -A username@IP_address" to connect in the Bastion instance
    - Because the -A is an agent forwarding that allows you to use your local SSH agent, which means, you can authenticate on a remote servers, making a single connection, being more secure, so when you connect to Bastion and after it, try to  "jump" from another instance, you don't need to copy the ssh pair key, you just use "ssh username@IP_address"
- If you had some troubles using "ssh -A", maybe the command is pulling your id_rsa and sending to the instance, to resolve this
  try "ssh-add file.pem /path/to/id_rsa", then you may be able to connect
  
## 🌐 VPC 1 — Bastion, Instance_1, Instance_2, Invader

### 🛡️ Bastion Instance
- Configurate the OS
- Use your downloaded ssh pair key
- Edit network configuration, putting the instance in SubNet_A
- The security group just leave the way that already is, after we will change it --> default is 0.0.0.0/0 "All comunication"

### 💻 Instance_1 or Server_1
- Configurate the OS
- Use your downloaded ssh pair key
- Edit network configuration, putting the instance in SubNet_B
- The security group just leave the way that already is, after we will change it --> default is 0.0.0.0/0 "All comunication"

### 💻 Instance_2 or Server_2
- Configurate the OS
- Use your downloaded ssh pair key
- Edit network configuration, putting the instance in SubNet_B
- The security group just leave the way that already is, after we will change it --> default is 0.0.0.0/0 "All comunication"

### 👨🏻‍💻 Invader
- Configurate the OS
- Use your downloaded ssh pair key
- Edit network configuration, putting the instance in SubNet_C
- The security group just leave the way that already is, after we will change it --> default is 0.0.0.0/0 "All comunication"

## ⚠️ Do all the VPC 1 first, it's easier then do both VPCs at once ⚠️

## 🌐 VPC 2 — Instance_1

### 💻 Instance_1
- Configurate the OS
- Use your downloaded ssh pair key
- Edit network configuration, putting the instance in SubNet_A of VPC 2 and disable the public IPv4, because we want to do private network without access to internet
- The security group just leave the way that already is, after we will change it --> default is 0.0.0.0/0 "All comunication"

