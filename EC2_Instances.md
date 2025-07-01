## Instance OS
- I prefer using Amazon Linux, but feel free to do it however you think is best;
- It's more commun to use Amazon Linux or Ubuntu.

## Create a SSH key pair for login
- Create you SSH and download it (normaly when you create, it will download automatically)
- When it download follow the normal steps using: "chmod 400 file.pem" to make it more secure for read

## Tip
- My tip is to use "ssh -A username@IP_address" to connect in the Bastion instance
    - Because the -A make a single connection, being more secure, so when you connect to Bastion server and after try to do the "jump" from another machine, you don't need to copy the ssh pair key
