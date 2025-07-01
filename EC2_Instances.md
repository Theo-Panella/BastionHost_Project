## 🐧 Instance OS
- I prefer using Amazon Linux, but feel free to do it however you think is best
- It's more commun to use Amazon Linux or Ubuntu

## 🔑 Create a SSH pair key for login
- Use or create your SSH and download it (normaly when you create, it will download automatically)
- When it download follow the normal steps using: "chmod 400 file.pem" to make it more secure for read

## 🍬 Tip
- Use "ssh -A username@IP_address" to connect in the Bastion instance
    - Because the -A make a single connection, being more secure, so when you connect to Bastion server and after this
      try to  "jump" from another instance, you don't need to copy the ssh pair key, you just use "ssh username@IP_address"
- If you had some troubles using "ssh -A", maybe the command is pulling your id_rsa and sending to the instance, to resolve this
  try "ssh-add file.pem /path/to/id_rsa", then you may be able to connect
  

## 🛡️ Bastion Instance
- Configurate the OS
- Use your downloaded ssh pair key
- Edit network configuration, putting the instance in SubNet_A
- The security groupe just leave the way that already is, after we will change it --> default is 0.0.0.0/0 "All comunication"

## 💻 Instance_1 or Server_1
- Configurate the OS
- Use your downloaded ssh pair key
- Edit network configuration, putting the instance in SubNet_B
- The security groupe just leave the way that already is, after we will change it --> default is 0.0.0.0/0 "All comunication"

## 👨🏻‍💻 Invader
- Configurate the OS
- Use your downloaded ssh pair key
- Edit network configuration, putting the instance in SubNet_C
- That one, i recomend just leave in default (0.0.0.0/0), because we just use him to test like a "Outside" connection to SubNet_B

## ☣️ATENTION☣️
The security groups will be configured after all the other components are set up. By using only ACLs as the security method, we can ensure that the ACLs are working correctly
