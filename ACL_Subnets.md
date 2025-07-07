## ⚠️ IMPORTANT ⚠️  
- We are talking about ACL (Stateless communication).  
- See the advice at the end of the document.  
- In this case, I allowed all protocol types in the ACLs — **not recommended** for production.  
- If you're building a company-level application, allow output traffic on ports **1024–65535** (high ports used by the OS). For input, restrict traffic to **only what's necessary**, like TCP port 22 for SSH. This minimizes the attack surface for invaders.


## 🌐 VPC 1 — ACL-SubNet_A, ACL-SubNet_B, and ACL-SubNet_C

### 🖧 ACL-SubNet_A

**Input rules:**
 - Your own gateway IP address (used to connect to the Bastion Host)  
 - SubNet_B IPv4 CIDR (allows SubNet_A to receive packages from SubNet_B)

**Output rules:**
 - Your own gateway IP address (used to connect to the Bastion Host)  
 - SubNet_B IPv4 CIDR (allows SubNet_A to send packages to SubNet_B)


### 🖧 ACL-SubNet_B

**Input rules:**
 - SubNet_A IPv4 CIDR (allows SubNet_B to receive packages from SubNet_A)
 - ⚠️ SubNet_A IPv4 CIDR from VPC 2 (allows SubNet_B to receive packages from SubNet_A_VPC2) ⚠️

**Output rules:**
 - SubNet_A IPv4 CIDR (allows SubNet_B to send packages back to SubNet_A)
 - ⚠️ SubNet_A IPv4 CIDR from VPC 2 (allows SubNet_B to send packages back to SubNet_A_VPC2) ⚠️


### 🖧 ACL-SubNet_C

**Input rules:**
 - Your own gateway IP address (used for private ACL access)  
 - SubNet_B IPv4 CIDR (allows SubNet_C to receive packages from SubNet_B)

**Output rules:**
 - Your own gateway IP address (used for private ACL access)  
 - SubNet_B IPv4 CIDR (allows SubNet_C to send packages back to SubNet_B)


### ‼️ Important to notice ‼️  
 - SubNet_C **can** send and receive packages **to/from SubNet_B**,  
  **but SubNet_B is not configured to do the same with SubNet_C**.  
 - This happens because **ACL-SubNet_B only allows communication with SubNet_A**,  
  effectively blocking any communication with SubNet_C.


## 🌐 VPC 2 — ACL-SubNet_A

### 🖧 ACL-SubNet_A
**Input rules:**
 - SubNet_B IPV4 CIDR from VPC 1 (allows SubNet_A to receive packages from SubNet_B )

**Output rules:**
 - SubNet_B IPV4 CIDR from VPC 1 (allows SubNet_A to send packages back from SubNet_B)
